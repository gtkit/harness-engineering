# 大模型对接规范 Guide

## 架构模式

LLM 调用属于"外部服务"，封装在独立包中：

```
internal/
  llm/
    client.go        # HTTP Client 封装
    provider.go      # Provider 接口定义
    stream.go        # SSE 流式响应处理
    retry.go         # 重试 + 降级逻辑
    token_counter.go # Token 计数与限额
    types.go         # 请求/响应结构体
```

## Provider 接口（必须实现）

```go
type Provider interface {
    // Chat 非流式调用
    Chat(ctx context.Context, req *ChatRequest) (*ChatResponse, error)
    // ChatStream 流式调用，返回 chunk channel
    ChatStream(ctx context.Context, req *ChatRequest) (<-chan StreamChunk, error)
    // CountTokens 预估 token 消耗
    CountTokens(text string) int
    // Name 返回 provider 名称，用于日志和指标
    Name() string
}
```

所有 LLM Provider（OpenAI、Claude、通义千问、DeepSeek 等）必须实现此接口，方便切换和降级。

## 超时控制

```go
// 非流式调用：30-60s
ctx, cancel := context.WithTimeout(ctx, 45*time.Second)
defer cancel()

// 流式调用：首 chunk 超时 15s，总超时根据 max_tokens 动态计算
// 估算公式：baseTimeout + max_tokens / tokensPerSecond
totalTimeout := 15*time.Second + time.Duration(req.MaxTokens/30)*time.Second
```

使用 `context.WithTimeout`，不要仅依赖 `http.Client.Timeout`。

## 重试与降级

| 错误 | 策略 |
|------|------|
| 429（限流） | 指数退避重试，最多 3 次，初始间隔 1s |
| 500/502/503 | 立即重试 1 次，失败后降级到备用 Provider |
| 400（参数错误） | 不重试，直接返回 |
| 401/403（认证） | 不重试，直接返回 |
| 超时 | 重试 1 次，失败后降级 |

```go
func (c *Client) ChatWithRetry(ctx context.Context, req *ChatRequest) (*ChatResponse, error) {
    providers := []Provider{c.primary, c.fallback}
    
    for _, p := range providers {
        resp, err := c.doWithRetry(ctx, p, req)
        if err == nil {
            return resp, nil
        }
        c.logger.Warn("provider failed, trying fallback",
            zap.String("provider", p.Name()),
            zap.Error(err),
        )
    }
    return nil, ErrLLMUnavailable
}
```

## 流式响应（SSE）

```go
func (c *Client) ChatStream(ctx context.Context, req *ChatRequest) (<-chan StreamChunk, error) {
    ch := make(chan StreamChunk, 16) // 带缓冲，避免阻塞生产者
    
    go func() {
        defer close(ch)
        
        resp, err := c.httpClient.Do(httpReq)
        if err != nil {
            ch <- StreamChunk{Err: fmt.Errorf("http request: %w", err)}
            return
        }
        defer resp.Body.Close()
        
        scanner := bufio.NewScanner(resp.Body)
        for scanner.Scan() {
            select {
            case <-ctx.Done():
                ch <- StreamChunk{Err: ctx.Err()}
                return
            default:
            }
            
            line := scanner.Text()
            if line == "data: [DONE]" {
                return
            }
            if !strings.HasPrefix(line, "data: ") {
                continue
            }
            
            var chunk StreamChunk
            if err := json.Unmarshal([]byte(line[6:]), &chunk); err != nil {
                ch <- StreamChunk{Err: fmt.Errorf("unmarshal chunk: %w", err)}
                return
            }
            ch <- chunk
        }
    }()
    
    return ch, nil
}
```

## Gin Handler 中转发 SSE

```go
func (h *ChatHandler) StreamChat(c *gin.Context) {
    var req dto.ChatReq
    if err := c.ShouldBindJSON(&req); err != nil {
        response.Error(c, http.StatusBadRequest, 2001, err.Error())
        return
    }

    c.Header("Content-Type", "text/event-stream")
    c.Header("Cache-Control", "no-cache")
    c.Header("Connection", "keep-alive")

    chunks, err := h.llmSvc.ChatStream(c.Request.Context(), &req)
    if err != nil {
        response.Error(c, http.StatusInternalServerError, 4001, err.Error())
        return
    }

    c.Stream(func(w io.Writer) bool {
        chunk, ok := <-chunks
        if !ok {
            return false
        }
        if chunk.Err != nil {
            c.SSEvent("error", chunk.Err.Error())
            return false
        }
        c.SSEvent("message", chunk.Content)
        return true
    })
}
```

## Token 管控

- 请求前预估 token 消耗，拒绝超限请求
- 记录每次调用的 prompt_tokens + completion_tokens
- 支持按用户/租户维度的 token 限额
- 超限时返回明确的错误码（如 4003 token_limit_exceeded）

## 敏感信息

- API Key 从环境变量或密钥管理服务获取
- 日志中禁止打印完整 prompt（可打印前 100 字符 + SHA256 hash）
- 用户输入发给 LLM 前做基本 sanitize（去除注入指令的尝试）
- 响应中的敏感信息（如 function_call 参数）按需脱敏

## Prompt 管理

- Prompt 模板放在 `internal/llm/prompts/` 或使用 `embed` 嵌入
- 使用 `text/template` 或结构化拼接
- 支持版本管理和 A/B 测试
- System prompt 和 User prompt 分离

## 错误类型

```go
var (
    ErrLLMTimeout       = errors.New("llm: request timeout")
    ErrLLMRateLimit     = errors.New("llm: rate limit exceeded")
    ErrLLMTokenLimit    = errors.New("llm: token limit exceeded")
    ErrLLMUnavailable   = errors.New("llm: service unavailable")
    ErrLLMInvalidResp   = errors.New("llm: invalid response format")
)
```

## 可观测性

每次 LLM 调用必须记录：

```go
logger.Info("llm call completed",
    zap.String("provider", provider.Name()),
    zap.String("model", req.Model),
    zap.Duration("latency", latency),
    zap.Int("prompt_tokens", resp.Usage.PromptTokens),
    zap.Int("completion_tokens", resp.Usage.CompletionTokens),
    zap.Int("status", resp.StatusCode),
)
```

Prometheus 指标：
- `llm_request_duration_seconds{provider, model, status}`
- `llm_tokens_total{provider, model, type=prompt|completion}`
- `llm_request_total{provider, model, status}`
- 流式调用额外记录：`llm_first_chunk_latency_seconds`
