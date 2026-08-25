# Go 1.27 现代语法 Guide

> 硬性基线：`go.mod` 声明 `go 1.27.0`；提交前 `go fix -diff ./...` 必须无输出。
> 本文的 API 签名、编译器报错与编解码输出都在 go1.27.0 上实测过；完整示例（泛型方法、Valuer/Scanner、JSON tag）整包 `go run` / `go vet` / `go fix -diff` 通过，带 `...` 的片段是示意。

## 门禁

```bash
go fix -diff ./...     # 有输出即不合规：先 go fix ./... 应用改写，复核后再提交
go vet ./...
go test -race -count=1 ./...
```

`go fix` 的改写器清单用 `go tool fix help` 查（go1.27.0 实测注册 26 个 analyzer，含 `errorsastype`、`waitgroupgo`、`rangeint`、`stringsseq`、`omitzero`、`newexpr`、`stditerators`），把下面这些写法从"建议"变成"可执行检查"。

## 泛型方法（Go 1.27 新增）

方法可以自带类型参数，容器不必再为每种取出类型写一个包级函数。完整写法、两条编译器强制约束（接口方法不能带类型参数、方法值必须先实例化）与选型标准见 `pkg-generics.md` 的「泛型方法（Go 1.27）」一节，本文不重复。

库作者额外注意：**泛型方法会进入导出面**。给已发布的类型新增泛型方法是 MINOR；改动它的类型参数个数、约束或返回类型是破坏性变更，按 `pkg-api-compat.md` 处理。

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
2. **要能直接入库必须自己包一层**。`uuid.UUID` 未实现 `driver.Valuer`，`*uuid.UUID` 未实现 `sql.Scanner`（实测确认）。库对外暴露的标识类型如果承诺“可直接作为列类型使用”，就必须自己实现这两个接口，并且**成对出现**——只实现一半会在读或写的一侧静默退化成默认编码：

   ```go
   type ID uuid.UUID

   func (u ID) Value() (driver.Value, error) { return uuid.UUID(u).String(), nil }

   func (u *ID) Scan(src any) error {
       s, ok := src.(string)
       if !ok {
           b, ok := src.([]byte)
           if !ok {
               return fmt.Errorf("scan id: unsupported type %T", src)
           }
           s = string(b)
       }
       parsed, err := uuid.Parse(s)
       if err != nil {
           return fmt.Errorf("scan id %q: %w", s, err)
       }
       *u = ID(parsed)
       return nil
   }

   var (
       _ driver.Valuer = ID{}
       _ sql.Scanner   = (*ID)(nil)
   )
   ```

   上面这两个 `var _ =` 断言是“可直接入库”这句承诺的最小反证形态：接口实现被改坏时编译即失败。承诺写进 README 之前，还要按 `pkg-testing.md` 补一个真正跑 `Value` / `Scan` 往返的用例，并覆盖非法输入：实测 `Scan(nil)`（NULL 列）报 `scan id: unsupported type <nil>`，`Scan([]byte(nil))` 报 `scan id "": invalid uuid`。这版对 NULL 是 fail-closed 的；库要支持可空列，就必须先显式处理 `src == nil`（置零值并 `return nil`，或改用 `sql.Null[T]`），并把该行为写进 GoDoc。

   不做这层封装时，调用方按 `.String()`（`CHAR(36)`）或 `u[:]`（`BINARY(16)`）自行转换，这一点要在 GoDoc 里写清楚。

3. **JSON 里零值不会被 `omitempty` 省掉**。`uuid.UUID` 实现了 `MarshalText` / `UnmarshalText`，走 `encoding.TextMarshaler` 的编码器输出标准小写短横线字符串；但它是数组类型，`omitempty` 对数组无效，零值会原样输出 `"00000000-0000-0000-0000-000000000000"`。可选字段用 `omitzero`：

   ```go
   type Row struct {
       ID     uuid.UUID `json:"id,omitzero"`      // 零值时该字段整个消失
       Parent uuid.UUID `json:"parent,omitempty"` // 零值时仍输出全 0 串
   }
   ```

   `omitzero` 与 `omitempty` 的这组差异在 `encoding/json` 和 `github.com/gtkit/json` v1.0.0 上实测输出逐字节一致，两个编码器都可以照此写 tag。

   **这条门禁抓不到，只能靠审查**：`go fix` 的 `omitzero` modernizer 会标记结构体、`time.Time` 等字段上无效的 `omitempty`，但实测不标记数组类型——`uuid.UUID` 上写错的 `omitempty` 能干净通过 `go fix -diff ./...`。所以 UUID 字段的 tag 要逐个人工核对。

## 错误：`errors.AsType`

```go
// 签名：func AsType[E error](err error) (E, bool)
if e, ok := errors.AsType[*PaymentError](err); ok {
    return e.Code
}
```

替代 `var e *PaymentError; errors.As(err, &e)` 的两步写法，少一个中间变量，类型写在调用处。包装仍用 `fmt.Errorf("...: %w", err)`，哨兵判断仍用 `errors.Is`。

## 并发：`sync.WaitGroup.Go`

```go
var wg sync.WaitGroup
for _, item := range items {
    wg.Go(func() {           // Add(1) / go / defer Done() 三步收成一步
        process(ctx, item)
    })
}
wg.Wait()
```

`wg.Go` 只是省掉计数样板，不改变逻辑约束：闭包里的错误必须自己收集（用 `errgroup` 或带锁的切片），goroutine 仍要监听 `ctx`。

## `new(expr)`

```go
p := new(computeLimit())   // 直接对表达式取地址，替代 tmp := ...; p := &tmp
```

## range over int / 迭代器

```go
for i := range 3 { ... }                       // 替代 for i := 0; i < 3; i++

for line := range strings.Lines(text) { ... }  // strings.SplitSeq / FieldsSeq / SplitAfterSeq 同理

for k, v := range maps.All(m) { ... }
```

自定义迭代器返回 `iter.Seq[T]` / `iter.Seq2[K, V]`，调用方直接 `range`。

## slices / maps / cmp 优先于手写循环

```go
slices.Contains(s, v)
slices.SortFunc(items, func(a, b Item) int { return cmp.Compare(a.Name, b.Name) })
slices.Collect(maps.Keys(m))      // maps.Keys 返回 iter.Seq，不是切片
slices.Sorted(maps.Keys(m))       // 需要有序键直接用 Sorted
maps.DeleteFunc(m, func(k string, v int) bool { return v == 0 })
```

## 自检

- [ ] `go.mod` 是 `go 1.27.0`，`go fix -diff ./...` 无输出
- [ ] 容器上按调用方类型变化的读取 / 转换写成泛型方法（细则见 `pkg-generics.md`）
- [ ] 新增 / 改动的泛型方法按 `pkg-api-compat.md` 评估过 SemVer 影响
- [ ] 新建 ID 用 `uuid` 包：主键 `uuid.NewV7()`，通用随机标识 `uuid.New()`
- [ ] 对外承诺“可直接入库”的标识类型，`Value()` 与 `Scan()` 成对实现且有往返测试
- [ ] 可选 UUID 字段的 JSON tag 用 `omitzero` 而不是 `omitempty`
- [ ] 类型断言错误用 `errors.AsType[T]`，包装用 `%w`，哨兵用 `errors.Is`
- [ ] 起 goroutine 用 `wg.Go`，且闭包内监听 ctx、错误有收集
- [ ] 定长循环用 `for i := range n`，集合操作走 `slices` / `maps` / `cmp`
