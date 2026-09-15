---
paths:
  - "**/*.lua"
---

触碰上述路径前，先完整阅读 `.harness/guides/lua-baseline.md`，按其中的规范与检查项实施。该 guide 是本仓库这块领域的单一真源，本规则只负责在你读到这些文件时把它拉进上下文；有冲突以 `CLAUDE.md` 与 guide 为准。

本次改动涉及 JSON 编解码、大整数 ID、空数组或 `ngx.null` 判断时，同时读 `.harness/guides/data-encoding.md`；涉及跨请求缓存、计数、限流时，同时读 `.harness/guides/shared-state.md`。
