# API 设计规范 Guide

> 本 guide 约束 HTTP transport 层。具体响应 helper、错误包、middleware 函数名必须以项目真实源码为准；不确定时先 `rg` / `go doc`，禁止照搬不存在的 `response.OK`、`Created`、`Paged` 等 API。

## 统一响应格式

项目应有统一响应信封。常见格式：

```json
{
  "code": 0,
  "msg": "OK",
  "data": {}
}
```

规则：
- `code = 0` 表示成功，非零为业务/错误码。
- 字段名以项目现有协议为准；如果项目使用 `msg`，不要改成 `message`。
- 分页信息可放 `data.paging` 或 `meta`，但一个项目只能统一一种，前后端契约同步。
- `nil` data 的序列化策略以项目 response 包为准，不在 handler 手写。

## 响应工具函数

新增 handler 前先读取项目现有 response 包和同模块 handler。只使用真实存在的 helper。

推荐边界：
- 成功：统一 response helper。
- 参数绑定错误：统一 bind/validation helper。
- 业务错误：handler 用 `errors.Is/As` 映射到项目错误码或 goerr status。
- 未知错误：统一内部错误，日志记录根因，客户端文案脱敏。

禁止：
- handler 手写散乱 JSON。
- handler 返回底层错误字符串给客户端。
- 硬编码裸数字错误码；新增状态前先确认项目错误体系是否已有。

## Handler 标准流程

```go
func (h *Handler) Create(c *gin.Context) {
    var req dto.CreateRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        // 使用项目真实 bind error helper。
        respondBindError(c, err)
        return
    }

    userID := authUserIDFromContext(c)

    cmd := application.CreateCommand{
        Name: req.Name,
    }

    result, err := h.service.Create(c.Request.Context(), userID, cmd)
    if err != nil {
        respondCreateError(c, err)
        return
    }

    respondOK(c, result)
}
```

固定流程：绑定 → 取上下文身份 → DTO 映射 command → 调 application service → response 收口。

禁止在 handler 中：
- 直接操作数据库 / import GORM / import repository
- 编写复杂业务逻辑
- 直接创建外部 SDK client
- 手写多套响应格式

## 错误码规范

- 业务/错误码由项目统一错误体系产生。
- 模块领域 error 在 handler 或 response mapper 中统一映射。
- 数据库、Redis、第三方 SDK 错误不要直接透给客户端。
- 参数、认证、权限、资源不存在、限流、内部错误要有稳定语义。

若项目使用 `github.com/gtkit/goerr`，优先复用已有 `Status*()`；没有合适状态时再按 goerr 的自定义状态 API 新增，禁止随手写裸数字。

## 路由命名

- RESTful 风格：`GET /api/v1/users/:id`
- 动作类用 POST：`POST /api/v1/orders/:id/pay`
- 批量操作用复数：`DELETE /api/v1/users/batch`
- 版本号放 URL：`/api/v1/`

## 请求校验

- 使用 Gin binding tag 做基础校验。
- 更新接口用指针字段支持 partial update。
- 列表接口提供默认值和最大 page size。
- 复杂跨字段校验放 application 或 validator helper，不塞进 handler。

## 中间件顺序

推荐顺序：

```go
r := gin.New()
r.Use(Recovery())      // 最外层，兜住后续 panic
r.Use(ErrorHandler())  // 统一错误处理
r.Use(CORS(...))       // 按配置启用
r.Use(RequestID())     // 请求 ID
r.Use(Logger())        // 请求日志
// 业务路由组再按需加 auth、rate limit、vip/permission 等
```

真实函数名以项目 `internal/middleware` 为准。
