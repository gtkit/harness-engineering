# 架构约束 Guide（gRPC 服务）

> BASE: go-harness/guides/architecture.md @ 2026-07-03（gRPC 化重写；分层骨架同源，transport 层由 HTTP/Gin 换为 gRPC）
> 本 guide 采用「模块化 + 显式装配」结构。契约先行：proto 是唯一事实源。

## 分层总览

推荐结构：

```
cmd/server/                  → 入口 main，只做 flag 解析后调 bootstrap.Run
proto/<domain>/v1/           → 手写契约（唯一事实源）
pb/<domain>/v1/              → buf generate 产物（禁止手改）
internal/
  bootstrap/                 → 进程级编排：Run(日志→配置→DB→装配→serve→优雅关闭)、
                               gRPC server 装配（拦截器链、服务注册、反射）
  runtime/
    module/<module>/         → 模块装配层：config/db → repo/client/adapter/熔断 → application service
  module/<module>/
    application/             → 业务逻辑层：service、port 接口、领域 error、command/result
    transport/grpc/          → gRPC 适配：pb ↔ application 映射、领域错误 → status code
    worker/                  → 模块后台任务（可选，只依赖 application）
  repository/<table-or-agg>/ → 数据访问层：封装 GORM；简单表一表一 repo
  models/                    → 持久化模型 + 跨层共享值类型/枚举
  platform/
    config/                  → 配置加载（yaml 严格解析 KnownFields，fail-fast）
    data/                    → 基础设施连接管理（ormx MySQL 等）
  pkg/                       → 项目内部共享包（如 breaker）
  shared/                    → 跨模块共享的轻量语义（按需）
```

## 装配边界

1. **`bootstrap/` 只做进程级编排**：`Run(cfgPath) error` 承载完整装配链；main 保持十几行。拦截器链推荐顺序：recovery（最外层）→ 限流 → protovalidate 校验。serve 错误经 channel 传播回 Run，**禁止在 goroutine 里 Fatal**（跳过清理逻辑）；资源用 defer 关闭（错误路径也覆盖）。
2. **`runtime/module/<module>/` 做模块内部装配**：config→options 翻译、创建外部 client、adapter 做类型与错误翻译，再注入 application service。渠道 SDK、熔断器只允许出现在这一层。
3. **`module/<module>/application/` 只保留业务**：service、port、领域 error、command/result。禁止 import GORM、具体 repository、渠道 SDK、gobreaker。

构造函数命名建议：
- `NewService(...)`：模块只产出单个 service。
- `Build(...)`：runtime 装配入口，返回 application 组件。

## 依赖方向

```
cmd → bootstrap
bootstrap → runtime/module, module/<m>/transport/grpc, platform, pb
runtime/module → repository, application, pkg
transport/grpc → application, pb
application → 自身 port, models, shared, 中立错误包
repository → models, 中立错误包
```

`application → models` 允许但应克制：可引用枚举、值类型、只读持久化结构；写操作和复杂业务流优先定义 application 自己的 command/result。

## 禁止规则

- `application` 禁止 import `gorm.io/gorm`、`internal/repository/*`、渠道 SDK、`sony/gobreaker`
- `transport/grpc` 禁止 import `internal/repository/*`、`gorm.io/gorm`、渠道 SDK
- `repository` 禁止 import `internal/module/*`、transport 协议包
- `module/<m>/worker` 只依赖 application，禁止直接 import repository / gorm
- `internal/pkg` 禁止反向 import `internal/module/*`
- `models` 禁止接收 `*gorm.DB` 的数据访问方法
- `pb/` 产物禁止手改；改契约只改 proto + `make gen`
- 外部渠道 client 若有全局唯一性约束（如 token 互斥），必须单点供给：全项目只允许一处 `<sdk>.New(`，用传感器固化

存量项目已有违例时，先记录「存量债务 / 只缩不扩」，不要让新规则和现状无声冲突。

## 可执行检查

项目应有 `scripts/check-architecture.sh` 并纳入 `make check`。没有脚本时按下列 grep 自查（跳过 `*_test.go`，无输出为通过）：

```bash
grep -rEn --include='*.go' --exclude='*_test.go' \
  'gorm\.io/gorm|internal/repository/|sony/gobreaker' internal/module
grep -rEn --include='*.go' --exclude='*_test.go' 'internal/module/' internal/repository internal/pkg
```

## 仓储粒度

- 简单表：一表一 repo。
- 复杂聚合：允许 aggregate repository 覆盖一个聚合根的多表/多介质，README 写明聚合边界。

## 依赖注入

构造函数注入，禁止业务代码依赖全局变量（logger 作为横切关注点豁免，用包级 API）。application 收 port 接口，不收 `*gorm.DB`。

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

## pb ↔ application 映射

- transport/grpc handler 只做三件事：pb 请求 → application input 映射、调 service、application result / 领域错误 → pb 响应 / status code。
- 请求字段校验交给 server 级 protovalidate 拦截器，handler **不重复校验**。
- application 的 command/result 是中立类型，不引用 pb；repository 不得感知 pb。
- 未接入真实实现的 RPC 返回 `codes.Unimplemented` 明示，**禁止返回成功态假数据**（调用方无法区分真假）。

## 错误跨层规则

三段翻译链，每段各司其职：

1. **SDK/驱动错误 → 领域 sentinel**：在 runtime adapter 完成（`errors.Is` 匹配 SDK sentinel，翻译为 application 定义的领域错误，保留排障细节在 message）。
2. **repo 错误**：单一找不到场景用 comma-ok `(T, found bool, error)`；唯一键冲突翻译为 `(conflict bool, error)`（ormx 开 TranslateError 后判 `gorm.ErrDuplicatedKey`），不把 repo sentinel 变成 application 契约。
3. **领域 sentinel → gRPC status code**：在 transport/grpc 完成，映射表见 `grpc-conventions.md`。

## runtime 层职责与红线

runtime 允许：config → options 翻译、创建外部 client、adapter 做类型和错误翻译、per-key 熔断器与 client 同生命周期缓存。
runtime 禁止：用环境名直接推导业务行为；承载业务规则（规则留在 application）。

## 跨 repo 事务

跨多表/多 repo 原子操作由 application 编排，application 通过 `TxManager` port 注入事务能力，不持有裸 `*gorm.DB`。推荐 context-tx 模式（ormx 提供 `WithTx/WithReadTx` 底座）。

## 配置管理

- 用结构体承载配置，不用散落全局变量。
- 配置从外置 YAML 文件加载（config/env/env.yml）：启动一次性读取并校验，**严格解析（`yaml.Decoder.KnownFields(true)`）**——未知/拼错键启动失败，杜绝配置静默失效；缺关键项 fail-fast。
- 运行环境由配置内 env 字段决定，不依赖文件名；业务开关走显式配置项，不按 env 推导。
- 敏感配置（密钥、密码）不进版本控制；env.yml 入 .gitignore，example 入库。
