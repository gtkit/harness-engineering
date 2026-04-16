# 测试与 Benchmark Guide

## 测试分层

| 类型 | 文件命名 | 最低要求 |
|-----|---------|---------|
| 单元测试 | `xxx_test.go` | 覆盖率 ≥ 80%，每个导出函数都有测试 |
| Example 测试 | `example_test.go` | 每个核心 API 至少一个 Example |
| Benchmark | `benchmark_test.go` | 性能关键路径必须有 |
| Fuzz 测试 | `fuzz_test.go` | 解析类/编解码类函数推荐加 |

## 单元测试（table-driven）

```go
func TestEncode(t *testing.T) {
    tests := []struct {
        name    string
        input   any
        opts    []Option
        want    []byte
        wantErr error
    }{
        {
            name:  "string value",
            input: "hello",
            want:  []byte(`"hello"`),
        },
        {
            name:  "nil input",
            input: nil,
            want:  []byte("null"),
        },
        {
            name:    "unsupported type",
            input:   make(chan int),
            wantErr: ErrInvalidArg,
        },
        {
            name:  "with custom option",
            input: "hello",
            opts:  []Option{WithIndent(true)},
            want:  []byte("\"hello\""),
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            enc := New(tt.opts...)
            got, err := enc.Encode(context.Background(), tt.input)

            if tt.wantErr != nil {
                if !errors.Is(err, tt.wantErr) {
                    t.Errorf("want error %v, got %v", tt.wantErr, err)
                }
                return
            }
            if err != nil {
                t.Fatalf("unexpected error: %v", err)
            }
            if !bytes.Equal(got, tt.want) {
                t.Errorf("want %s, got %s", tt.want, got)
            }
        })
    }
}
```

**规则：**
- 每个 test case 必须有 `name`
- 必须覆盖三类：success / error / edge case
- 用标准库 `testing`，不强制要求 testify（库尽量少依赖）
- 需要用 testify 时只用 `assert` 和 `require`，不用 `suite`

## Example 测试

```go
// example_test.go
package pkgname_test // 注意：外部测试包

import (
    "context"
    "fmt"
    "time"

    "github.com/yourorg/pkgname"
)

func ExampleNew() {
    client := pkgname.New(
        pkgname.WithTimeout(5 * time.Second),
    )
    fmt.Println(client != nil)
    // Output: true
}

func ExampleClient_Encode() {
    client := pkgname.New()
    result, err := client.Encode(context.Background(), "hello")
    if err != nil {
        fmt.Println("error:", err)
        return
    }
    fmt.Println(string(result))
    // Output: "hello"
}
```

**规则：**
- 放在 `example_test.go`，用外部测试包（`package pkgname_test`）
- 每个核心 API 至少一个 Example
- 必须有 `// Output:` 注释（可验证的 Example）
- 体现最常见的用法，不要写复杂场景

## Benchmark

```go
// benchmark_test.go
func BenchmarkEncode(b *testing.B) {
    client := New()
    input := map[string]any{"name": "test", "count": 42}
    ctx := context.Background()

    b.ResetTimer()
    b.ReportAllocs()
    for b.Loop() {
        _, err := client.Encode(ctx, input)
        if err != nil {
            b.Fatal(err)
        }
    }
}

func BenchmarkEncode_Parallel(b *testing.B) {
    client := New()
    input := "hello"
    ctx := context.Background()

    b.RunParallel(func(pb *testing.PB) {
        for pb.Next() {
            _, _ = client.Encode(ctx, input)
        }
    })
}
```

**规则：**
- 用 `b.Loop()`（Go 1.24+）替代 `for i := 0; i < b.N; i++`
- 必须 `b.ReportAllocs()`
- 性能关键路径加并行 Benchmark
- 不同输入规模分多个 Benchmark（Small / Medium / Large）

## Fuzz 测试（推荐）

```go
func FuzzDecode(f *testing.F) {
    f.Add([]byte(`{"key": "value"}`))
    f.Add([]byte(`null`))
    f.Add([]byte(``))

    f.Fuzz(func(t *testing.T, data []byte) {
        result, err := Decode(data)
        if err != nil {
            return // 解析失败是正常的
        }
        // 确保 encode 后再 decode 结果一致（round-trip）
        encoded, err := Encode(result)
        if err != nil {
            t.Fatalf("encode failed after successful decode: %v", err)
        }
        result2, err := Decode(encoded)
        if err != nil {
            t.Fatalf("decode failed on re-encoded data: %v", err)
        }
        if !reflect.DeepEqual(result, result2) {
            t.Fatalf("round-trip mismatch")
        }
    })
}
```

## 运行命令

```bash
# 单元测试 + race
go test -race -count=1 -timeout=5m ./...

# 覆盖率
go test -coverprofile=coverage.out ./...
go tool cover -func=coverage.out

# Benchmark
go test -bench=. -benchmem -count=3 ./...

# Fuzz（运行 30 秒）
go test -fuzz=FuzzDecode -fuzztime=30s ./...
```
