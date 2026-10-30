---
paths:
  - "**/go.mod"
  - "**/go.sum"
  - "**/package.json"
  - "**/package-lock.json"
---

改依赖前读取 `.harness/guides/dependencies.md`；Go 版本变化同时读取 `.harness/guides/go-modern.md`。按项目锁定版本核实 gtkit 模块路径、真实包名和 API；不自动安装/升级，不为偏好替换协议 SDK。
