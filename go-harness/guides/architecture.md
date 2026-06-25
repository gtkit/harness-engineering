# 架构约束 Guide

> 本 guide 采用「模块化 + 显式装配」结构。旧式 `handler/service/repository` 三层口径不再作为默认模板；若存量项目仍是旧结构，先确认迁移策略，不要把两套规则混用。

## 分层总览

推荐结构：

```
cmd/                         → CLI 入口与子命令，只做参数解析与启动
internal/
  appmeta/                   → 应用级常量与路径元信息
  bootstrap/                 → 进程级编排：拿资源、调 runtime constructor、挂 router/worker
  runtime/
    module/<module>/         → 模块装配层：config/db/cache → repo/client/adapter → application service
    resource/                → 运行期工具，不承载业务 DAO
  module/<module>/
    application/             → 业务逻辑层：service、port 接口、领域 error、command/result、options
    dto/                     → 模块独有请求/响应 DTO
    transport/http/          → HTTP 适配：handler 绑定/校验、router 注册
    worker/                  → 模块后台任务（可选）
  repository/<table-or-agg>/ → 数据访问层：封装 GORM/Redis；简单表一表一 repo，复杂聚合可用 aggregate repo
  models/                    → 持久化模型 + 跨层共享值类型/枚举
  middleware/                → Gin 中间件
  router/                    → 路由聚合、版本化模块注册、健康检查路由
  platform/
    config/                  → 配置加载
    data/                    → 基础设施连接管理（DB/Redis）
  pkg/                       → 项目内部共享包
  shared/                    → 跨模块共享的轻量语义
  scaffold/                  → 开发期脚手架/代码生成工具（可选）
```

## 装配边界

1. **`bootstrap/` 只做进程级编排**：拿基础设施资源、调用各模块 runtime constructor、组装 router 与 worker、决定实例生命周期。不在这里直接拼模块内部 repo/client/service。
2. **`runtime/module/<module>/` 做模块内部装配**：把 `config/db/cache` 翻译成 repo / client / adapter，再注入 application service。模块对外只暴露少量构造函数。
3. **`module/<module>/application/` 只保留业务**：service、port、领域 error、command/result、options。禁止 import Gin、GORM、具体 repository。

构造函数命名建议：
- `NewService(...)`：模块只产出单个 service，且不需要 `*config.Config`。
- `NewServiceWithConfig(...)`：单个 service，需要 `*config.Config` 做 options 翻译。
- `NewServicesWithConfig(...)`：一次装配并返回多个 service。

规则：复数 `Services` 表示返回多个；`WithConfig` 表示依赖 `*config.Config`。存量项目不符合时，标注存量例外，避免在无关任务里顺手重命名。

## 依赖方向

业务主脊：

```
bootstrap → runtime/module → application
runtime/module → repository, application
transport/http → application, module/<m>/dto
application → 自身 port, models, module/<m>/dto, shared, 中立错误包
repository → models, 中立错误包
```

`application → models` 允许但应克制：可引用枚举、值类型、只读持久化结构；写操作和复杂业务流优先定义 application 自己的 command/result，避免完整 model 长期扩散到 API result。

## 包可见范围

- **纯基础包：任何层可 import**。无业务、无 HTTP 协议、无 gorm/redis 依赖的工具包，以及 `appmeta`、`models`、`shared/*`。纯分页结果类型建议放 `internal/pkg/paging`。
- **基础设施型包：仅 repository、runtime/module、platform 可 import**。依赖 GORM/Redis/文件系统/外部 SDK 的工具包，例如 GORM 分页执行器 `internal/pkg/paginator`。
- **协议/HTTP 适配包：仅 transport/http、router、middleware 可 import**。例如 response、sse、gin context helper、中间件。

分页边界建议：
- `internal/pkg/paging`：纯分页结果类型，任何层可 import。
- `internal/pkg/paginator`：GORM 查询执行器，application / dto / models 禁止 import。

## 禁止规则

- `application` 禁止 import `gorm.io/gorm`
- `application` 禁止 import `internal/repository/*`
- `application` 禁止 import `github.com/gin-gonic/gin`
- `transport/http` 禁止 import `internal/repository/*` 与 `gorm.io/gorm`
- `repository` 禁止 import `github.com/gin-gonic/gin`
- `repository` 禁止 import `internal/module/*`
- `module/<m>/worker` 只依赖 application，禁止直接 import repository / gorm
- `internal/pkg` 禁止反向 import `internal/module/*`
- `models` 禁止接收 `*gorm.DB` 的数据访问方法；业务规则方法优先放 application

存量项目已有违例时，先记录「存量债务 / 只缩不扩」，不要让新规则和现状无声冲突。

## 可执行检查

项目若有 `scripts/check-architecture.sh` 或 `make check-architecture`，提交前必须运行。没有脚本时，按下列 grep 自查（跳过 `*_test.go`）：

```bash
rg -n 'gorm\.io/gorm|internal/repository/|github\.com/gin-gonic/gin' internal/module/*/application --glob '!**/*_test.go'
rg -n 'internal/repository/|gorm\.io/gorm' internal/module/*/transport/http --glob '!**/*_test.go'
rg -n 'github\.com/gin-gonic/gin|internal/module/' internal/repository --glob '!**/*_test.go'
rg -n 'internal/module/' internal/pkg --glob '!**/*_test.go'
rg -n 'internal/repository/|gorm\.io/gorm' internal/module/*/worker --glob '!**/*_test.go'
```

约定：无输出为通过；有输出先判断是否是已记录的存量债务。

## 仓储粒度

- 简单表：一表一 repo。
- 复杂聚合：允许 aggregate repository 覆盖一个聚合根的多表/多介质。聚合 repo README 应包含「聚合边界」：覆盖表、外部介质、事务边界、缓存边界。

## 依赖注入

构造函数注入，禁止业务代码依赖全局变量。application 收 port 接口，不收 `*gorm.DB`。

```go
type OrderServiceDeps struct {
    OrderRepo   OrderRepository
    StatusCache StatusCache
}

func NewOrderService(deps OrderServiceDeps) *OrderService { /* ... */ }
```

`db → repo → adapter → service` 的拼装放在 `runtime/module/<module>`。

## 接口定义位置

- Repository / 外部依赖 port 定义在 application 层（使用方定义接口），通常放 `ports.go`。
- 遵循 Go 隐式接口实现，不提前抽象。
- 无基础设施依赖的极简模块可豁免 runtime 装配层，但要保持边界清晰。

## DTO 归属

- 模块独有 DTO 放 `module/<module>/dto`，包名用 `dto`。
- 真正跨模块共享的轻量类型放 `internal/shared/...`，不要塞进某个模块让别的模块横向 import。
- 写操作 / 复杂业务流：handler 做 DTO ↔ application command 映射。
- 简单读接口：可复用无 binding/form tag 的响应 DTO。
- repository 不得 import 模块 dto；查询条件用 repo 自己的 query/options，或 application port 的中立输入类型，由 runtime adapter 桥接。

## 错误跨层规则

repo 不得把自己的 sentinel 变成 application 必须 import 的契约。按场景选：

1. **comma-ok**：单一找不到场景，port 返回 `(T, found bool, error)`。
2. **中立错误包**：真正跨模块复用的 NotFound / Conflict / Unauthorized 等可放 `internal/apperror`，但不要提前创建空包。
3. **runtime adapter 翻译**：模块特有 repo sentinel 在 runtime adapter 翻译成 application 领域错误。

## runtime 层职责与红线

runtime 允许：
- `config → options` 翻译
- 创建外部 client
- adapter 做类型和错误翻译

runtime 禁止：
- 用环境名直接推导业务行为。环境只选择配置，业务开关走显式配置项。
- 承载业务规则。规则留在 application。

## 跨 repo 事务

跨多表/多 repo 原子操作由 application 编排，application 通过 `TxManager` port 注入事务能力，不持有裸 `*gorm.DB`。

推荐 context-tx 模式：事务 manager 把 tx 放进 context；repo 的 `mdbCtx(ctx)` 从 context 取 tx，否则回退到默认 DB。

约定：
- repo 数据访问统一经 `mdbCtx(ctx)`。
- repo 内部可用事务处理单 repo / 聚合内部多语句写。
- 跨多个 repo 的业务事务由 application 的 `TxManager.Do` 编排。

## 配置管理

- 用结构体承载配置，不散落全局变量。
- 配置从环境变量或配置文件加载。
- dev/staging/prod 配置隔离。
- 敏感配置不进版本控制。
