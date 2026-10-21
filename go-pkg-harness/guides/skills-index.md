# Go 技术 skill 索引 Guide

通用 Go 知识放在技术 skill 里，`.harness/guides/` 只写本包约定。Codex 先获得可发现 skill 的名称、描述和路径等元数据；任务匹配 description 时可自动选用，也可显式调用，选用时再读取 `SKILL.md` 正文。本表负责按任务路由，不要求用户每次手动点名；发现、读取与执行通过是不同状态，条目按扩展包开发会真正碰到的面裁过。

## 加载纪律

- 优先使用当前会话 skills 清单和项目路由，按需读取相关技能正文；不为确认自动加载能力重复扫描目录或先跑 doctor。除用户明确要求诊断外，仅在安装更新、影响加载的环境变化或加载异常时检查对应范围，复杂任务、新会话或切换阶段本身不触发检查。
- **开始做功能前先扫一遍本表**：按本次要做的事选出相关 skill，在写第一行代码前调用，不要边写边想起来。
- **分批加载，每批先选最多 3 个**：按当前步骤的主路径选最相关的 skill，其余记录为后续需要项，在处理对应主题前补读。这不是整项任务的数量上限，不得因配额跳过必要专项，也不为加载 skill 单独启动计划流程。
- 写到中途出现表里的新主题（第一次加锁、第一次解析外部输入），当场补调，不留到写完再补。
- 审查、排障、方案评审同样先调对应 skill，再给判断。
- 调不到某个 skill 时记录缺失与具体路径，可继续不依赖它的工作；本次阶段要求的质量、API兼容或安全验证保持未验证，不能跳过后声明通过。按 harness-doctor 的依赖清单区分必需、条件和不适用项，不自动安装。

## 索引

| 本次要做的事 | 调用 |
|---|---|
| Go 任务跨主题或入口不明确 | `go-task-router`；已明确单一专项时直接进入该专项 |
| 写或改任何 `.go` 文件 | `use-modern-go` |
| goroutine、channel、锁、并发安全承诺 | `go-concurrency` |
| context 生命周期、deadline、取消原因、请求脱离与有界收尾 | `go-context`；并发调度、重试预算另按对应专项 |
| 错误类型、sentinel error、wrap 边界、`errors.Is` / `As` 契约 | `go-error-handling` |
| 写或改测试、Benchmark、Fuzz、Example | `go-testing` |
| 包内直接操作 MySQL / Postgres、Redis、MQ | `go-database-patterns` / `go-redis-patterns` / `go-mq-patterns` |
| 解析外部输入、密钥处理、注入与解析炸弹、依赖漏洞 | `go-security` |
| 分配优化、逃逸分析、pprof、优化前后对比 | `go-performance` |
| golangci-lint 配置、go.mod 依赖治理、apidiff、发版 | `go-engineering-governance` |
| 自己写完或改完代码后的交付前验证 | `go-enterprise-quality` |
| 审查代码、diff 或 PR | `go-review` |
| 包的 API 面设计、选型取舍、方案评审 | `senior-go-engineer` / `tech-design-review` |

## 调用方与影响范围导航

审查或变更影响分析需要定位声明、引用、接口实现或调用链时，按当前运行时解析出的 `go-review` 目录读取 `references/code-navigation.md`；`go-enterprise-quality` 共用这份参考，不另复制。gopls/LSP 仅在当前环境确实可用时使用；缺失时用 `rg` 与源码追踪，记录模块、构建条件和动态/仓库外调用方缺口，不自动安装，不把文本搜索当作完整调用图。

## 与 guides 的关系

skill 给通用写法，guide 给本包约定。遵守当前用户指令与适用的 `AGENTS.md` / `CLAUDE.md` 和 `.harness/guides/`；已有项目契约优先于 skill 的默认示例，冲突时在汇报里点出，不据此迁移日志、错误模型或架构。
