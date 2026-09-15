# Laravel Queue / Event / Scheduler Guide

## Queue Job

- Job 默认要求幂等（重试会重复执行，靠业务唯一键 / 状态判断去重）
- 明确 `tries`、`backoff`、失败路径
- **失败处理**：实现 `failed(Throwable $e)` 做补偿 / 告警，不让失败静默丢进 `failed_jobs`；区分 `$tries`（含重试次数）与 `$maxExceptions`（异常上限），长任务用 `retryUntil()` 给时间窗
- 大对象优先传 ID，执行时重新加载
- 避免把未提交事务中的状态直接交给异步 Job（`afterCommit()` 或事务提交后再 dispatch）

## Event / Listener

- Event 表达"已发生的事实"
- **同步 vs 异步边界**：默认同步 Listener（在请求生命周期内执行，抛异常会中断主流程）；含 IO / 慢操作 / 可独立失败的 Listener 实现 `ShouldQueue` 转异步，并**自行保证幂等与失败处理**（异步失败不影响主流程，但也不能静默丢）
- Listener 保持轻量，复杂逻辑继续下沉到 Service
- 注意事件链条中的隐藏 IO、递归触发和幂等问题

## Scheduler / Command

- 定时任务默认视为强约束范围
- Command 负责入口与编排，核心逻辑下沉
- **防重叠 / 单实例**：耗时任务加 `withoutOverlapping()` 防同机叠跑；多实例部署的关键任务加 `onOneServer()`（需共享 cache 锁，如 redis），否则每台机都会各跑一遍
- 定时任务应可重复执行（幂等），避免多次运行导致不可控副作用
- 对关键任务补日志、告警或至少失败可见性

## 交付前必查

- Job 是否可重试
- 定时任务是否会重复发送 / 重复扣减 / 重复清理
- Listener 是否隐藏调用外部服务
- 是否需要队列 fake / 事件 fake 的测试覆盖
