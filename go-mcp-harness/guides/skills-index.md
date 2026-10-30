# Go MCP 技术技能路由

使用当前会话已提供的技能清单和真实路径，不扫描全部技能，不把 doctor 作为前置检查。一次先读取主路径需要的少量技能，涉及后续主题时再加载；技能正文不能扩大用户授权。

| 当前任务 | 技能 |
|---|---|
| Go 源码修改 | `use-modern-go`；`go-enterprise-quality` 中适用内容，受控检查仍需授权 |
| 复杂任务分流 | `go-task-router`；单一明确专项直接读取专项 |
| Go 架构/方案 | `senior-go-engineer`、`tech-design-review` |
| context/取消/关闭 | `go-context`；涉及并发再读 `go-concurrency` |
| 错误与部分成功 | `go-error-handling` |
| HTTP 服务边界 | `engineering-skills-for-go:go-service-boundaries`；确有 Gin 才读 `go-gin-api` |
| HTTP 流与连接 | `go-websocket-sse`，协议语义仍以目标 MCP 版本为准 |
| 文件、命令、SSRF、授权 | `go-security` 或 `engineering-skills-for-go:go-security-hardening` |
| 日志、指标、trace | `go-observability` |
| Go 功能测试 | `go-testing` |
| 实测性能优化 | `go-performance` 或 `engineering-skills-for-go:go-performance-and-diagnostics` |
| 运行行为验收 | `backend-acceptance` 中适用项；遵守 `.harness/guides/acceptance-gates.md` |
| Go diff 审查 | `go-review` |
| Node 安装器/启动器 | `senior-nodejs-engineer`；不因此触发浏览器前端技能 |
| Shell 安装脚本 | `shell-scripting` |
| Nginx/OpenResty 代理 | `openresty-gateway-operations` |
| 多平台分发/供应链 | `go-engineering-governance`；按需要追加 `polyglot-security-supply-chain` |

数据库、Redis、MQ、浏览器 UI 只有实际涉及时才从当前技能清单选择相应专项。MCP 服务本身不必调用 LLM；不得因名称含 AI 自动引入模型 SDK、prompt pipeline 或支付模块。

缺失技能记录影响与可替代的官方/源码依据；文件存在、运行时可发现、实际读取和检查通过分别报告。
