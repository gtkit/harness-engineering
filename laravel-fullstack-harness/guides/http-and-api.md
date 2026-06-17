# Laravel HTTP 与 API Guide

## Controller 固定流程

推荐顺序：

1. 接收 `FormRequest`
2. 调用 Action / Service
3. 使用 Resource / ResourceCollection 返回
4. 不在 Controller 内直接拼复杂业务或事务

```php
public function store(StoreOrderRequest $request, CreateOrderAction $action): OrderResource
{
    $order = $action->handle($request->validated(), $request->user());

    return new OrderResource($order);
}
```

## Request 与 Validation

- 校验优先放在 `FormRequest`
- 自定义错误消息与业务错误分开处理

## 授权（Policy / Gate）

- 对象级 / 资源级授权用 **Policy**（`$this->authorize('update', $order)` 或 `authorizeResource`），不要把授权判断散落在 Service 里
- `FormRequest::authorize()` 只做**粗粒度准入**（是否登录 / 角色），细粒度对象权限交给 Policy
- 简单全局开关用 `Gate::define`；不要在多处重复同一套权限判断

## Resource 与响应

- 统一使用 `JsonResource` / `ResourceCollection`
- 分页返回保持结构稳定
- 不要在不同接口中随意变换字段命名

## 路由与安全

- 优先跟随项目现有版本化策略；若无既有策略，新项目默认 URI 前缀版本化（`/api/v1`），保持向后兼容
- 若项目已有 API 前缀、版本前缀、命名规范，必须跟随
- `route:list` 应可作为交付前的基础检查
- **CSRF**：Web 表单走 `web` 中间件组自带 CSRF；无状态 API 用 token（Sanctum / Passport），不要给 API 关 CSRF 又用 cookie 会话
- **限流**：对外接口加 `throttle` 中间件（按用户 / IP）；对外暴露的临时链接用签名 URL（`URL::signedRoute`）

## 错误处理与响应契约

- 业务异常走统一异常处理层（`bootstrap/app.php` 的 `withExceptions` 或异常 `render()`），不在 Controller 中散落 `try/catch` 包裹全部逻辑
- **统一错误响应结构**，不返回随意拼装的数组。约定最小结构：
  ```json
  { "message": "人类可读信息", "errors": { "field": ["逐字段校验错误"] }, "code": "可选业务码" }
  ```
- **状态码映射**：校验失败 422（`errors` 按字段）、未认证 401、未授权 403、资源不存在 404、冲突 409、服务端 500
- 错误响应字段命名跨接口保持一致；全栈项目此结构即前后端错误契约的来源
