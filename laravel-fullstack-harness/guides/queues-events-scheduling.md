# Laravel Queue / Event / Scheduler Guide

## Queue Job

- Job 默认要求幂等
- 明确 `tries`、`backoff`、失败路径
- 大对象优先传 ID，执行时重新加载
- 避免把未提交事务中的状态直接交给异步 Job

## Event / Listener

- Event 表达“已发生的事实”
- Listener 保持轻量，复杂逻辑继续下沉到 Service
- 注意事件链条中的隐藏 IO、递归触发和幂等问题

## Scheduler / Command

- 定时任务默认视为强约束范围
- Command 负责入口与编排，核心逻辑下沉
- 定时任务应可重复执行，避免多次运行导致不可控副作用
- 对关键任务补日志、告警或至少失败可见性

## 交付前必查

- Job 是否可重试
- 定时任务是否会重复发送 / 重复扣减 / 重复清理
- Listener 是否隐藏调用外部服务
- 是否需要队列 fake / 事件 fake 的测试覆盖
