# Go 测试与验证 Guide

## 验证入口

优先使用项目统一入口。没有统一入口时至少执行：

```bash
golangci-lint run ./...
go vet ./...
go test -race -count=1 -timeout=5m ./...
```

按改动类型追加：

```bash
go test -coverprofile=coverage.out ./...
go test -run TestName -count=1 ./internal/...
go test -bench=. -benchmem -count=3 ./...
```

## 测试分层

- Unit：application 业务规则、值对象、工具函数。
- Handler：httptest 覆盖绑定、鉴权上下文、错误映射、响应结构。
- Repository / Integration：GORM 查询、事务、锁、迁移兼容。
- Contract：公开 API 响应结构、错误码、分页结构、DTO json tag。
- Regression：修 bug 先补能失败的复现用例。

## Table-Driven 标准

可枚举输入输出的测试使用 table-driven：

```go
func TestValidateCreateUser(t *testing.T) {
    tests := []struct {
        name    string
        input   CreateUserInput
        wantErr error
    }{
        {name: "missing email", input: CreateUserInput{Name: "A"}, wantErr: ErrEmailRequired},
        {name: "ok", input: CreateUserInput{Name: "A", Email: "a@example.com"}},
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

case 名说明业务场景；断言具体；覆盖 success、error、edge。

## Mock 与外部依赖

- mock 通过接口注入，不 monkey patch。
- service 测试 mock repository / provider。
- repository 测试用真实 DB 或项目既有集成测试策略。
- HTTP 外部依赖用 `httptest.Server`。
- 时间、随机数、ID 生成器尽量可注入。

## 并发与 Race

- 声明并发安全的类型必须有并发测试。
- goroutine 能通过 context 或 channel 退出。
- 幂等、状态流转、支付回调覆盖并发重复请求。
- 涉及共享状态跑 `go test -race`。

## 数据库与迁移验证

- 跨表写入有事务测试，覆盖中途失败回滚。
- RecordNotFound、唯一键冲突、锁等待/死锁重试按风险覆盖。
- schema / 默认值 / 回填变更说明部署顺序。
- 列表接口覆盖默认分页、最大 page size、空结果和非法参数。

## API 与错误契约

- Handler 测试断言 HTTP 状态、业务 code、客户端文案、data/paging 结构。
- 未知错误统一内部错误，不暴露底层字符串。
- 鉴权和限流覆盖未登录、权限不足、命中限流、正常通过。
- DTO / 响应变更同步文档、前端类型或调用方测试。

## 回归要求

- 修 bug 先写失败测试或最小复现步骤。
- 修复后重跑受影响包全量测试，再跑项目必需检查。
- 测试失败不能只改断言凑绿。
- 交付说明实际跑过的命令；没跑说明原因。
