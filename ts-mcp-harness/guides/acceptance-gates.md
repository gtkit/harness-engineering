# TypeScript MCP 交付验收

本指南是 `ts-mcp-harness` 的专用路由，优先于共享工作流按扩展名或 Web 项目假设的默认分流。TypeScript MCP 是服务端程序，不因 TS/npm 自动执行浏览器前端验收，也不调用 Go 技能。

| 改动 | 验收范围 |
|---|---|
| 文档、注释、规则 | 只回读指定内容，不测试或构建 |
| 工具与 stdio | 业务、SDK 适配、进程生命周期和真实依赖；按 backend-acceptance 的适用条目审视 |
| Streamable HTTP | 业务加身份/权限、流、取消、限额、代理及停机 |
| npm 安装/分发 | bin/产物、运行时/平台、生产依赖、禁用脚本与失败恢复 |
| 真实浏览器 UI | 只有实际修改界面时追加 frontend-acceptance |

具体矩阵见 `.harness/guides/testing-and-validation.md` 和 `.harness/guides/release-and-distribution.md`。无数据库时不测试数据库，无客户端证据不宣称宿主兼容；规则分发成功不代表应用已通过这些场景。

交付包含授权范围、实际文件、版本组合、已执行命令/退出码、真实行为结果、未执行/未验证/不适用、安装及发布状态。质量检查在功能完成后单独确认，未授权不运行聚合门禁，不因缺少无关工具否定已完成证据。
