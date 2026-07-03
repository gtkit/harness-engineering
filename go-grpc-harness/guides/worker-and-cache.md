# Worker / Cache Guide

> BASE: go-harness/guides/worker-and-cache.md @ 2026-07-03（通用规则同源;通用改进先落 go-grpc-harness,择机回灌 go-harness）

> 本 guide 补充 `workers-and-scheduling.md`，聚焦缓存、Redis、Pub/Sub、延迟队列一致性。

## Worker 边界

- worker 负责调度、并发、退出、节流、重试节奏。
- 业务决策放 application service。
- 数据访问经 application port，不在 worker 中直接访问 DB / Redis repository。
- 长生命周期 worker 必须支持 context cancel。

## Cache 边界

- 缓存默认不是权威数据源。
- 写 DB 成功后再更新/失效缓存。
- 缓存写失败必须有降级策略，常见做法是删除旧缓存让读路径回源。
- key 有命名空间和版本意识。
- value 只放读路径必要字段，不无约束缓存完整持久化模型。

## Redis / PubSub / Delay Queue

- Redis-only repo 不参与 GORM 事务；原子性用 Lua / SetNX / 原子计数。
- Pub/Sub 只做通知，不做权威状态；客户端收到事件后仍应能查询最终状态。
- 延迟队列任务必须有兜底扫描或补偿路径，避免单点丢任务。

## 测试要求

涉及 worker/cache 的变更至少覆盖：
- 正常路径
- 外部依赖失败
- context cancel / timeout
- 重复执行或并发竞争
