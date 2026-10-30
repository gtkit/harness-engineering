---
paths:
  - "**/*.sh"
  - "**/*.ps1"
  - "**/*.bat"
  - "**/install.js"
  - "**/launch.js"
  - "**/package.json"
  - "**/package-lock.json"
  - "**/*.mjs"
  - "**/*.cjs"
  - "**/*.ts"
  - "**/.mcp.json"
  - "**/plugin.json"
  - ".github/workflows/**"
---

读取 `.harness/guides/release-and-distribution.md`。命令、平台、版本、下载校验、输出与退出码按真实宿主/依赖核实。只准备分发文件不代表已获得安装、部署或发布授权；脚本 lint 也须单独授权。

JS/TS 路径仅提示核对 npm 安装器/启动器的实际职责；MCP 服务仍为 Go 时不改套 TS 服务架构，也不因 npm 分发要求用户安装 Go。
