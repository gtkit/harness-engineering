# Go 技术 skill 索引 Guide

通用 Go 知识放在全局 skill 里，`.harness/guides/` 只写本项目约定。skill 的正文不会自动进上下文——只有名字和描述在，正文必须显式调用才读得到。本表就是那张调用索引。

## 加载纪律

- **开始做功能前先扫一遍本表**：按本次要做的事选出相关 skill，在写第一行代码前调用，不要边写边想起来。
- **一次最多调 3 个**：命中多条时按本次改动的主路径挑最相关的三个先调，其余命中项写进计划，写到那段代码时再调。上下文预算和规范同等重要——把命中的全调进来会把项目代码挤出去。
- 写到中途出现表里的新主题（第一次加锁、第一次读写缓存、第一次写消费者、第一次碰 JWT），当场补调，不留到写完再补。
- 审查、排障、方案评审同样先调对应 skill，再给判断。
- 调不到某个 skill（本机没装）时跳过它继续做，并在汇报里说明跳过了哪个；不因缺失中断，也不凭记忆编造它的内容。

## 索引

| 本次要做的事 | 调用 |
|---|---|
| 写或改任何 `.go` 文件 | `use-modern-go` |
| HTTP API 与前端/其他后端共享 schema、错误契约或兼容窗口 | `cross-stack-api-contract` |
| goroutine、channel、锁、context 传播、有界并发、data race | `go-concurrency` |
| 错误类型、错误码分段、重试判定、统一错误响应 | `go-error-handling` |
| 写或改测试、治 flaky、Benchmark | `go-testing` |
| 跨语言契约、集成、浏览器、故障注入或 flaky 测试策略 | `polyglot-test-engineering` |
| 操作 MySQL / Postgres：查询、连接池、事务、迁移、分页 | `go-database-patterns` |
| 读写 Redis：数据结构选型、Pipeline、锁、Streams | `go-redis-patterns` |
| DB 与缓存的更新时序、穿透击穿雪崩、热 key、多级缓存 | `go-cache-consistency` |
| 事务边界、并发扣减、幂等键状态机、跨服务一致性 | `go-data-consistency` |
| Kafka / RocketMQ / NATS / RabbitMQ 的生产者与消费者 | `go-mq-patterns` |
| Go/PHP/Node 之间的任务或事件 schema、重试、DLQ、回放 | `async-job-contracts` |
| 日志、metrics、tracing、request_id、慢 SQL | `go-observability` |
| OpenResty/PHP/Go/浏览器之间的 trace、日志、指标关联 | `cross-stack-observability` |
| Gin 的 handler、middleware、路由、DTO 校验、JWT | `go-gin-api` |
| 优雅关闭、探针、服务间调用、gRPC 拦截器与超时预算 | `go-microservice` |
| WebSocket / SSE 长连接推送 | `go-websocket-sse` |
| 超时、重试、熔断、限流、降级、SLO 告警、容量评估 | `go-stability-engineering` |
| 鉴权、处理外部输入、TLS、密钥、注入与 SSRF、安全审查 | `go-security` |
| CPU / 内存 / 延迟排查，pprof、GC 调优、优化前后对比 | `go-performance` |
| 浏览器→网关→Go/依赖的端到端性能和容量 | `fullstack-performance` |
| golangci-lint 配置、go.mod 依赖治理、API 兼容、发版 | `go-engineering-governance` |
| 自己写完或改完 Go 代码后的交付前验证 | `go-enterprise-quality` |
| Go/PHP/前端/OpenResty 的发布、迁移、灰度和回滚 | `polyglot-release-engineering` |
| 生产事故跨组件定位、止损和复盘 | `incident-response` |
| Go/PHP/npm 依赖、SBOM、secret、CVE 或镜像治理 | `polyglot-security-supply-chain` |
| Go/PHP/Vue/Node/OpenResty 版本升级和兼容迁移 | `runtime-upgrade-migration` |
| 审查 Go 代码、diff 或 PR | `go-review` |
| 项目设计、选型、方案取舍、容量估算 | `senior-go-engineer` |
| 写或评审技术方案、ADR、上线与回滚方案 | `tech-design-review` |

## 与 guides 的关系

skill 给通用写法，guide 给本项目约定。两者冲突时以 `.harness/guides/` 和 `CLAUDE.md` 为准，并在汇报里点出冲突点。
