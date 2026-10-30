# TypeScript MCP 技能路由

按当前会话清单读取真实技能路径，不扫描全部目录，不把 doctor 作为前置条件。一次只加载相关主题；技能默认版本、命令和门禁均服从用户授权与实际项目。

| 当前任务 | 技能 |
|---|---|
| TS/Node 服务、异步生命周期、模块与 npm | `senior-nodejs-engineer` |
| 方案与兼容/失败设计 | `tech-design-review` |
| 业务/权限/外部副作用验收 | `backend-acceptance` 的适用项，按本包 acceptance-gates 分流 |
| Shell 安装脚本 | `shell-scripting` |
| Nginx/OpenResty 与 SSE 代理 | `openresty-gateway-operations` |
| 跨组件契约 | `cross-stack-api-contract`，仅确有多个组件时 |
| 供应链、发布 | `polyglot-security-supply-chain` / `polyglot-release-engineering` 的适用项 |
| 实际浏览器界面 | 才加载 `senior-frontend-engineer` / `frontend-acceptance` |

TypeScript MCP 不加载 Go 技能，不套用 Go module、context、goroutine 或 Go 测试命令。没有浏览器、数据库、队列时不增加对应流程。MCP 服务不一定调用 LLM，不能自动加入模型 SDK 或 prompt pipeline。

技能缺失如实记录，可独立完成的授权工作继续；文件存在、运行端可发现、正文已读与检查通过是不同证据。
