# CI / 传感器 Guide（gRPC 服务）

> BASE: go-harness/guides/ci-sensors.md @ 2026-07-03（gRPC 化改写）
> guide 中的硬规则应尽量落成脚本。新增规则前先 grep 存量代码，避免模板与现实冲突。

## 本地入口

优先使用项目统一入口：

```bash
make check
```

`make check` 应聚合：

```bash
golangci-lint run ./...
go vet ./...
go fix -diff ./...   # 有输出即失败：现代写法未落地
go test -race -count=1 -timeout=5m ./...
bash scripts/check-architecture.sh
```

## 架构传感器应覆盖

- `internal/module`（application/transport）禁 import GORM / repository / 渠道 SDK / gobreaker
- `internal/repository` 禁 import module / transport 协议包
- `internal/pkg` 禁反向 import `internal/module`
- worker 禁直接 import GORM / repository
- 有全局唯一性约束的渠道 client（如 token 互斥）：`<sdk>.New(` 全项目单点，传感器白名单只放行供给组件一处
- 传感器用 `grep -rEn`（不用 rg，保证 CI/裸机可移植）；跳过 `*_test.go`

## pb 产物一致性

- `pb/` 禁止手改；模板已带 `make proto-check`（buf lint + generate + `git diff --exit-code pb/ proto/`），**CI 必跑**；本地依赖 buf 工具链故不进默认 `make check`。
- 本地插件版本变化只会引起产物头部注释 diff，属正常噪音，统一重新生成即可。

## CI 要求

- CI 在部署前跑质量检查（make check）。
- 部署 job 需要 SSH 凭据时，质量检查 job 不应继承部署用 SSH before_script。
- CI 输出应能区分 lint、vet、race test、架构边界、pb 一致性失败。

## 新规则准入

1. 核实现存代码是否已有违例。
2. 有违例则标注存量债务或先整改。
3. 能脚本化的规则同步进入传感器（先落 scripts/check-architecture.sh，再考虑 CI）。

## Go 版本升级核对

升 Go 大版本时按序核对，不要只看 `go build` 通过：

1. `go fix -diff ./...` 无输出——新版本引入的 modernizer 已落地。
2. `go.mod` 的 `godebug` 行、源码里的 `//go:debug` 指令、部署脚本的 `GODEBUG=` 环境变量都要查一遍：Go 1.27 移除了 `asynctimerchan`、`tlsrsakex`、`tls10server`、`tls3des`、`x509keypairleaf`、`gotypesalias`、`tlsunsafeekm`。`go.mod` 里留着已移除的开关会让**所有 go 命令直接失败**（`go: error loading go.mod: removed GODEBUG "asynctimerchan" set to old value "1"`），必须先把代码改回标准行为再删掉该行。
3. `go mod tidy -diff`、`go vet ./...`、`go test -race ./...` 全绿后再改 `go.mod` 的 go 指令行。
4. `govulncheck ./...`——大版本切换常伴随标准库漏洞修复窗口变化。
