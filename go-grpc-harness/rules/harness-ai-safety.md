---
paths:
  - "**/.env*"
  - "**/*.pem"
  - "**/*.key"
  - "**/id_rsa*"
  - "**/credentials*"
  - "**/secrets*"
  - "**/*.sql"
  - "**/migrations/**"
  - "**/docker-compose*"
  - "**/Dockerfile*"
---

触碰上述路径前，先完整阅读 `.harness/guides/ai-safety.md`，按其中的规范与检查项实施。该 guide 是本仓库这块领域的单一真源，本规则只负责在你读到这些文件时把它拉进上下文；有冲突以 `CLAUDE.md` 与 guide 为准。

这些路径上的文件承载凭据、真实数据或部署配置，改动前先确认目标不是生产，且不会把真实值写进版本库。
