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

- `pb/` 禁止手改；CI 可加一致性检查：`make gen && git diff --exit-code pb/`（proto 与产物不同步即失败）。
- 本地插件版本变化只会引起产物头部注释 diff，属正常噪音，统一重新生成即可。

## CI 要求

- CI 在部署前跑质量检查（make check）。
- 部署 job 需要 SSH 凭据时，质量检查 job 不应继承部署用 SSH before_script。
- CI 输出应能区分 lint、vet、race test、架构边界、pb 一致性失败。

## 新规则准入

1. 核实现存代码是否已有违例。
2. 有违例则标注存量债务或先整改。
3. 能脚本化的规则同步进入传感器（先落 scripts/check-architecture.sh，再考虑 CI）。
