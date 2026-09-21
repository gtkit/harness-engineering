# 扩展包（第三方库）设计规范 Guide

## 设计原则

1. **零外部依赖优先**：能用标准库实现的不引入第三方
2. **条件化依赖选型**：第三方包按“标准库 → gtkit 原生包 → 业界事实标准 → 其他第三方”选择；gtkit 同名包若仅是事实标准库轻封装，可直连事实标准库
3. **JSON 固定例外**：JSON 必须使用 `github.com/gtkit/json` 或 `github.com/gtkit/json/v2`，禁止 `encoding/json`
4. **接口驱动**：暴露接口，隐藏实现
5. **Options 模式配置**：使用 Functional Options
6. **文档即 API**：每个导出函数/类型都有 GoDoc 注释
7. **向后兼容**：遵循语义化版本，大版本变更需要充分理由

## 包结构

```
github.com/gtkit/pkgname/
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

> 日志一律 `github.com/gtkit/logger`（major 以项目 go.mod 已引用的为准，未引用时用最新 major，当前 `/v2`），库内直接调包级函数，不提供 `WithLogger` 注入；`log` / `log/slog` 包括当接口层的变通写法都不用。

```go
type Option func(*config)

type config struct {
    timeout  time.Duration
    retries  int
}

func defaultConfig() *config {
    return &config{
        timeout: 10 * time.Second,
        retries: 3,
    }
}

func WithTimeout(d time.Duration) Option {
    return func(c *config) { c.timeout = d }
}

func WithRetries(n int) Option {
    return func(c *config) { c.retries = n }
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

## 导出结构体的带键初始化守卫

首位加一个未导出空字段，编译器会拒绝跨包的位置初始化，调用方必须写字段名，字段顺序因此不再进入兼容契约：

```go
type Config struct {
    _    struct{} // 守卫：强制跨包调用方带键初始化
    Host string
    Port int
}
```

外部包写 `pkg.Config{"127.0.0.1", 8080}` 直接编译失败（Go 1.27.1 实测）：`too few values in struct literal of type pkg.Config (type has unexported fields - use key:value pairs)`。

满足其一就加：

- 结构体有 2 个及以上相同类型的字段（`Width`/`Height`、`From`/`To`）：调整顺序后旧的位置初始化仍然编译通过，值被静默对调。
- Config、Options、跨服务 DTO 这类预期会持续新增字段的结构体。

这些情况不加：`internal/` 下的类型（同模块内部本来就允许位置初始化，拦不住）；`Point{1, 2}` 这类靠简洁字面量表达的小值类型；调用方需要与同构 struct 互转的类型（未导出字段会让跨包 struct 转换一并失败）。

实施约束：

- `_ struct{}` 必须是第一个字段。放末位时尾部零大小字段会被补齐到对齐边界，实测 `unsafe.Sizeof` 由 24 涨到 32；放首位与不加守卫时相同。
- 必须带注释说明用途，否则后续 review 会当成无用字段删掉。
- 守卫不改变 JSON 序列化行为，也不影响结构体的可比较性。
- 给已发布的导出结构体补加守卫，会让使用位置初始化的调用方编译中断，属于破坏性变更，跟着升大版本。

## context 支持

- 所有可能耗时的操作都接受 `context.Context` 作为第一个参数
- 尊重 context 的 cancel 和 deadline
- 不要在内部创建新的 context（如 `context.Background()`），用调用方传入的

## 并发安全

- 文档明确标注是否 goroutine-safe
- 如果是线程安全的，内部用 sync.Mutex 或 sync.RWMutex 保护
- 如果不是线程安全的，在 GoDoc 中明确说明
