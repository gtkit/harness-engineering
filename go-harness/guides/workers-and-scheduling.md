# Go Worker 与定时任务 Guide

本 guide 约束 Go 后端服务中的后台 goroutine、队列消费者、定时任务、异步事件和 outbox 补偿任务。任何不直接在 HTTP 请求生命周期内完成的逻辑，都要按本文件审查。

## 基本原则

- 禁止在 `init()`、包级变量初始化、构造函数或 middleware 注册阶段偷偷启动 goroutine。
- 后台任务必须由应用生命周期统一管理：启动、健康状态、停止信号、超时退出都要可控。
- 任何异步任务默认可能重复执行，必须按幂等设计。
- 请求内不要 fire-and-forget 启 goroutine 执行业务副作用；需要异步时写入队列 / outbox / job 表，再由 worker 处理。
- 后台任务不得吞掉 panic 或 error；失败必须可见、可重试或可补偿。

## 生命周期与优雅关闭

- worker 使用顶层 `context.Context`，跟随服务 `SIGINT` / `SIGTERM` 取消。
- 每个 worker loop 必须监听 `ctx.Done()`，不能永久阻塞在无退出路径的 channel、sleep 或外部调用上。
- 外部调用必须设置 timeout；关闭时给 worker 明确 drain 时间上限。
- 多 worker 并发处理时限制并发数，避免无界 goroutine。

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

- 消息处理必须幂等：使用业务唯一键、状态机、去重表或唯一索引防重复副作用。
- ack 必须发生在持久化副作用成功之后；失败路径按队列能力 nack / retry / dead-letter。
- 重试使用指数退避 + 最大次数；不可无限快速重试打爆依赖。
- 消费者并发数必须可配置，并有合理默认值。
- 大 payload 不直接塞消息体，优先传业务 ID，处理时重新加载最新状态。
- 处理顺序有要求时明确 partition / key / 锁策略，不假设队列天然全局有序。

## 定时任务

- 定时任务必须可重复执行；重复运行不能导致重复扣款、重复发送、重复删除。
- 多实例部署时关键任务必须有分布式锁或 leader 机制；单机 ticker 不能假设只有一个实例。
- 明确时区、错过执行的补偿策略和最长运行时间。
- 长任务拆分为小批次，记录游标或 checkpoint，避免一次执行失败后全部重来。
- 定时任务入口只做调度与编排，核心业务逻辑下沉到 service，便于测试。

## Outbox 与事务边界

- DB 写入和异步副作用需要一致性时，优先使用 outbox：业务事务内写业务表 + outbox 表，事务提交后 worker 投递或执行。
- 禁止在事务未提交前发消息、调支付、发邮件或触发不可回滚副作用。
- outbox 处理要有状态字段、重试次数、下次重试时间和错误原因。
- 补偿任务必须可观测，不能只靠日志排查。

## 可观测性

- 每类 worker 必须记录启动、停止、单次处理失败、重试耗尽、队列积压或扫描进度。
- 日志包含 job/message id、业务 id、attempt、耗时和错误上下文。
- 高风险任务应暴露指标：处理成功/失败计数、耗时、重试次数、积压量。
- 敏感 payload 不进日志；必要时只记录脱敏后的业务标识。

## 测试与验证

- worker 核心处理函数必须可单测，不依赖真实 ticker。
- 测试覆盖 success、可重试失败、不可重试失败、ctx cancel、重复消息幂等。
- 定时任务测试调用核心 service，不等待真实时间流逝。
- 涉及并发处理时跑 `go test -race`，并覆盖并发重复执行场景。
- 修改 worker / scheduler 后，交付前说明实际跑过的 worker 相关测试和项目级验证命令。
