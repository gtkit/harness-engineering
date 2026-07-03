// Package breaker 是基于 sony/gobreaker/v2 的轻量熔断封装(纯基础包,无业务/无观测依赖)。
//
// 设计原则:
//   - 熔断加在 client 侧(调用外部服务处),不加在入口侧;
//   - 泛型支持任意返回类型;
//   - 默认触发策略为「连续失败 N 次」——低 QPS 服务(如退款)在滑动窗口内凑不满
//     最小请求量,错误率式熔断会形同虚设;高 QPS 场景可用 WithErrorRatio 切换;
//   - 错误分类通过 WithIsSuccessful 注入(业务错误应计成功,不代表渠道故障),
//     本包禁止反向依赖业务模块的 sentinel;
//   - 调用方取消(context.Canceled)恒不计入统计——那不是外部服务的故障;
//   - 观测:状态变更默认 stdlib log,可用 WithOnStateChange 替换(将来接 metrics 从这里挂)。
//
// 使用示例:
//
//	b := breaker.New[string]("channel:app1",
//	    breaker.WithIsSuccessful(func(err error) bool { return err == nil || isBizErr(err) }))
//	tid, err := b.Execute(func() (string, error) { return client.Refund(ctx, req) })
//	if breaker.IsRejected(err) { /* 熔断打开,快速失败 */ }
package breaker

import (
	"context"
	"errors"
	"time"

	"github.com/gtkit/logger"
	"github.com/sony/gobreaker/v2"
)

// 默认配置常量。
const (
	DefaultMaxRequests         = 1                // 半开状态允许的探测请求数(保守:一次探测定夺)
	DefaultConsecutiveFailures = 5                // 默认策略:连续失败达到此值熔断打开
	DefaultRecoverTimeout      = 30 * time.Second // Open → HalfOpen 的冷却时间
)

// Option 配置熔断器参数。
type Option func(*config)

type config struct {
	maxRequests         uint32
	recoverTimeout      time.Duration
	consecutiveFailures uint32
	// 错误率策略(ratioMinRequests>0 时启用,替代连续失败策略)
	ratioMinRequests uint32
	ratioPercent     int
	ratioWindow      time.Duration
	isSuccessful     func(error) bool
	onStateChange    func(name string, from, to gobreaker.State)
}

func defaultConfig() config {
	return config{
		maxRequests:         DefaultMaxRequests,
		recoverTimeout:      DefaultRecoverTimeout,
		consecutiveFailures: DefaultConsecutiveFailures,
		isSuccessful:        func(err error) bool { return err == nil },
		onStateChange: func(name string, from, to gobreaker.State) {
			// 状态迁移是告警源(observability guide):Warn 级 + 结构化字段
			logger.Warnw("circuit breaker state changed", "breaker", name, "from", from.String(), "to", to.String())
		},
	}
}

// WithMaxRequests 设置半开状态下允许通过的探测请求数。
func WithMaxRequests(n uint32) Option {
	return func(c *config) { c.maxRequests = n }
}

// WithRecoverTimeout 设置从 Open 到 HalfOpen 的冷却时间。
func WithRecoverTimeout(d time.Duration) Option {
	return func(c *config) { c.recoverTimeout = d }
}

// WithConsecutiveFailures 设置连续失败阈值(默认策略)。
func WithConsecutiveFailures(n uint32) Option {
	return func(c *config) { c.consecutiveFailures = n }
}

// WithErrorRatio 切换为错误率策略:window 窗口内请求量 >= minRequests 且失败率 >= percent% 时熔断。
// 仅适合请求量足以凑满 minRequests 的高 QPS 场景;低 QPS 用默认的连续失败策略。
func WithErrorRatio(minRequests uint32, percent int, window time.Duration) Option {
	return func(c *config) {
		c.ratioMinRequests = minRequests
		c.ratioPercent = percent
		c.ratioWindow = window
	}
}

// WithIsSuccessful 注入错误分类:返回 true 表示该错误不算外部服务故障
// (如业务拒绝:订单不存在、参数校验失败),不计入失败。nil err 恒为成功。
func WithIsSuccessful(f func(error) bool) Option {
	return func(c *config) { c.isSuccessful = f }
}

// WithOnStateChange 替换状态变更回调(默认 stdlib log;接入 metrics/告警从这里挂)。
func WithOnStateChange(f func(name string, from, to gobreaker.State)) Option {
	return func(c *config) { c.onStateChange = f }
}

// Breaker 是泛型熔断器,包裹对外部服务的调用。
type Breaker[T any] struct {
	cb   *gobreaker.CircuitBreaker[T]
	name string
}

// New 创建命名熔断器实例。
func New[T any](name string, opts ...Option) *Breaker[T] {
	cfg := defaultConfig()
	for _, o := range opts {
		o(&cfg)
	}

	readyToTrip := func(counts gobreaker.Counts) bool {
		return counts.ConsecutiveFailures >= cfg.consecutiveFailures
	}
	var interval time.Duration
	if cfg.ratioMinRequests > 0 { // 错误率策略
		ratio := float64(cfg.ratioPercent) / 100.0
		readyToTrip = func(counts gobreaker.Counts) bool {
			return counts.Requests >= cfg.ratioMinRequests &&
				float64(counts.TotalFailures)/float64(counts.Requests) >= ratio
		}
		interval = cfg.ratioWindow
	}

	isSuccessful := cfg.isSuccessful
	cb := gobreaker.NewCircuitBreaker[T](gobreaker.Settings{
		Name:        name,
		MaxRequests: cfg.maxRequests,
		Interval:    interval,
		Timeout:     cfg.recoverTimeout,
		ReadyToTrip: readyToTrip,
		IsSuccessful: func(err error) bool {
			return err == nil || isSuccessful(err)
		},
		// 调用方取消不是外部服务故障,不计成功也不计失败
		IsExcluded: func(err error) bool {
			return errors.Is(err, context.Canceled)
		},
		OnStateChange: cfg.onStateChange,
	})
	return &Breaker[T]{cb: cb, name: name}
}

// Execute 经熔断器执行调用。熔断打开或半开超额时不执行 fn,
// 返回的错误可用 IsRejected 判定。
func (b *Breaker[T]) Execute(fn func() (T, error)) (T, error) {
	return b.cb.Execute(fn)
}

// State 返回当前熔断器状态。
func (b *Breaker[T]) State() gobreaker.State { return b.cb.State() }

// Name 返回熔断器名称。
func (b *Breaker[T]) Name() string { return b.name }

// IsRejected 判断错误是否为熔断拒绝(open 状态或半开超额),调用方据此翻译为可重试语义。
func IsRejected(err error) bool {
	return errors.Is(err, gobreaker.ErrOpenState) || errors.Is(err, gobreaker.ErrTooManyRequests)
}
