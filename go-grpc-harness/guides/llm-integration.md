# 大模型对接规范 Guide

> BASE: go-harness/guides/llm-integration.md @ 2026-07-03（通用规则同源;通用改进先落 go-grpc-harness,择机回灌 go-harness）

> LLM 属于外部依赖。具体 provider SDK、stream 类型、token 字段必须以 go.mod 和真实源码为准；禁止臆造 `ChatWithRetry`、`CountTokens`、`Name()`、`<-chan StreamChunk` 等接口。

## 模块结构

推荐按模块化结构组织：

```
internal/
  module/llm/
    application/
      service.go     → 业务编排：会话、鉴权、限额、流式回调
      ports.go       → Provider / Stream / SessionStore / UserRepository 等 port
      errors.go      → 领域 error
    dto/
    transport/http/
      handler.go     → 解请求 + 调 service
      sse_chat.go    → application 回调 → SSE 事件
  runtime/module/llm/
    options.go       → config → provider/session client 装配
  repository/llm_session/
    session.go       → Redis 会话存储（如需）
```

## Provider / Stream port

application 只依赖自己定义的 port：

```go
type Stream interface {
    Recv() (*provider.StreamChunk, error) // io.EOF 表示结束；类型以真实 SDK 为准
    Close() error
}

type Provider interface {
    ChatStream(ctx context.Context, req *provider.ChatRequest) (Stream, error)
}
```

如果项目需要非流式接口、token 计数、provider name，先确认真实 SDK 和业务需要，再在 application port 中显式定义。不要默认生成一组不存在的方法。

## 超时控制

- 非流式调用：通常 30-60s。
- 流式调用：首 chunk 超时和总超时分开控制。
- 使用 `context.WithTimeout` / deadline，不只依赖 `http.Client.Timeout`。
- handler、service、provider client 全链路透传 context。

## 重试与降级

通用建议，落地以项目实际代码为准：

| 错误 | 策略 |
|------|------|
| 429 | 指数退避，有限次数 |
| 500/502/503 | 有限重试，必要时切备用 provider |
| 400 | 不重试 |
| 401/403 | 不重试，检查配置或权限 |
| timeout | 有限重试或降级 |

重试 helper 必须是真实存在的项目包；没有就先实现小而清晰的 retry，不臆造 `Client.ChatWithRetry`。

## 流式响应（SSE）

推荐边界：
- application 通过 callback 或 iterator 驱动业务流。
- transport/http 把业务事件适配成 SSE。
- handler 只负责绑定请求、调用 SSE adapter、握手失败时回 JSON。

事件建议：
- `session`：会话建立
- `chunk`：增量文本
- `done`：正常结束
- `error`：已开流后的错误

握手阶段错误仍用普通 JSON 响应；已开流后的错误用 SSE `error` 事件。

## Token 管控

- 请求前预估 token 消耗，拒绝明显超限请求。
- 记录 prompt_tokens / completion_tokens（如 SDK 可得）。
- 支持按用户/租户维度的限额。
- 超限时优先复用项目已有错误状态，例如 `goerr.StatusQuotaExceeded()`；没有再按统一错误体系新增，禁止硬编码裸数字错误码。

## 敏感信息

- API Key 从配置、环境变量或密钥管理服务获取。
- 日志禁止打印完整 prompt / response / API key。
- 可记录截断文本、长度、hash、模型名、耗时、终态。
- 用户输入发给 LLM 前按业务需要做长度限制和基础校验。

## Prompt 管理

- Prompt 模板若独立管理，放在 `internal/module/llm` 或项目约定目录。
- 使用 `text/template` 或结构化拼接。
- System prompt 与 User prompt 分离。
- 版本、A/B、灰度策略必须显式配置，不和环境名硬绑定。

## 错误类型

模块特有错误放 `module/llm/application/errors.go`，handler 用 `errors.Is` 映射：
- 无效消息 / 会话 ID
- 消息过长
- 需要 VIP / 权限不足
- 会话并发占用
- provider 未配置
- provider 调用失败

错误名以真实代码为准，禁止臆造 `ErrLLM*` 系列。

## 可观测性

建议记录：
- provider 标识、model
- 耗时、首 chunk 延迟
- token 用量（如可得）
- 终态：done / error / timeout / canceled

Prometheus label 必须低基数，不要把 user_id、session_id、prompt hash 当 label。
