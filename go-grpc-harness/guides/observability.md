# 可观测性 Guide

> BASE: go-harness/guides/observability.md @ 2026-07-03（通用规则同源;通用改进先落 go-grpc-harness,择机回灌 go-harness）

> 日志、指标、告警 API 以项目真实依赖为准。示例中的字段名表达结构化日志意图，不代表具体 logger 函数签名。

## 日志

- 字段 key 稳定，优先 snake_case：`user_id`、`order_no`、`request_id`、`duration_ms`。
- 错误日志包含操作上下文，不只打印 `err`。
- 热路径避免频繁 Info；异常路径 Warn/Error。
- 禁止打印密码、token、完整 API key、完整 prompt、完整请求体、支付签名密钥。
- 对外错误文案经 response/handler 映射，底层错误只进日志。

## 指标

新增外部调用、worker、支付、LLM、缓存关键路径时考虑：
- 请求/任务总数：success / error / timeout / canceled
- 耗时分布
- 队列积压、租约超时、重试次数
- 缓存 hit / miss / backfill / delete_failed

Prometheus label 必须低基数。禁止 user_id、order_no、session_id、prompt hash 作为 label。

## 告警

高风险事件必须有日志或指标：
- 支付金额不一致、交易号不一致、伪造回调
- 订单交付失败进入 fallback
- LLM provider 未配置、持续超时、会话并发 gate 异常
- Redis / DB / 第三方 SDK 连续失败
- worker panic 或异常退出

## Request ID / Trace

HTTP 全局中间件应注册 request id。handler、worker、外部调用尽量透传 request id / trace id；后台任务没有 request id 时生成 task/job 标识。
