---
paths:
  - "**/package.json"
  - "**/*.sh"
  - "**/*.ps1"
  - "**/*.bat"
  - "**/bin/**"
  - "**/scripts/**"
  - "**/.mcp.json"
  - "**/plugin.json"
  - ".github/workflows/**"
---

读取 `.harness/guides/release-and-distribution.md`。核对实际 npm 产物与启动入口、生产依赖、运行时/平台、标准流和退出；TypeScript 服务不添加 Go 构建或二进制安装链。安装、部署、发布和质量检查分别按授权执行。
