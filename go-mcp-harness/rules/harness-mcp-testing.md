---
paths:
  - "**/*_test.go"
  - "**/*.test.js"
  - "tests/**"
---

读取 `.harness/guides/testing-and-validation.md` 与 `.harness/guides/acceptance-gates.md`。按真实传输/版本选择测试，不用 mock 冒充客户端或真实依赖验证，不创建项目副本；纯文档任务不触发测试。
