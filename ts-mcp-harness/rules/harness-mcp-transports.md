---
paths:
  - "**/transport/**"
  - "**/transports/**"
  - "**/*stdio*.*"
  - "**/*http*.*"
  - "**/*server*.*"
  - "**/*main*.*"
---

先读 `.harness/guides/architecture.md`，再按实际模式读 `.harness/guides/mcp-stdio.md` 或 `.harness/guides/mcp-streamable-http.md`。两者都受影响才同时加载；核对 SDK 代际和协议版本，不凭路径猜测实现。
