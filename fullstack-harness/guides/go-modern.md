# Go 1.27 现代语法 Guide

> 硬性基线：`backend/go.mod` 声明 `go 1.27.0`；提交前在 `backend/` 下 `go fix -diff ./...` 必须无输出。
> 本文只约束后端 Go 代码；前端规范见 `frontend-coding.md`。
> 本文的 API 签名、编译器报错与编解码输出都在 go1.27.0 上实测过；完整示例（泛型方法、Valuer/Scanner、JSON tag）整包 `go run` / `go vet` / `go fix -diff` 通过，带 `...` 的片段是示意。

> 通用的现代 Go 写法（泛型方法、`errors.AsType`、`sync.WaitGroup.Go`、`new(expr)`、range-over-int / 迭代器、`slices` / `maps` / `cmp`、`omitzero`、`json/v2`、`synctest`）以 skill `use-modern-go` 为准，按项目 `go.mod` 版本只读它 `references/` 里对应的一段；本文只保留门禁命令、本项目的 UUID 落库约束与自检项。

## 门禁

```bash
go fix -diff ./...     # 有输出即不合规：先 go fix ./... 应用改写，复核后再提交
go vet ./...
go test -race -count=1 ./...
```

`go fix` 的改写器清单用 `go tool fix help` 查（go1.27.0 实测注册 26 个 analyzer，含 `errorsastype`、`waitgroupgo`、`rangeint`、`stringsseq`、`omitzero`、`newexpr`、`stditerators`），把下面这些写法从"建议"变成"可执行检查"。

## UUID：标准库 `uuid` 包

```go
import "uuid"
```

`uuid.UUID` 是 `[16]byte`，可直接用 `==` 比较，零值等于 `uuid.Nil()`。

| 需求 | 写法 |
|-----|-----|
| 通用场景 | `uuid.New()`（等价 `uuid.NewV4()`，122 位随机） |
| 数据库主键 | `uuid.NewV7()`（高 48 位是时间戳，除系统时钟回拨外单调递增，B+ 树插入友好） |
| 明确要 v4 | `uuid.NewV4()` |
| 解析 | `uuid.Parse(s) (UUID, error)`；确定合法时 `uuid.MustParse(s)`（非法直接 panic） |
| 空值 / 最大值 | `uuid.Nil()`、`uuid.Max()` |
| 排序 | `u.Compare(v) int`（RFC 9562 大端序） |
| 字符串 | `u.String()`，小写带短横线 |

`uuid.Parse` 接受四种形式：`f81d4fae-7dec-11d0-a765-00a0c91e6bf6`、带花括号、`urn:uuid:` 前缀、以及无短横线的 32 位十六进制。

### 三个必须记住的行为

1. **`uuid.Nil()` 是函数，不是变量**（与 `github.com/google/uuid` 的 `uuid.Nil` 变量不同）。漏掉括号写 `u == uuid.Nil` 报 `invalid operation: u == uuid.Nil (mismatched types uuid.UUID and func() uuid.UUID)`；判空写 `u == uuid.Nil()`，或直接 `u == uuid.UUID{}`（两者等价，实测一致）。
2. **入库必须显式转换**。`uuid.UUID` 未实现 `driver.Valuer`，`*uuid.UUID` 未实现 `sql.Scanner`（实测确认），不能直接作为列类型交给 GORM / `database/sql`：

   ```go
   // ✓ CHAR(36)：写入 .String()，读出 uuid.Parse
   type Order struct {
       ID        string `gorm:"type:char(36);primaryKey"`
       CreatedAt time.Time
   }
   o := &Order{ID: uuid.NewV7().String()}

   // ✓ BINARY(16)：写入 u[:]，读出用 [16]byte 复制回来
   type Event struct {
       ID []byte `gorm:"type:binary(16);primaryKey"`
   }
   u := uuid.NewV7()
   e := &Event{ID: u[:]}

   // ✓ 需要在模型里直接放 uuid.UUID 时，自己包一层实现 Valuer / Scanner
   type DBUUID uuid.UUID

   func (u DBUUID) Value() (driver.Value, error) { return uuid.UUID(u).String(), nil }

   func (u *DBUUID) Scan(src any) error {
       s, ok := src.(string)
       if !ok {
           b, ok := src.([]byte)
           if !ok {
               return fmt.Errorf("scan uuid: unsupported type %T", src)
           }
           s = string(b)
       }
       parsed, err := uuid.Parse(s)
       if err != nil {
           return fmt.Errorf("scan uuid %q: %w", s, err)
       }
       *u = DBUUID(parsed)
       return nil
   }
   ```

   包一层时同一个类型必须同时实现 `Value()`（值接收者）和 `Scan()`（指针接收者），只实现一半会在读或写的一侧静默退化成默认编码。

   上面这版对 NULL 是 fail-closed 的：列值为 NULL 时 `database/sql` 传进来的 `src` 是 `nil`，实测报 `scan id: unsupported type <nil>`；传 `[]byte(nil)` 则报 `scan id "": invalid uuid`。主键不该为 NULL，报错正合适；**列可为 NULL 时必须先显式处理 `src == nil`**（置零值并 `return nil`，或改用 `sql.Null[T]` 包一层），否则每读到一行 NULL 都会失败。

3. **JSON 里零值不会被 `omitempty` 省掉**。`uuid.UUID` 实现了 `MarshalText` / `UnmarshalText`，走 `encoding.TextMarshaler` 的编码器输出标准小写短横线字符串；但它是数组类型，`omitempty` 对数组无效，零值会原样输出 `"00000000-0000-0000-0000-000000000000"`。可选字段用 `omitzero`：

   ```go
   type Row struct {
       ID     uuid.UUID `json:"id,omitzero"`      // 零值时该字段整个消失
       Parent uuid.UUID `json:"parent,omitempty"` // 零值时仍输出全 0 串
   }
   ```

   `omitzero` 与 `omitempty` 的这组差异在 `encoding/json` 和 `github.com/gtkit/json` v1.0.0 上实测输出逐字节一致，两个编码器都可以照此写 tag。

   **这条门禁抓不到，只能靠审查**：`go fix` 的 `omitzero` modernizer 会标记结构体、`time.Time` 等字段上无效的 `omitempty`，但实测不标记数组类型——`uuid.UUID` 上写错的 `omitempty` 能干净通过 `go fix -diff ./...`。所以 UUID 字段的 tag 要逐个人工核对。

## 自检

- [ ] `go.mod` 是 `go 1.27.0`，`go fix -diff ./...` 无输出
- [ ] 容器上按调用方类型变化的读取 / 转换写成泛型方法，没有为每种类型复制一个包级函数
- [ ] 泛型方法没有出现在 interface 声明里，方法值都带了实例化参数
- [ ] 新建 ID 用 `uuid` 包：主键 `uuid.NewV7()`，通用随机标识 `uuid.New()`
- [ ] `uuid.UUID` 入库处有显式转换（`.String()` / `u[:]` / 自实现 Valuer+Scanner 成对出现）
- [ ] 可选 UUID 字段的 JSON tag 用 `omitzero` 而不是 `omitempty`
- [ ] 类型断言错误用 `errors.AsType[T]`，包装用 `%w`，哨兵用 `errors.Is`
- [ ] 起 goroutine 用 `wg.Go`，且闭包内监听 ctx、错误有收集
- [ ] 定长循环用 `for i := range n`，集合操作走 `slices` / `maps` / `cmp`
