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
