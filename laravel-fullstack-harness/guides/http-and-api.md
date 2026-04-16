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
- 授权优先放在 `authorize()`
- 自定义错误消息与业务错误分开处理

## Resource 与响应

- 统一使用 `JsonResource` / `ResourceCollection`
- 分页返回保持结构稳定
- 不要在不同接口中随意变换字段命名

## 路由

- 优先跟随项目现有版本化策略
- 若项目已有 API 前缀、版本前缀、命名规范，必须跟随
- `route:list` 应可作为交付前的基础检查

## 错误处理

- 业务异常走统一异常处理层
- 不在 Controller 中散落 `try/catch` 包裹全部逻辑
- 不返回随意拼装的错误数组结构
