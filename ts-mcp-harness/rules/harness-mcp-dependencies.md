---
paths:
  - "**/package.json"
  - "**/package-lock.json"
  - "**/pnpm-lock.yaml"
  - "**/yarn.lock"
  - "**/bun.lock*"
  - "**/tsconfig*.json"
---

读取 `.harness/guides/dependencies.md` 和 `.harness/guides/typescript-runtime.md`。核对实际运行时/锁文件/SDK 代际、ESM/CJS 与 schema；不自动安装、升级、混用锁文件或添加 Go 依赖。
