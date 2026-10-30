# TypeScript MCP 依赖

沿用已有适用依赖；运行时内建能力足够时不增加包。新增依赖先核实模块名、精确版本、导出、运行时/平台支持、生命周期、安全边界和维护来源，不写未经验证的 API 示例，不自动升级主版本。

## SDK 代际

截至 2026-10-30 核对的[官方 TypeScript SDK](https://github.com/modelcontextprotocol/typescript-sdk)：v1 使用 `@modelcontextprotocol/sdk`；v2 拆分为 `@modelcontextprotocol/server`、`@modelcontextprotocol/client`，另有可选 HTTP 适配包。这里只说明识别方法，不是迁移授权。按项目锁定代际读对应文档，不能混用 import、schema 约定、传输实现或认证 API。

服务端项目没有客户端能力需求时不额外引入客户端 SDK；SDK 宣称支持某传输不代表项目所用旧版本、目标运行时或宿主已实测兼容。不要自行实现 JSON-RPC/SSE 编解码替代已有协议能力。

## 选择与边界

| 能力 | 原则 |
|---|---|
| 运行时 | 沿用 Node.js/Bun/Deno 的实际选择，核实 SDK、原生模块和部署平台支持；不因 TS 相同就宣称互通 |
| schema | 使用所选 SDK 支持的校验器及版本；JSON Schema、TS 类型与运行时行为一致 |
| 日志 | 优先现有日志方式，实际验证 stderr 目标与初始化输出，禁止污染 stdio stdout |
| HTTP | 使用 SDK 适配和已有框架，不重复 body 解析，不破坏流式响应 |
| 认证 | 优先标准授权组件；JWT 签验不能替代完整 OAuth 或资源权限 |
| 存储/队列 | 仅在持久化/共享状态确有需求时引入，明确连接、重试、隔离和关闭 |

不使用 Go、gtkit 或 Go 工具链。包管理器依据 `packageManager`、锁文件和已有命令核对，不能混用 npm/pnpm/yarn/bun 锁文件。安装前核对 lifecycle scripts 与原生构建副作用；安装、审计、质量检查、发布分别服从授权。

SDK 编码行为默认保留：大整数、`undefined`/null、Date、BigInt、Buffer、循环引用及错误对象不能依靠类型断言直接作为协议 JSON。应用自定义转换必须有兼容证据。
