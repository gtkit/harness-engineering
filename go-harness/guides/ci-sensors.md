# CI / 传感器 Guide

> guide 中的硬规则应尽量落成脚本。新增规则前先 grep 存量代码，避免模板与现实冲突。

## 本地入口

优先使用项目统一入口：

```bash
make check
```

没有统一入口时至少执行：

```bash
golangci-lint run ./...
go vet ./...
go fix -diff ./...   # 有输出即失败：现代写法未落地
go test -race -count=1 -timeout=5m ./...
```

架构检查若有脚本：

```bash
scripts/check-architecture.sh
# 或
make check-architecture
```

## 架构传感器应覆盖

- application 禁 import Gin / GORM / repository
- transport/http 禁 import GORM / repository
- repository 禁 import Gin / module
- internal/pkg 禁反向 import module
- worker 禁直接 import GORM / repository
- GORM repo 数据访问统一经 context-aware DB helper，如 `mdbCtx(ctx)`
- application / dto / models 禁 import 基础设施型 paginator

测试文件可单独豁免，避免集成测试误判生产代码。

## CI 要求

- CI 在部署前跑质量检查。
- 部署 job 需要 SSH 凭据时，质量检查 job 不应继承部署用 SSH before_script。
- CI 输出应能区分 lint、vet、race test、架构边界失败。

## 新规则准入

1. 核实现存代码是否已有违例。
2. 有违例则标注存量债务或先整改。
3. 能脚本化的规则同步进入传感器。

## Go 版本升级核对

升 Go 大版本时按序核对，不要只看 `go build` 通过：

1. `go fix -diff ./...` 无输出——新版本引入的 modernizer 已落地。
2. `go.mod` 的 `godebug` 行、源码里的 `//go:debug` 指令、部署脚本的 `GODEBUG=` 环境变量都要查一遍：Go 1.27 移除了 `asynctimerchan`、`tlsrsakex`、`tls10server`、`tls3des`、`x509keypairleaf`、`gotypesalias`、`tlsunsafeekm`。`go.mod` 里留着已移除的开关会让**所有 go 命令直接失败**（`go: error loading go.mod: removed GODEBUG "asynctimerchan" set to old value "1"`），必须先把代码改回标准行为再删掉该行。
3. `go mod tidy -diff`、`go vet ./...`、`go test -race ./...` 全绿后再改 `go.mod` 的 go 指令行。
4. `govulncheck ./...`——大版本切换常伴随标准库漏洞修复窗口变化。
