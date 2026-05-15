# 架构约束 Guide

## 分层规则

```
cmd/           → 程序入口，只做初始化和启动
internal/
  handler/     → HTTP 处理层：参数绑定、校验、调用 service、返回响应
  service/     → 业务逻辑层：编排业务流程，调用 repository 和外部服务
  repository/  → 数据访问层：封装 GORM 操作，一表一 repo
  model/       → 数据模型（GORM model + 业务 model）
  dto/         → 请求/响应 DTO（Data Transfer Object）
  middleware/  → Gin 中间件
pkg/           → 可复用的公共包（可被外部项目引用）
config/        → 配置加载
```

## 依赖方向（严格单向）

```
handler → service → repository
handler → dto
service → model, repository, dto
repository → model
```

## 禁止规则

- handler 禁止 import repository 包
- handler 禁止 import `gorm.io/gorm`
- service 禁止 import `github.com/gin-gonic/gin`
- repository 禁止 import `github.com/gin-gonic/gin`
- `pkg/` 下的包禁止 import `internal/`
- model 包禁止包含业务逻辑方法（只有字段定义和简单的格式化/校验方法）

## 职责边界

- handler 只处理协议层：参数绑定、输入校验、认证上下文、调用 service、返回响应
- service 负责业务编排、事务边界、领域规则、外部服务协调
- repository 只封装数据访问，不写业务判断和 HTTP 语义
- dto/request/response 只承载传输结构，不承载业务逻辑
- middleware 只处理横切能力，如鉴权、日志、限流、恢复，不承载具体业务流程
- `pkg/` 只放跨项目稳定复用的能力，不收纳业务临时代码

## 抽象准入

只有满足以下任一条件才新增接口、helper、公共包或配置项：

- 已出现 2 处以上真实重复，且抽象后语义更清晰
- 某段逻辑复杂到需要隔离测试
- 需要隔离外部依赖、存储实现、支付渠道、LLM provider 等变化点
- 已有架构约定要求通过接口或封装层访问

不满足准入条件时优先直写清晰代码，不为单次使用提前抽象。

## 依赖注入

使用构造函数注入，禁止全局变量：

```go
type UserService struct {
    userRepo  UserRepository   // 接口，不是具体实现
    cacheRepo CacheRepository
    logger    *zap.Logger
}

func NewUserService(ur UserRepository, cr CacheRepository, l *zap.Logger) *UserService {
    return &UserService{userRepo: ur, cacheRepo: cr, logger: l}
}
```

## 接口定义位置

- Repository 接口定义在 service 层（使用方定义接口）
- Service 接口定义在 handler 层或单独的接口文件中
- 遵循 Go 的隐式接口实现，不要提前抽象

## 配置管理

- 使用结构体承载配置，不用散落的全局变量
- 配置从环境变量或配置文件加载
- 不同环境（dev/staging/prod）的配置严格隔离
- 敏感配置（密钥、密码）不进版本控制

## 可观测性

- 错误要带上下文，方便定位来源和失败阶段
- 外部依赖失败要保留可追踪信息，必要时打 trace / request id
- 关键路径日志应可区分业务失败、依赖失败、参数错误和系统异常

## 兼容性与迁移

- 公开 API、DTO、配置项或默认行为变更时，必须说明兼容策略
- 破坏性变更要明确迁移路径或前向兼容方案
- 数据库 schema 变更要考虑前向部署、回滚和数据填充顺序
