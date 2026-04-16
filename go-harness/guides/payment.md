# 支付模块规范 Guide

## 架构原则

支付是金融级业务，必须满足：
- **幂等性**：同一请求重复提交不会重复扣款
- **一致性**：订单状态与支付状态强一致
- **可追溯**：每一步操作都有日志和流水记录
- **安全性**：签名验证、防篡改、防重放

## 模块结构

```
internal/
  payment/
    service.go       # 支付业务编排
    gateway.go       # 支付网关接口（微信/支付宝/银联等）
    callback.go      # 异步回调处理
    refund.go        # 退款逻辑
    types.go         # 支付相关类型定义
    sign.go          # 签名与验签
```

## 核心接口

```go
type PaymentGateway interface {
    // CreateOrder 创建支付订单，返回支付参数（如支付URL、prepay_id等）
    CreateOrder(ctx context.Context, req *CreateOrderReq) (*CreateOrderResp, error)
    // QueryOrder 查询支付订单状态
    QueryOrder(ctx context.Context, orderNo string) (*OrderStatus, error)
    // Refund 发起退款
    Refund(ctx context.Context, req *RefundReq) (*RefundResp, error)
    // VerifyCallback 验证回调签名
    VerifyCallback(ctx context.Context, body []byte, headers map[string]string) (*CallbackResult, error)
}
```

## 幂等性设计

```go
// 使用业务订单号作为幂等键
func (s *paymentService) CreatePayment(ctx context.Context, req *CreatePaymentReq) (*PaymentResp, error) {
    // 1. 检查是否已存在
    existing, err := s.paymentRepo.GetByOrderNo(ctx, req.OrderNo)
    if err != nil && !errors.Is(err, apperror.ErrNotFound) {
        return nil, fmt.Errorf("check existing payment: %w", err)
    }
    if existing != nil {
        if existing.Status == PaymentStatusPaid {
            return existing.ToResp(), nil // 已支付，直接返回
        }
        if existing.Status == PaymentStatusPending {
            return existing.ToResp(), nil // 待支付，返回支付参数
        }
    }

    // 2. 创建支付记录（在调用网关之前）
    payment := &model.Payment{
        OrderNo:   req.OrderNo,
        Amount:    req.Amount,
        Status:    PaymentStatusPending,
        ExpireAt:  time.Now().Add(30 * time.Minute),
    }
    if err := s.paymentRepo.Create(ctx, payment); err != nil {
        return nil, fmt.Errorf("create payment record: %w", err)
    }

    // 3. 调用支付网关
    gatewayResp, err := s.gateway.CreateOrder(ctx, req)
    if err != nil {
        // 标记为失败但不删除记录
        _ = s.paymentRepo.UpdateStatus(ctx, payment.ID, PaymentStatusFailed)
        return nil, fmt.Errorf("create gateway order: %w", err)
    }

    return gatewayResp, nil
}
```

## 回调处理

```go
func (h *PaymentCallbackHandler) HandleWechatCallback(c *gin.Context) {
    // 1. 读取原始 body
    body, err := io.ReadAll(c.Request.Body)
    if err != nil {
        c.String(http.StatusBadRequest, "FAIL")
        return
    }

    // 2. 验签（最重要的一步）
    result, err := h.gateway.VerifyCallback(c.Request.Context(), body, extractHeaders(c))
    if err != nil {
        h.logger.Error("callback verify failed", zap.Error(err))
        c.String(http.StatusBadRequest, "FAIL")
        return
    }

    // 3. 幂等处理
    if err := h.paymentSvc.HandleCallback(c.Request.Context(), result); err != nil {
        h.logger.Error("handle callback failed", zap.Error(err))
        c.String(http.StatusInternalServerError, "FAIL")
        return
    }

    // 4. 返回成功（注意：各支付渠道的成功响应格式不同）
    c.String(http.StatusOK, "SUCCESS")
}
```

## 必须遵守的规则

1. **先落库再调网关**：创建支付记录后才调用支付网关，确保可追溯
2. **回调必须验签**：不验签的回调直接拒绝，防止伪造
3. **回调必须幂等**：同一回调可能发送多次，处理逻辑必须幂等
4. **金额用分（整数）**：禁止使用 float 表示金额，用 int64 表示分
5. **状态机严格**：支付状态只能单向流转，禁止回退
6. **超时关单**：未支付的订单到期自动关闭
7. **主动查询补偿**：回调可能丢失，定时任务主动查询未完结订单
8. **退款走异步**：退款是异步操作，需要轮询或等回调确认
9. **签名密钥从密钥管理服务获取**：禁止硬编码
10. **所有操作记录流水**：支付流水表独立于业务订单表

## 对账

- 每日定时拉取支付渠道的账单
- 与本地支付流水逐笔核对
- 差异记录标记并告警
- 长款（我方未入账）和短款（我方多入账）分别处理
