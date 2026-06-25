# API 兼容性 Guide

本 guide 约束 Go 扩展包的导出面、兼容性判断和 SemVer 影响。只要涉及导出符号、错误体系、Option、接口、泛型约束、行为语义或 major 版本规划，就必须读取本文件。

## 导出面清单

以下都属于公共契约，变更前必须评估兼容性：

- 导出的 type / func / method / const / var
- 导出 struct 字段、接口方法、泛型类型参数和约束
- sentinel error、自定义错误类型、`errors.Is` / `errors.As` 可观察行为
- 构造函数、Option、默认值、零值可用性
- context、并发安全、资源所有权、关闭语义
- GoDoc、Example 和 README 中承诺的行为

## 兼容性判断

### PATCH

适合 PATCH 的变更：

- 修复 bug，不改变已承诺的正确行为
- 内部重构，不改变导出 API 和可观察行为
- 文档修正、测试补充、性能优化
- 放宽输入限制，且不会让原有调用方行为变坏

### MINOR

适合 MINOR 的变更：

- 新增导出函数、方法、类型或 Option
- 新增可选 struct 字段，且零值保持原行为
- 新增 sentinel error 或自定义错误类型，且不移除旧错误判断能力
- 新增兼容能力，旧调用方无需修改即可继续工作

### MAJOR

以下属于破坏性变更，v1+ 必须升 MAJOR：

- 删除、重命名导出符号
- 修改导出函数、方法或接口签名
- 修改导出 struct 字段类型或删除字段
- 给导出接口新增方法
- 收紧泛型约束，导致原可用类型不再可用
- 改变错误类型、sentinel error 或 `errors.Is` / `errors.As` 判断结果
- 改变默认值、零值行为、并发安全承诺或资源关闭所有权
- 改变 GoDoc / README 已承诺的核心行为语义

`v0.x.y` 不做稳定兼容承诺，但破坏性变更至少升 MINOR，让下游能识别风险。

## 导出 API 设计纪律

- 新增导出 API 必须来自明确用户需求或稳定领域契约，不能为一次性内部实现开口子。
- 默认返回具体类型；只有接口本身是稳定契约，或需要隔离多实现/外部依赖时，才导出接口。
- 导出接口保持小而稳定；给接口新增方法是破坏性变更。
- Option 只表达调用方真正需要控制的行为，不暴露内部调优参数。
- 新增 Option 必须有 GoDoc、默认值说明和 Example 覆盖。
- 导出 struct 优先保持字段非导出；一旦导出字段，字段名、类型和含义都进入兼容契约。

## 错误兼容性

- 已公开的 sentinel error 不随意删除、重命名或替换。
- 如果新增自定义错误类型，旧的 `errors.Is` 判断能力必须保留，除非明确升 MAJOR。
- 自定义错误类型增加字段通常兼容；删除字段、改字段类型、改变 `Unwrap` / `Is` / `As` 行为属于破坏性变更。
- 不把内部依赖的错误类型作为公共契约暴露给调用方。

## 废弃流程

1. 先新增替代 API，并补 GoDoc、Example、README。
2. 给旧 API 加 `// Deprecated: use XXX instead.`。
3. CHANGELOG 的 `Deprecated` 区段记录迁移路径。
4. v1+ 至少保留一个 MINOR 周期；删除只能放在下一个 MAJOR。

## v2+ 发布要求

- `go.mod` 的 module path 必须带 `/v2`、`/v3` 后缀。
- README、Example、GoDoc 和迁移说明里的 import path 必须同步更新。
- CHANGELOG 和 tag message 必须写清破坏性变更与迁移路径。
- 只打 `v2.0.0` tag 但 module path 不变是错误发布。

## 提交前自检

```bash
git diff --name-only
go vet ./...
golangci-lint run ./...
go test -race -count=1 -timeout=5m ./...
go test -bench=. -benchmem -count=3 ./...
```

确认：

- 本次 diff 没有无意新增导出符号。
- 所有新增导出符号都有 GoDoc 和 Example 或测试覆盖。
- README / CHANGELOG 已同步记录调用方式或兼容性影响。
- SemVer 级别与变更性质匹配。
