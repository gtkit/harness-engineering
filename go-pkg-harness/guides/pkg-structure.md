# 包结构与设计 Guide

## 目录结构

```
github.com/yourorg/pkgname/
├── doc.go               # 包级文档（Package pkgname ...）
├── pkgname.go           # 核心类型 + 接口 + 构造函数
├── options.go           # Functional Options
├── errors.go            # 包级错误定义
├── xxx.go               # 按功能拆分的实现文件
├── xxx_test.go          # 对应测试
├── example_test.go      # Example 测试（GoDoc 展示）
├── benchmark_test.go    # 性能基准测试
├── internal/            # 内部实现（不对外暴露）
│   └── helper.go
├── go.mod
├── go.sum
├── README.md
├── CHANGELOG.md
├── LICENSE
└── .golangci.yml        # lint 配置
```

## 文件组织原则

- **一个文件一个职责**：不要把所有代码塞在一个文件里
- **核心类型放主文件**：`pkgname.go` 只放核心 type/interface/New 函数
- **实现按功能拆**：`encode.go`、`decode.go`、`validate.go`
- **内部细节用 `internal/`**：调用方不应该知道的实现放这里

## 接口设计

```go
// 暴露接口，隐藏实现
type Encoder interface {
    Encode(ctx context.Context, v any) ([]byte, error)
}

// 构造函数返回接口（可选，视情况也可以返回具体类型）
func NewJSONEncoder(opts ...Option) Encoder {
    cfg := defaultConfig()
    for _, opt := range opts {
        opt(cfg)
    }
    return &jsonEncoder{cfg: cfg}
}
```

**接口原则：**
- 接口应该小（1-3 个方法），大接口拆成小接口组合
- 接口定义在使用方，不在实现方（Go 惯例）
- 接口命名以 -er 结尾：`Reader`、`Encoder`、`Validator`
- 不要提前抽象——先写具体实现，发现需要多态时再抽接口

## Functional Options

```go
type Option func(*config)

type config struct {
    timeout     time.Duration
    retries     int
    maxSize     int
    logger      *slog.Logger
    concurrency int
}

func defaultConfig() *config {
    return &config{
        timeout:     10 * time.Second,
        retries:     3,
        maxSize:     1 << 20, // 1MB
        logger:      slog.Default(),
        concurrency: runtime.NumCPU(),
    }
}

func WithTimeout(d time.Duration) Option {
    return func(c *config) { c.timeout = d }
}

func WithRetries(n int) Option {
    return func(c *config) {
        if n >= 0 {
            c.retries = n
        }
    }
}

func WithLogger(l *slog.Logger) Option {
    return func(c *config) {
        if l != nil {
            c.logger = l
        }
    }
}
```

**规则：**
- 所有可选参数用 Option，必选参数放构造函数签名
- Option 函数内做防御性校验（nil 检查、负数检查）
- 必须有合理的默认值，使用者不传任何 Option 也能正常工作

## 命名规范

| 类型 | 规范 | 示例 |
|-----|------|------|
| 包名 | 短、小写、单词 | `signutil`、`httpkit`、`cache` |
| 导出类型 | 不重复包名 | `cache.Client`（不是 `cache.CacheClient`）|
| 构造函数 | `New` 或 `NewXxx` | `New()`、`NewWithConfig()` |
| Option | `With` 前缀 | `WithTimeout()`、`WithLogger()` |
| 接口 | -er 后缀 | `Signer`、`Validator` |
| 错误变量 | `Err` 前缀 | `ErrTimeout`、`ErrInvalidKey` |

## API 稳定性规则

- 导出的类型、函数、方法签名一旦发布（v1.0.0+），不随意修改
- 新增能力用新接口/方法，不改老的
- 废弃的用 `// Deprecated: use XXX instead.` 标记
- 破坏性变更 → 升大版本（v1 → v2，module path 加 `/v2`）

## context.Context

- 所有可能耗时的操作：第一个参数 `ctx context.Context`
- 尊重 ctx 的 cancel 和 deadline
- 内部不创建 `context.Background()`，用调用方传入的
- 纯计算型函数（无 IO、无网络）不需要 ctx

## 并发安全

- GoDoc 里明确标注：`// Client is safe for concurrent use.` 或 `// NOT safe for concurrent use.`
- 线程安全的类型内部用 `sync.Mutex` / `sync.RWMutex`
- 不需要线程安全的场景不要加锁（不过度设计）

## 依赖选择优先级

```
1. 标准库（能用标准库解决的绝不引入第三方）
   ↓ 标准库不够用
2. github.com/gtkit/* 仓库下的包（优先使用）
   ↓ gtkit 没有
3. 其他第三方（选最小依赖、最活跃维护的）
```

### JSON 强制规则

**禁止使用 `encoding/json`。** JSON 序列化/反序列化必须使用：

```go
import "github.com/gtkit/json"    // v1
import "github.com/gtkit/json/v2" // v2，按项目已有版本选择
```

如果项目 go.mod 已有 gtkit/json 的版本，遵循已有版本。新项目推荐 v2。

### gtkit 常用包参考

使用 gtkit 下的包时，如果不确定某个包是否存在或具体 API 签名，**必须先确认**，不要编造。确认方式：
- 让用户提供 `go doc` 输出
- 让用户确认包是否存在
- 绝不猜测 gtkit 下的函数名或参数
