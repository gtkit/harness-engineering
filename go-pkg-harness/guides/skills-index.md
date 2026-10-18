# Go 技术 skill 索引 Guide

通用 Go 知识放在全局 skill 里，`.harness/guides/` 只写本包约定。skill 的正文不会自动进上下文——只有名字和描述在，正文必须显式调用才读得到。本表就是那张调用索引，条目按扩展包开发会真正碰到的面裁过。

## 加载纪律

- **开始做功能前先扫一遍本表**：按本次要做的事选出相关 skill，在写第一行代码前调用，不要边写边想起来。
- **一次最多调 3 个**：命中多条时按本次改动的主路径挑最相关的三个先调，其余命中项写进计划，写到那段代码时再调。上下文预算和规范同等重要——把命中的全调进来会把项目代码挤出去。
- 写到中途出现表里的新主题（第一次加锁、第一次解析外部输入），当场补调，不留到写完再补。
- 审查、排障、方案评审同样先调对应 skill，再给判断。
- 调不到某个 skill 时记录缺失与具体路径，可继续不依赖它的工作；本次阶段要求的质量、API兼容或安全验证保持未验证，不能跳过后声明通过。按 harness-doctor 的依赖清单区分必需、条件和不适用项，不自动安装。

## 索引

| 本次要做的事 | 调用 |
|---|---|
| 写或改任何 `.go` 文件 | `use-modern-go` |
| goroutine、channel、锁、context 传播、并发安全承诺 | `go-concurrency` |
| 错误类型、sentinel error、wrap 边界、`errors.Is` / `As` 契约 | `go-error-handling` |
| 写或改测试、Benchmark、Fuzz、Example | `go-testing` |
| 包内直接操作 MySQL / Postgres、Redis、MQ | `go-database-patterns` / `go-redis-patterns` / `go-mq-patterns` |
| 解析外部输入、密钥处理、注入与解析炸弹、依赖漏洞 | `go-security` |
| 分配优化、逃逸分析、pprof、优化前后对比 | `go-performance` |
| golangci-lint 配置、go.mod 依赖治理、apidiff、发版 | `go-engineering-governance` |
| 自己写完或改完代码后的交付前验证 | `go-enterprise-quality` |
| 审查代码、diff 或 PR | `go-review` |
| 包的 API 面设计、选型取舍、方案评审 | `senior-go-engineer` / `tech-design-review` |

## 与 guides 的关系

skill 给通用写法，guide 给本包约定。两者冲突时以 `.harness/guides/` 和 `CLAUDE.md` 为准，并在汇报里点出冲突点。
