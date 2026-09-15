# Worker 与定时任务 Guide

> worker 仍遵守模块化边界：`module/<m>/worker` 只依赖 application，不直接 import repository / gorm。

## 基本原则

- 禁止在 `init()`、包级变量初始化、构造函数或 middleware 注册阶段偷偷启动 goroutine。
- worker 由 bootstrap 统一启动和停止。
- 请求内不要 fire-and-forget 执行业务副作用；需要异步时写队列 / outbox / job 表。
- 异步任务默认可能重复执行，必须幂等。

## 生命周期

- worker 使用顶层 `context.Context`，跟随 SIGINT / SIGTERM 取消。
- loop 必须监听 `ctx.Done()`。
- 外部调用必须设置 timeout。
- 并发数必须有上限，不能按数据量无限开 goroutine。

```go
func (w *Worker) Run(ctx context.Context) error {
    ticker := time.NewTicker(time.Minute)
    defer ticker.Stop()

    for {
        select {
        case <-ctx.Done():
            return ctx.Err()
        case <-ticker.C:
            if err := w.process(ctx); err != nil {
                w.logger.Error("worker process failed", zap.Error(err))
            }
        }
    }
}
```

## 队列消费者

- ack 发生在持久化副作用成功之后。
- 失败路径按队列能力 nack / retry / dead-letter。
- 重试有最大次数或租约边界。
- 大 payload 不直接塞消息体，优先传业务 ID。
- 顺序有要求时明确 partition / key / 锁策略。

## 定时任务

- 可重复执行，重复运行不造成重复扣款、发送、删除。
- 多实例部署时关键任务必须有分布式锁或 leader 机制。
- 明确时区、错过执行补偿、最长运行时间。
- 长任务拆小批次，记录游标或 checkpoint。
- 调度入口只做调度，业务逻辑下沉 application service。

## Outbox 与事务边界

- DB 写入和异步副作用需要一致性时优先使用 outbox。
- 禁止在事务未提交前发消息、调支付、发邮件或触发不可回滚副作用。
- outbox 有状态、重试次数、下次重试时间和错误原因。

## 测试

- worker 核心处理函数可单测，不依赖真实 ticker。
- 覆盖 success、可重试失败、不可重试失败、ctx cancel、重复消息幂等。
- 涉及并发处理时跑 `go test -race`。
