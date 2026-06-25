# 错误体系设计 Guide

## 三层错误体系

库的错误设计分三层，调用方按需使用：

### 第一层：Sentinel Error（判断错误类别）

```go
// errors.go
var (
    ErrNotFound    = errors.New("pkgname: not found")
    ErrTimeout     = errors.New("pkgname: timeout")
    ErrInvalidArg  = errors.New("pkgname: invalid argument")
    ErrUnavailable = errors.New("pkgname: service unavailable")
)
```

调用方用 `errors.Is(err, pkgname.ErrTimeout)` 判断。

### 第二层：自定义错误类型（获取错误详情）

```go
type ValidationError struct {
    Field   string
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("pkgname: validation failed on %s: %s", e.Field, e.Message)
}

type RateLimitError struct {
    RetryAfter time.Duration
    cause      error // 可选：包内层根因
}

func (e *RateLimitError) Error() string {
    return fmt.Sprintf("pkgname: rate limited, retry after %s", e.RetryAfter)
}

// 自定义错误类型若包了内层错误，必须实现 Unwrap，让 errors.Is/As 能穿透。
func (e *RateLimitError) Unwrap() error { return e.cause }

// 想让自定义类型同时被某个 sentinel 命中，实现 Is：
func (e *RateLimitError) Is(target error) bool { return target == ErrRateLimited }
```

- 调用方用 `errors.As(err, &valErr)` 获取详情字段。
- 自定义错误类型一旦包内层错误（`cause`），**必须实现 `Unwrap() error`**，否则 `errors.Is`/`errors.As` 无法穿透到根因。
- 需要自定义类型关联到 sentinel 时，实现 `Is(target error) bool`。

### 第三层：Error Wrapping（保留调用链）

```go
func (c *Client) Do(ctx context.Context, req *Request) (*Response, error) {
    resp, err := c.httpClient.Do(httpReq)
    if err != nil {
        return nil, fmt.Errorf("pkgname: do request: %w", err)
    }
    // ...
}
```

## 规则

1. **错误消息以包名开头**：`"pkgname: xxx"` 方便调用方定位来源
2. **sentinel error 用 `errors.New`**：不要用 `fmt.Errorf`
3. **wrapping 用 `%w`**：让调用方能 `errors.Is` / `errors.As` 穿透
4. **不暴露内部依赖的错误类型**：wrap 后返回自己的错误
5. **禁止隐式 panic**：普通 API 绝不 panic，所有异常走 error 返回；`MustXxx` 只在 Go 生态惯例明确或用户明确要求时允许
6. **error 是接口**：自定义错误类型必须实现 `error` 接口

## 不要做的事

```go
// ✗ 普通 API 不要 panic
func Parse(s string) (*Config, error) {
    cfg, err := parseConfig(s)
    if err != nil {
        panic(err) // 普通解析 API 不应该 panic
    }
    return cfg, nil
}

// ✓ 如果确实需要 Must 变体，函数名必须以 Must 开头，并在 GoDoc 里明确说明会 panic
// MustParse is like Parse but panics on error.
// It is intended for use in variable initialization.
func MustParse(s string) *Config { ... }
```

```go
// ✗ 不要裸返回字符串
return errors.New("failed")

// ✓ 带上下文
return fmt.Errorf("pkgname: parse config %q: %w", filename, err)
```
