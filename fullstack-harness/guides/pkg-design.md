# 扩展包（第三方库）设计规范 Guide

## 设计原则

1. **零外部依赖优先**：能用标准库实现的不引入第三方
2. **接口驱动**：暴露接口，隐藏实现
3. **Options 模式配置**：使用 Functional Options
4. **文档即 API**：每个导出函数/类型都有 GoDoc 注释
5. **向后兼容**：遵循语义化版本，大版本变更需要充分理由

## 包结构

```
github.com/yourorg/pkgname/
├── pkgname.go           # 核心类型和接口定义
├── options.go           # Functional Options
├── errors.go            # 包级错误定义
├── pkgname_test.go      # 测试
├── example_test.go      # 示例测试（出现在 GoDoc 中）
├── doc.go               # 包级文档
├── internal/            # 内部实现细节（不对外暴露）
├── README.md            # 用法说明
└── CHANGELOG.md         # 变更日志
```

## Functional Options 模板

```go
type Option func(*config)

type config struct {
    timeout  time.Duration
    retries  int
    logger   *slog.Logger
}

func defaultConfig() *config {
    return &config{
        timeout: 10 * time.Second,
        retries: 3,
        logger:  slog.Default(),
    }
}

func WithTimeout(d time.Duration) Option {
    return func(c *config) { c.timeout = d }
}

func WithRetries(n int) Option {
    return func(c *config) { c.retries = n }
}

func WithLogger(l *slog.Logger) Option {
    return func(c *config) { c.logger = l }
}

// New 创建实例，应用所有选项
func New(opts ...Option) *Client {
    cfg := defaultConfig()
    for _, opt := range opts {
        opt(cfg)
    }
    return &Client{cfg: cfg}
}
```

## 错误设计

```go
// 包级 sentinel error，调用方可以用 errors.Is 判断
var (
    ErrTimeout    = errors.New("pkgname: operation timeout")
    ErrInvalidArg = errors.New("pkgname: invalid argument")
)

// 需要携带上下文信息的错误用自定义类型
type ValidationError struct {
    Field   string
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("pkgname: validation failed on %s: %s", e.Field, e.Message)
}
```

## 必须包含

- **README.md**：安装方式、快速上手、完整示例、API 概览
- **GoDoc 注释**：每个导出的 type/func/const/var 都有注释
- **Example 测试**：至少包含核心功能的 Example（会出现在 GoDoc 中）
- **测试覆盖率 ≥ 80%**
- **CHANGELOG.md**：语义化版本（v1.2.3），每个版本列出 Added/Changed/Fixed
- **LICENSE**

## Example 测试写法

```go
func ExampleClient_Send() {
    client := pkgname.New(
        pkgname.WithTimeout(5 * time.Second),
    )
    
    result, err := client.Send(context.Background(), "hello")
    if err != nil {
        log.Fatal(err)
    }
    fmt.Println(result)
    // Output: world
}
```

## API 稳定性

- 导出的接口一旦发布，不随意修改签名
- 新增方法用新的接口（接口组合）
- 废弃的 API 用 `// Deprecated:` 注释标记
- 破坏性变更必须升大版本（v1 → v2）

## context 支持

- 所有可能耗时的操作都接受 `context.Context` 作为第一个参数
- 尊重 context 的 cancel 和 deadline
- 不要在内部创建新的 context（如 `context.Background()`），用调用方传入的

## 并发安全

- 文档明确标注是否 goroutine-safe
- 如果是线程安全的，内部用 sync.Mutex 或 sync.RWMutex 保护
- 如果不是线程安全的，在 GoDoc 中明确说明
