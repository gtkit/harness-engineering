---
paths:
  - "**/lua/resty/**"
  - "**/lua/vendor/**"
  - "**/lualib/**"
---

触碰上述路径前，先完整阅读 `.harness/guides/vendor-and-deps.md`，按其中的规范与检查项实施。该 guide 是本仓库这块领域的单一真源，本规则只负责在你读到这些文件时把它拉进上下文；有冲突以 `CLAUDE.md` 与 guide 为准。

这些路径下是第三方代码。出现在 diff 里本身就需要解释，先确认这次改动是否真的必须动它。
