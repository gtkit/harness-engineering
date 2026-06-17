# 发布与供应链安全 Guide

本 guide 约束 Go 扩展包的发布、版本、依赖和供应链安全。只要涉及 tag、module path、依赖新增/升级、漏洞修复、license 或发布流程，就必须读取本文件。

## 发布前门禁

发布前必须通过项目既有 CI。没有统一入口时至少执行：

```bash
go mod tidy
go vet ./...
golangci-lint run ./...
go test -race -count=1 -timeout=5m ./...
go test -bench=. -benchmem -count=3 ./...
go test -coverprofile=coverage.out ./...
govulncheck ./...
```

- `go mod tidy` 后的 `go.mod` / `go.sum` diff 必须可解释。
- Benchmark 结果用于发现明显退化，不要求每次发布都追求更快。
- `govulncheck` 如受环境阻塞，发布说明必须写明未执行原因和替代检查。

## SemVer 与 Tag

- 正式版 tag 必须是 `vX.Y.Z`，禁止 `1.2.3`、`v1.2`、`release-1.2.3`、`latest`。
- 使用附注标签：`git tag -a vX.Y.Z -m "..."`，禁止轻量 tag。
- 已推送 tag 不删除、不重打、不强推；发错版本时发新 PATCH 修复。
- 版本递增规则：
  - MAJOR：不兼容 API / 行为 / 错误类型变更。
  - MINOR：向后兼容新增导出 API、Option、能力。
  - PATCH：Bug 修复、文档修正、内部重构、性能优化。
- `v0.x.y` 开发期也要给下游信号：破坏性变更至少升 MINOR。

## v2+ Module Path

- v2 及以上版本的 `module` 路径必须带 `/v2`、`/v3` 后缀。
- 仓库需通过子目录（如 `v2/`）或独立 major 分支提供对应版本；只打 `v2.0.0` tag 但 module path 不变是错误发布。
- README、GoDoc Example、迁移说明里的 import path 必须同步更新。
- MAJOR 升级必须在 CHANGELOG 和 tag message 中写清迁移路径。

## 依赖治理

- 零外部依赖优先；新增依赖必须说明标准库为何不够。
- 新增依赖检查项：
  - license 与本包发布方式兼容。
  - 维护活跃、版本稳定，不依赖 RC/Beta。
  - transitive dependency 数量可接受。
  - 不引入全局副作用、日志栈绑定或网络初始化。
- 禁止为测试方便把重量级依赖带进生产依赖；测试专用依赖只出现在测试文件导入中。
- `replace` 只能用于本地开发或明确的临时修复，发布前必须移除或说明原因。

## 漏洞与安全发布

- 安全修复放入 CHANGELOG 的 `Security` 区段。
- 漏洞修复优先最小变更，不顺手重构公共 API。
- 涉及凭据、签名、解析器、反序列化、路径处理、压缩包处理、网络请求的变更必须补恶意输入或边界测试。
- 发现密钥入库：立即吊销密钥，再清理历史；不要只删除文件假装已解决。

## 发布产物自检

发布前确认：

- `README.md` 安装命令、import path、Example 与当前版本一致。
- `CHANGELOG.md` 已从 `[Unreleased]` 移动到目标版本区段。
- 所有导出 API 有 GoDoc，核心 API 有可运行 Example。
- `go list -m`、`go test ./...` 在干净 clone 中可通过。
- 没有提交本地产物：`coverage.out`、`dist/`、`bin/`、`.env`、IDE 文件、临时日志。

## Tag Message 模板

```text
版本 vX.Y.Z

主要变更：
- feat: 新增 xxx
- fix: 修复 xxx

破坏性变更（如有）：
- BREAKING CHANGE: xxx 已删除，请使用 yyy 替代

安全修复（如有）：
- 修复 xxx 输入导致的 xxx 风险
```
