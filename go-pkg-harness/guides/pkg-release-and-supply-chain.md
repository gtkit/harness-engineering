# 发布与供应链安全 Guide

本 guide 约束 Go 扩展包的发布、版本、依赖和供应链安全。只要涉及 tag、module path、依赖新增/升级、漏洞修复、license 或发布流程，就必须读取本文件。

## 发布入口

发版走 Makefile 的两步流程，本地门禁与标签发布分开：

```bash
make release-patch   # PATCH：bug 修复 / 文档修正 / 内部重构 / 性能优化
make release-minor   # MINOR：向后兼容的新增导出 API、Option、能力
```

`release-*` 依次执行工作区干净检查、空白检查（`git diff --check` 上一个 tag..HEAD）、`go mod tidy -diff`、`go vet`、`go fix -diff`、`golangci-lint`、`gofumpt` 只读检查、race 测试、`EXTRA_TEST_TARGET`（配置了才跑）、覆盖率门禁、benchmark、`govulncheck`、`gosec`；全部通过后原地自增 `version.go` 的 `Version` 常量、提交、打附注标签、推送主干分支。**标签留在本地。**

远端 CI 全绿后再发布标签：

```bash
make push-tag
```

`push-tag` 核对该 commit 的 GitHub check-runs 结论，全绿才推送标签。已人工确认 CI 通过但 API 查不到（仓库私有、限额、网络）时用 `make push-tag SKIP_CI_CHECK=1`。

标签之所以分两步推：Go module proxy 抓取标签后永久缓存，删除或覆盖都收不回来，所以推标签前必须先拿到远端 CI 的结论。本地门禁只能证明本机通过，跨平台 job 和 CI 专有的集成测试本机跑不到。

可按包覆盖的配置：`BUMP`、`RELEASE_REMOTE`、`COVERAGE_MIN`（0 表示不检查）、`REQUIRE_CHANGELOG`、`EXTRA_TEST_TARGET`。

使用约束：

- `BUMP` 只接受 `patch` 和 `minor`。传 `major` 会被拒绝并指向 MINOR 路径——只 bump tag 而不改 module path 是错误发布。
- `REQUIRE_CHANGELOG=1`（默认）时 `CHANGELOG.md` 必须已有 `## [vX.Y.Z] - YYYY-MM-DD` 条目，脚本会把该条目正文写进 tag message。
- `version.go` 里 `const Version = "vX.Y.Z"` 这行的形状不能改，注释中不能出现版本号字面量——脚本取文件里第一个匹配到的版本号。
- 格式化只走 `make fmt`；`make tool` 是只读检查，发现未格式化文件会失败而不是就地改写。

## 发布前门禁

`release-*` 已包含下列检查。手工核对或在没有 Makefile 的包里发布时，至少执行：

```bash
go mod tidy
go vet ./...
go fix -diff ./...
golangci-lint run ./...
go test -race -count=1 -timeout=5m ./...
go test -bench=. -benchmem -count=3 ./...
go test -coverprofile=coverage.out ./...
govulncheck ./...
```

- `go mod tidy` 后的 `go.mod` / `go.sum` diff 必须可解释。
- `go fix -diff` 有输出即发版失败：说明新版本 Go 的 modernizer 还没落地，先 `go fix ./...` 应用并复核。
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
