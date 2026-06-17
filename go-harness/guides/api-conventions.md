# API 设计规范 Guide

## 统一响应格式

所有 API 必须使用统一的 JSON 响应格式：

```json
{
    "code": 0,
    "message": "success",
    "data": {},
    "meta": {
        "page": 1,
        "per_page": 20,
        "total": 100,
        "total_page": 5
    }
}
```

- `code = 0` 表示成功，非零表示错误
- `meta` 仅分页接口返回

## 响应工具函数

```go
response.OK(c, data)                              // 200 成功
response.Created(c, data)                          // 201 创建成功
response.Error(c, httpStatus, bizCode, message)    // 错误响应
response.Paged(c, data, page, perPage, total)      // 分页响应
```

## Handler 标准流程

每个 handler 方法必须遵循固定流程：

```go
func (h *XxxHandler) Create(c *gin.Context) {
    // 1. 参数绑定
    var req dto.CreateXxxReq
    if err := c.ShouldBindJSON(&req); err != nil {
        response.Error(c, http.StatusBadRequest, 2001, err.Error())
        return
    }

    // 2. 调用 service（透传 context）
    result, err := h.svc.Create(c.Request.Context(), &req)
    if err != nil {
        c.Error(err) // 交给 ErrorHandler 中间件统一处理
        return
    }

    // 3. 返回响应
    response.Created(c, result)
}
```

禁止在 handler 中：
- 直接操作数据库
- 编写复杂业务逻辑
- 手动构造 JSON 响应（必须用 response 工具函数）

## 错误码规范

| 范围 | 含义 | 示例 |
|-----|------|------|
| 0 | 成功 | - |
| 1001-1099 | 认证/授权错误 | 1001 未认证, 1002 token 过期, 1003 权限不足 |
| 2001-2099 | 参数校验错误 | 2001 参数格式错误, 2002 必填字段缺失 |
| 3001-3099 | 业务逻辑错误 | 3001 余额不足, 3002 订单已关闭 |
| 4001-4099 | 外部服务错误 | 4001 LLM 服务不可用, 4002 支付网关超时 |
| 5001-5099 | 系统内部错误 | 5001 数据库错误, 5002 缓存错误 |

## 错误体系（apperror）与 ErrorHandler

错误码表要落地，必须有统一的业务错误类型，handler 里 `c.Error(err)` 才能被 `ErrorHandler` 中间件映射成上面的响应格式。

```go
// internal/apperror（或 pkg/apperror）
type Error struct {
    BizCode    int    // 对应错误码表，如 3001
    HTTPStatus int    // 映射的 HTTP 状态码，如 400
    Message    string // 面向客户端的安全文案（不泄漏内部细节）
    cause      error  // 内部根因，仅用于日志，不返回客户端
}

func (e *Error) Error() string { return e.Message }
func (e *Error) Unwrap() error { return e.cause }

// 预定义 sentinel + 构造器
var ErrNotFound = &Error{BizCode: 3404, HTTPStatus: 404, Message: "资源不存在"}
func Wrap(bizCode, httpStatus int, msg string, cause error) *Error { /* ... */ }
```

- service 层返回 `apperror.Error`（或包装 sentinel），handler 只 `c.Error(err)` 不自行映射。
- `ErrorHandler` 中间件：`errors.As(err, &ae)` 命中 `*apperror.Error` 时按 `BizCode/HTTPStatus/Message` 输出；未命中（未知错误）统一记 5001 + HTTP 500，**只记日志不暴露内部信息**。
- 客户端文案与内部根因分离：`Message` 给用户，`cause` 进日志。

## 鉴权与限流

错误码 1001-1003 和 review-checklist 的"走 auth 中间件""有限流"要有落地约定，否则 AI 会自行编造。

- **鉴权中间件**：解析并校验 token（JWT 或项目既有方案）后，把身份写入 `context`，用**统一的 context key**（如 `type ctxKey int; const userIDKey ctxKey = iota`，避免裸字符串 key）。下游通过 helper（如 `auth.UserID(ctx)`）读取，禁止各层各取各的。
  - 校验失败返回 1001（未认证）/ 1002（token 过期）/ 1003（权限不足），对应 HTTP 401/401/403。
- **限流**：单机用标准库 `golang.org/x/time/rate`；分布式按用户/IP 维度用 `redis/go-redis` 实现滑动窗口或令牌桶。限流命中返回 429。
- 鉴权、限流中间件只加在**业务路由组**，不污染健康检查 / 回调等公开端点。

## 路由命名

- RESTful 风格：`GET /api/v1/users/:id`
- 动作类用 POST：`POST /api/v1/orders/:id/pay`
- 批量操作用复数：`DELETE /api/v1/users/batch`
- 版本号放在 URL 中：`/api/v1/`, `/api/v2/`

## 请求校验

- 使用 binding tag 做基本校验：`binding:"required,min=2,max=50"`
- 自定义校验器注册到 validator
- 更新接口使用指针字段支持 partial update：`Name *string`
- 列表接口提供默认值：page=1, per_page=20

## 中间件顺序

```go
r := gin.New()
r.Use(middleware.Recovery(logger))      // 1. panic 恢复
r.Use(middleware.ErrorHandler(logger))  // 2. 统一错误处理
r.Use(middleware.RequestLogger(logger)) // 3. 请求日志
r.Use(middleware.CORS())                // 4. 跨域
// 业务路由组中再加 auth、ratelimit 等
```
