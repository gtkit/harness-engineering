# Go MCP 依赖选择

## 选择顺序与证据

保留现有合适依赖。新增能力先判断标准库能否直接解决；确需第三方时优先核实 `github.com/gtkit/*` 的原生能力，再选择官方协议 SDK 或成熟生态。用户的 gtkit 偏好不表示强制替换 SDK、JSON 编解码器或所有标准库调用。

每次选择记录：真实模块路径/版本、声明的 package 名、所需 API、Go/平台兼容、资源生命周期、错误/取消语义、安全限制、引入理由。只读到仓库 README 不代表当前项目锁定版本具备该 API。不得使用 `@latest` 代替版本决策；不得顺带改为 `/v2`。

## 候选矩阵

下面是按职责的候选，不是预装清单；链接为维护者文档，2026-10-30 核对。根仓库名不等于应使用的 module 主版本。

| 能力 | 优先核实候选 | MCP 适用边界 |
|---|---|---|
| 应用日志 | [gtkit/logger](https://github.com/gtkit/logger) | 核实当前版本的输出目标、初始化副作用、并发与 flush；stdio 禁止任何日志进入 stdout，禁止自动开启外部推送 |
| 应用 JSON | [gtkit/json](https://github.com/gtkit/json) | 其后端可按 build tags 选择；须验证数字、null/缺失、UTF-8、错误和目标架构。SDK 自带协议编码默认保留 |
| 入站/按主体限流 | [gtkit/golimit](https://github.com/gtkit/golimit) | 核实拒绝/等待语义、key 容量、清理与并发；限制速率不能代替在途并发上限，内存限流不等于集群总限流 |
| JWT 处理 | [gtkit/gojwt](https://github.com/gtkit/gojwt) | 明确 issuer/audience/算法/有效期策略；JWT 签验不是完整 MCP OAuth，不能代替发现、授权或资源权限 |
| Redis | [gtkit/redisx](https://github.com/gtkit/redisx) | 仅确需共享状态/缓存时引入；连接、重试、隔离、key 预算与 TTL 由业务决定 |
| MySQL/GORM | [gtkit/ormx](https://github.com/gtkit/ormx) | 仅需持久存储且适配该数据库时引入；事务提交点、连接预算和重复执行语义仍需定义 |
| MCP 协议 | [官方 Go SDK](https://github.com/modelcontextprotocol/go-sdk) 或项目已有 [MCP-Go](https://github.com/mark3labs/mcp-go) | 新项目比较目标版本/传输/客户端；存量不自动迁移。不得编造 gtkit MCP SDK 路径 |
| HTTP 承载、文件、子进程 | 标准库与 SDK 的公开接口 | 不因 HTTP 传输强制 Gin；不为简单操作引入包装框架 |

## 重点限制

- 日志优先采用符合项目需要的 gtkit/logger。SDK 若要求标准库日志接口，仅在边界做必要适配，不混入业务日志系统；不能为避免适配而让日志污染协议流。新版本也须实际验证初始化与崩溃路径的输出。
- 应用 JSON 优先评估 gtkit/json；替换 SDK 内部编码会影响 ID/大整数、schema 和错误响应，没有兼容性证据不得替换。不能仅为速度启用平台相关 build tags。
- SDK 与规范独立演进。读取所选 SDK 版本的支持矩阵/源码，记录目标客户端的实测版本；仓库当前支持某协议不等于旧的锁定版本支持。
- 远程认证可使用外部授权服务器；只有 JWT 能力时不得宣称实现 OAuth。opaque token 与 JWT 的处理按签发方契约选择。
- 依赖故障分别设计总超时、是否重试、退避/次数、停止条件、可观察结果；写工具或结果未知时不自动重试。
- 使用真实包名；发生遮蔽先改善局部命名。别名需保留来源，禁止把 `github.com/golang-jwt/jwt/v5` 叫作另一个库的 `gojwt`。

本 harness 不写入 `go.mod`，不安装任何上述模块。依赖变更遵循实际任务授权与项目流程；配置、示例、文档须同步。
