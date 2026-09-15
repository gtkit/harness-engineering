# 支付模块规范 Guide

> 支付是高风险业务。接口名、SDK 类型、渠道枚举必须以真实依赖为准；若使用 `github.com/gtkit/go-pay/paymgr`，优先走 paymgr 的统一抽象，不要臆造 `CreateOrder` / `Refund` / `VerifyCallback`。

## 架构原则

- 幂等性：重复请求、重复回调不会重复扣款/交付。
- 一致性：订单、支付流水、权益交付状态有明确事务边界。
- 可追溯：关键操作有流水和日志。
- 安全性：验签、防篡改、防重放、密钥不硬编码。

## 模块结构

支付能力可落在 `order` 聚合，也可独立为 `payment` 模块：

```
internal/
  module/order/ 或 module/payment/
    application/
      payment.go          → 支付业务编排
      ports.go            → PaymentGateway / repo / delivery port
      commands.go         → CreatePaymentInput/Output 等
    dto/
    transport/http/
      handler.go          → 下单、回调、查询
      router.go
    worker/               → 超时关单、查单补偿、对账
  runtime/module/<module>/
    options.go            → config → gateway client / repo / service
  repository/order/ 或 repository/payment/
```

边界：
- PaymentGateway 是 application port，具体 SDK client 在 runtime 层创建并注入。
- 签名、验签、回调解析属于 gateway adapter 或 transport 层，不渗入 application 的业务状态机。
- application 禁止 import GORM / repository。

## PaymentGateway port

若使用 `paymgr`，接口通常类似：

```go
type PaymentGateway interface {
    UnifiedOrder(ctx context.Context, ch paymgr.Channel, req *paymgr.UnifiedOrderRequest) (*paymgr.UnifiedOrderResponse, error)
    CloseOrder(ctx context.Context, ch paymgr.Channel, req *paymgr.CloseOrderRequest) error
    QueryOrder(ctx context.Context, ch paymgr.Channel, req *paymgr.QueryOrderRequest) (*paymgr.QueryOrderResponse, error)
    ParseNotify(ctx context.Context, ch paymgr.Channel, r *http.Request) (*paymgr.NotifyResult, error)
    ACKNotify(ch paymgr.Channel, w http.ResponseWriter) error
}
```

版本不同签名可能不同，写代码前必须确认真实 go doc。

## 下单幂等

固定原则：
1. 校验商品/权益/金额。
2. 查找可复用的待支付订单。
3. 不可复用则关闭旧单或创建新单。
4. **先落库，再调网关**。
5. 注册超时关单和状态缓存。
6. 调网关统一下单，返回客户端调起参数。

金额使用整数分 `int64`，禁止 float。

## 回调处理

推荐流程：

```
ParseNotify（验签 + 解析）
  → HandlePayNotify（状态机 + 幂等 + CAS）
  → ACKNotify（渠道格式应答）
```

关键规则：
- 验签失败不 ACK，记录安全日志。
- 重复回调必须幂等。
- 金额/交易号不一致只记录异常并告警，不擅自交付。
- 交付失败通常不把错误返回给支付网关，避免重试风暴；依赖 fallback scanner 补偿。

## 状态机

只允许白名单状态迁移。示例：

```
pending → paid → delivered → completed
pending → closed
paid → refunding → refunded
```

支付竞态恢复可作为明确例外，例如 `closed -> paid`：必须先 `QueryOrder` 复核、校验金额、CAS 重开，再继续交付。禁止绕过状态机随意回退。

## 必须遵守

1. 先落库再调网关。
2. 回调必须验签。
3. 回调必须幂等。
4. 金额用分，禁止 float。
5. 状态迁移走白名单 + CAS。
6. 未支付订单有超时关单。
7. 回调丢失有主动查单补偿。
8. 退款异步化，轮询或回调确认。
9. 签名密钥来自配置/密钥管理服务。
10. 支付流水独立记录，可审计。

## 对账

- 定时拉取渠道账单。
- 与本地流水逐笔核对。
- 差异记录、告警、人工处理入口清晰。
- 长款/短款分别处理。
