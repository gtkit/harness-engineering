# internal/pkg Guide

> BASE: go-harness/guides/internal-pkg.md @ 2026-07-03（通用规则同源;通用改进先落 go-grpc-harness,择机回灌 go-harness）

> `internal/pkg` 是项目内部共享包，不等同于对外发布的第三方库。对外扩展包看 `pkg-design.md`。

## 分类

- **纯基础包**：无业务、无 HTTP 协议、无 GORM/Redis 依赖。任何层可 import。
- **基础设施型包**：依赖 GORM/Redis/文件系统/外部 SDK/config/resource。仅 repository、runtime/module、platform 或同类基础设施包可 import。
- **协议适配包**：依赖 gRPC/pb、HTTP(回调 webhook)、响应编码。仅 transport/*、bootstrap 可 import。

## 反向依赖红线

`internal/pkg` 禁止 import：
- `internal/module/*`
- `internal/module/*/application`
- `internal/module/*/dto`

通用能力不得反向知道业务模块。

## 新增包准入

- 只有一个模块使用：优先放模块内部。
- 跨模块复用但有业务语义：放 `internal/shared/<domain>`。
- 无业务语义且可复用：放 `internal/pkg`。
- 面向外部发布：按 `pkg-design.md` 新建独立包。

## 分页包约定

- `internal/pkg/paging`：纯分页结果类型，任何层可 import。
- `internal/pkg/paginator`：GORM 分页查询执行器，application / models 禁止 import。
