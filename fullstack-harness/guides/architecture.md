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
