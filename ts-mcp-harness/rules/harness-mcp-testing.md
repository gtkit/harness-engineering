---
paths:
  - "**/*.test.*"
  - "**/*.spec.*"
  - "tests/**"
  - "test/**"
---

读取 `.harness/guides/testing-and-validation.md` 与 `.harness/guides/acceptance-gates.md`。先核对 package script 及 pre/post 行为，不经聚合命令执行未授权检查。mock、构建、安装与真实客户端分别报告；不运行 Go 命令。
