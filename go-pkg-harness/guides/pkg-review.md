# 包级代码审查清单

完成代码后逐条自审。不通过则修复。

---

## 1. API 设计

- [ ] 导出的 API 是否最小化？（不该导出的没导出）
- [ ] 命名是否清晰？（不重复包名、动词开头的函数、-er 后缀接口）
- [ ] 构造函数是否用 Functional Options？必选参数放签名，可选放 Option
- [ ] Option 函数内是否做了防御校验？（nil、负数、零值）
- [ ] 默认值是否合理？不传 Option 也能正常工作？

## 2. 错误处理

- [ ] 错误消息以包名开头？（`"pkgname: xxx"`）
- [ ] 可判断的错误用 sentinel error？（`var ErrXxx = errors.New(...)`）
- [ ] 需要详情的错误用自定义类型？（实现 `error` 接口）
- [ ] wrapping 用 `%w`？
- [ ] 绝无 panic？（`Must` 变体有 GoDoc 说明）
- [ ] 不暴露内部依赖的错误类型？

## 3. 文档

- [ ] 每个导出的 type/func/const/var 有 GoDoc 注释？
- [ ] 包级文档（doc.go）有用法概述？
- [ ] 核心 API 有 Example 测试？（`// Output:` 可验证）
- [ ] 并发安全性已标注？
- [ ] README 有安装、快速上手、API 概览？

## 4. 测试

- [ ] 覆盖率 ≥ 80%？
- [ ] table-driven 风格？
- [ ] 覆盖 success + error + edge case？
- [ ] Example 测试有 `// Output:`？
- [ ] 性能关键路径有 Benchmark（`b.ReportAllocs()`）？
- [ ] `-race` 通过？

## 5. 依赖

- [ ] 零外部依赖或最小依赖？
- [ ] 需要第三方时优先用了 `github.com/gtkit/*`？
- [ ] JSON 用的是 `gtkit/json` 或 `gtkit/json/v2`？（禁止 `encoding/json`）
- [ ] 没有引入比自身更重的依赖？
- [ ] `internal/` 隔离了实现细节？

## 6. 并发安全

- [ ] 需要线程安全的类型加了锁？
- [ ] 不需要线程安全的没有多余的锁？
- [ ] GoDoc 明确标注了并发安全性？
- [ ] Benchmark 包含并行场景？

## 7. 兼容性

- [ ] 导出 API 没有破坏已有签名？（如有，需升大版本）
- [ ] 废弃 API 用 `// Deprecated:` 标记？
- [ ] go.mod 的 module path 与版本一致？（v2+ 需要 `/v2`）

## 8. Go 1.26.2 现代特性

- [ ] 用 `slices`/`maps`/`cmp` 替代手写循环？
- [ ] 合理使用泛型（不过度、不不足）？
- [ ] 用 `b.Loop()` 替代 `for i := 0; i < b.N; i++`？
- [ ] 用 `slog` 替代 `log`（如需日志）？

## 9. 反编造

- [ ] 所有标准库 API 调用真实存在？
- [ ] 泛型约束语法正确？
- [ ] 不确定的已标注"需确认"？

---

## 合规摘要

```
## 合规检查摘要
- [x] Go 1.26.2 现代特性
- [x] 零/最小外部依赖
- [x] Functional Options + 合理默认值
- [x] 导出 API 全部有 GoDoc
- [x] Example 测试（可验证）
- [x] 测试覆盖 ≥ 80%（success + error + edge）
- [x] Benchmark（ReportAllocs）
- [x] 错误体系（sentinel + 自定义类型 + wrapping）
- [x] 并发安全标注
- [x] API 兼容性
- [x] 无编造内容
```
