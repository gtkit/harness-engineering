# Go 测试与验证 Guide

本 guide 约束 Go 后端业务服务的测试、验证和回归闭环。它补充入口文件中的提交前检查，适用于 handler、service、repository、middleware、外部依赖适配和迁移相关改动。

## 验证入口

优先使用项目已有统一入口（如 `make test`、`make lint`、`task test`、CI 脚本）。如果项目没有统一入口，至少执行：

```bash
golangci-lint run ./...
go vet ./...
go test -race -count=1 -timeout=5m ./...
```

按改动类型追加：

```bash
# 覆盖率
go test -coverprofile=coverage.out ./...

# 只定位某个回归时可先聚焦，最终仍要跑相关全量
go test -run TestName -count=1 ./internal/...

# 涉及性能敏感路径
go test -bench=. -benchmem -count=3 ./...
```

## 测试分层

- **Unit**：纯业务规则、值对象、工具函数、service 分支逻辑；不依赖真实 DB / Redis / HTTP。
- **Handler**：使用 `httptest` 覆盖参数绑定、鉴权上下文、错误映射、响应结构；不要起真实端口。
- **Repository / Integration**：覆盖 GORM 查询、事务、锁、迁移兼容；优先使用测试容器或项目既有测试数据库策略，不把本地个人库写死进测试。
- **Contract**：公开 API 响应结构、错误码、分页 meta、DTO json tag 变更时必须有契约测试或快照式断言。
- **Regression**：修 bug 先补能失败的复现用例，再修到通过。

## Table-Driven 标准

所有可枚举输入输出的测试使用 table-driven 风格：

```go
func TestValidateCreateUser(t *testing.T) {
    tests := []struct {
        name    string
        input   CreateUserReq
        wantErr error
    }{
        {name: "missing email", input: CreateUserReq{Name: "A"}, wantErr: ErrEmailRequired},
        {name: "ok", input: CreateUserReq{Name: "A", Email: "a@example.com"}},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := ValidateCreateUser(tt.input)
            if tt.wantErr != nil && !errors.Is(err, tt.wantErr) {
                t.Fatalf("want %v, got %v", tt.wantErr, err)
            }
            if tt.wantErr == nil && err != nil {
                t.Fatalf("unexpected error: %v", err)
            }
        })
    }
}
```

- case 名必须说明业务场景，不用 `case1` / `invalid` 这类空名。
- 断言要具体：优先 `errors.Is` / `errors.As` / 字段级比较，避免只断言“有错误”。
- 覆盖 success、error、edge 三类；只测 happy path 视为不足。

## Mock 与外部依赖

- mock 通过接口注入，不 monkey patch，不改全局变量。
- service 测试 mock repository / provider；repository 测试使用真实 DB 或项目既有集成测试基线。
- HTTP 外部依赖用 `httptest.Server` 或可注入 client；禁止请求真实第三方服务。
- 时间、随机数、ID 生成器需可注入，避免测试依赖当前时间或不稳定随机值。

## 并发与 Race

- 任何声明并发安全的类型必须有并发测试，并在 `-race` 下通过。
- goroutine 必须能通过 `context` 或 channel 退出；测试要验证取消路径。
- 涉及锁、幂等、状态流转、余额、库存、支付回调时，必须覆盖并发重复请求或重复回调。
- 不为了让 race 测试通过而删掉真实共享状态；要修正同步边界。

## 数据库与迁移验证

- 跨表写入必须有事务测试，覆盖中途失败时回滚。
- `gorm.ErrRecordNotFound`、唯一键冲突、锁等待/死锁重试路径要按业务风险覆盖。
- 生产迁移脚本必须可前向部署；涉及 schema / 默认值 / 回填时，测试或说明部署顺序。
- 列表接口测试必须覆盖默认分页、最大 page size、空结果和非法分页参数。

## API 与错误契约

- Handler 测试必须断言 HTTP 状态码、业务 `code`、`message` 安全文案、`data` / `meta` 结构。
- 未知错误必须映射为统一 500 响应，不暴露内部错误字符串。
- 鉴权和限流中间件至少覆盖未登录、权限不足、命中限流和正常通过。
- DTO / 响应结构变更时同步更新文档、前端类型或调用方测试。

## 回归要求

- 修复 bug 时先写失败测试或最小复现脚本；没有复现就说明阻塞原因。
- 每次修复后重跑受影响包的全量测试，再跑项目级必需检查。
- 测试失败不能只改断言凑绿；必须说明行为为何应该变化。
- 交付时说明实际跑过的命令；没跑的命令必须说明缺失工具、环境或成本原因。
