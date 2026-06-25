# 包结构与设计 Guide

## 目录结构

```
github.com/gtkit/pkgname/
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

## 职责边界

- 导出 API 只表达稳定契约，不暴露临时实现细节
- 内部实现放在非导出类型、非导出函数或 `internal/` 中
- Option 只表达调用方真正需要控制的行为，不把内部调优参数外露
- 错误类型和错误变量保持最小集合，能支持调用方判断即可
- 测试 helper、fixture、benchmark 辅助逻辑只服务测试，不反向污染生产 API

## 抽象准入

只有满足以下任一条件才新增接口、Option、helper、internal 子包或导出类型：

- 已出现 2 处以上真实重复，且抽象后语义更清晰
- 某段逻辑复杂到需要隔离测试
- 需要隔离外部依赖、编码格式、存储实现或并发策略
- 新增导出 API 是用户明确要求，且符合 SemVer 与 GoDoc 要求

不满足准入条件时优先保持小而直接的实现；库代码尤其禁止为单次使用扩大导出面积。

## 接口设计

```go
// 默认返回具体类型，避免为“隐藏实现”提前扩大抽象面。
type Client struct {
    cfg config
}

func New(opts ...Option) (*Client, error) {
    cfg := defaultConfig()
    for _, opt := range opts {
        if err := opt(cfg); err != nil {
            return nil, err
        }
    }
    return &Client{cfg: *cfg}, nil
}

func (c *Client) Encode(ctx context.Context, v any) ([]byte, error) {
    // ...
}
```

**接口原则：**
- 接口应该小（1-3 个方法），大接口拆成小接口组合
- 接口定义在使用方，不在实现方（Go 惯例）
- 接口命名以 -er 结尾：`Reader`、`Encoder`、`Validator`
- 默认构造函数返回具体类型；只有接口本身就是稳定契约，或需要隔离外部依赖/多实现时，才导出小接口
- 不要提前抽象——先写具体实现，发现需要多态时再抽接口

## Functional Options

```go
type Option func(*config) error

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
    return func(c *config) error {
        if d <= 0 {
            return fmt.Errorf("pkgname: invalid timeout: %w", ErrInvalidArg)
        }
        c.timeout = d
        return nil
    }
}

func WithRetries(n int) Option {
    return func(c *config) error {
        if n < 0 {
            return fmt.Errorf("pkgname: invalid retries: %w", ErrInvalidArg)
        }
        c.retries = n
        return nil
    }
}

func WithLogger(l *slog.Logger) Option {
    return func(c *config) error {
        if l == nil {
            return fmt.Errorf("pkgname: nil logger: %w", ErrInvalidArg)
        }
        c.logger = l
        return nil
    }
}
```

**规则：**
- 所有可选参数用 Option，必选参数放构造函数签名
- Option 函数内做防御性校验（nil 检查、负数检查），非法值默认返回错误，不静默忽略
- 必须有合理的默认值，使用者不传任何 Option 也能正常工作
- 示例中的 `ErrInvalidArg` 代表本包在 `errors.go` 中定义的可判断错误；实际名称以项目真实错误体系为准
- 只有无害兼容场景才允许静默忽略非法 Option，且必须在 GoDoc 中写清楚
- 如果所有 Option 都不会失败，可以使用 `type Option func(*config)`，但一旦存在非法输入就改为 `type Option func(*config) error`，`New(...) (*Client, error)` 返回错误

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
- **废弃流程**：`// Deprecated: use XXX instead.` 标记 + 注释指向替代 API；至少保留一个 MINOR 周期；只能在下一个 MAJOR 删除
- **破坏性变更 → 升大版本**。v2+ 不只是改 import：`go.mod` 的 module path 必须带 `/v2`，并通过**仓库子目录 `v2/`** 或**独立 major 分支**提供该版本（Go Module 硬要求），否则下游 `go get` 取不到
- 破坏性变更必须在 README / CHANGELOG 写清迁移路径
- 详细兼容性判断见 `pkg-api-compat.md`

## 可观测性

- 导出 API 返回的错误要能帮助调用方定位失败阶段
- 可判断错误应提供 sentinel error 或自定义错误类型
- 错误包装不能丢失根因，也不能暴露无关内部依赖细节

## context.Context

- 所有可能耗时的操作：第一个参数 `ctx context.Context`
- 尊重 ctx 的 cancel 和 deadline
- 内部不创建 `context.Background()`，用调用方传入的
- **不要把 `context` 存进 struct 字段**，按调用逐次作首参传入
- 纯计算型函数（无 IO、无网络）不需要 ctx

## 并发安全

- GoDoc 里明确标注：`// Client is safe for concurrent use.` 或 `// NOT safe for concurrent use.`
- 线程安全的类型内部用 `sync.Mutex` / `sync.RWMutex`
- 不需要线程安全的场景不要加锁（不过度设计）

## 依赖选择优先级

```
1. 标准库（能用标准库解决的绝不引入第三方）
   ↓ 标准库不够用
2. github.com/gtkit/* 下的“原生”包（gtkit 自己设计的包，如 gtkit/logger、gtkit/json、gtkit/go-pay）
   ↓ gtkit 没有原生包或同名包仅是轻封装
3. 业界事实标准包（如 redis/go-redis、gorm/gorm、gin-gonic/gin，可直连）
   ↓ 没有事实标准或事实标准不适合
4. 其他第三方（选最小依赖、最活跃维护的）
```

如果 `github.com/gtkit/*` 下的同名包只是对业界事实标准库的轻封装，不强制优先使用 gtkit，可直接依赖事实标准库。

⚠ **`gtkit/go-pay` 不是轻封装**：v1.3.0 起通过 `paymgr` 包对外提供跨渠道统一抽象（`UnifiedOrder` / `QueryOrder` / `CloseOrder` / `Refund` / `ParseNotify` 等 8 个统一 API、`ChannelError` 结构化错误、`RefundStatus` 跨渠道状态映射），属"对上游有真正增量价值"的增强。**支付场景应优先使用 `gtkit/go-pay`**，不要直连 `go-pay/gopay`。

### JSON 选择规则

gtkit 生态包、已有项目已使用 gtkit/json、或用户明确要求 gtkit 兼容时，JSON 序列化/反序列化默认使用：

```go
import "github.com/gtkit/json"    // v1
import "github.com/gtkit/json/v2" // v2，按项目已有版本选择
```

如果项目 go.mod 已有 gtkit/json 的版本，遵循已有版本。新项目推荐 v2。

纯公共小库如果明确以零外部依赖为目标，且标准库能力足够，可以使用 `encoding/json`。使用例外时必须在 README、设计说明或 PR 描述中记录原因；不要为了 JSON 规则引入与包目标相冲突的依赖。

### gtkit 常用包参考

使用 gtkit 下的包时，如果不确定某个包是否存在或具体 API 签名，**必须先确认**，不要编造。确认方式：
- 优先在本机运行 `go doc` / `go list` / `go env GOPATH` 下模块缓存核验
- 查阅项目仓库、官方文档或已锁定的 `go.mod` / `go.sum`
- 本地和公开来源都无法确认时，再让用户确认包是否存在或提供 `go doc` 输出
- 绝不猜测 gtkit 下的函数名或参数
