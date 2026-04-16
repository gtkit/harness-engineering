---
name: go-pkg-harness
description: |
  Go 扩展包（第三方库）开发专用 Harness skill。当用户开发独立的 Go package 供其他项目引用时触发。覆盖：包结构设计、Functional Options、接口设计、错误体系、GoDoc 文档、Example 测试、语义化版本、API 兼容性、并发安全、泛型应用、benchmark。关键词：Go 包、Go 库、Go package、Go module、扩展包、第三方库、pkg、工具库、SDK、Functional Options、GoDoc、Example Test、semver、go mod、泛型。即使用户只是说"帮我写个工具包"、"封装一个 xxx 库"、"写个通用的 xxx"，也应触发。
---

# Go Package Harness Skill

> 专为 Go 扩展包（第三方库）开发设计的约束系统。
> 库代码的标准比业务代码更高——你写的每一行都会被别人依赖。

---

## 第零章：行为纪律

1. **禁止编造**：不确定的标准库 API、泛型约束语法不写，先确认再动手。
2. **禁止猜测**：不说"这个包应该有 xxx 方法"。
3. **严格按结构输出**：只写用户要求的功能，不自作主张加 feature。
4. **库代码零容忍**：不留 TODO、不留 panic、不留未处理的 error。
5. **执行清理**：如果项目中存在 `.idea/`、`.DS_Store` 或误写的 `.Ds_Store`，必须删除并保持工作区干净。

---

## 第一章：技术栈

- **Go 1.26.2**（使用所有现代特性：泛型、range-over-func、slices/maps/cmp、iterator）
- **零外部依赖优先**：能用标准库实现的绝不引入第三方；JSON 场景统一视为例外
- **必须引入第三方时，优先使用 `github.com/gtkit/` 仓库下的包**
- gtkit 没有的，再选最小依赖、最活跃维护的第三方
- **JSON 操作必须使用 `github.com/gtkit/json` 或 `github.com/gtkit/json/v2`**，禁止使用 `encoding/json` 或其他第三方 JSON 库

---

## 第二章：Logic 思维链

### Step 1：理解需求

- 这个包解决什么问题？给谁用？
- 核心 API 是什么？（几个主要函数/方法）
- 是否需要并发安全？
- 是否需要泛型？
- 有歧义立即提问

### Step 2：提取关键信息 → 加载 Guide

| 场景 | 加载的 Guide |
|-----|-------------|
| 包结构、接口、Options 设计 | `.harness/guides/pkg-structure.md` |
| 错误体系设计 | `.harness/guides/pkg-errors.md` |
| 测试、Benchmark、Example | `.harness/guides/pkg-testing.md` |
| 文档、README、CHANGELOG | `.harness/guides/pkg-docs.md` |
| 泛型应用 | `.harness/guides/pkg-generics.md` |
| 代码审查 | `.harness/guides/pkg-review.md` |
| 所有任务 | `.harness/guides/pkg-structure.md` 始终生效 |

### Step 3：按结构组织

严格按包结构模板输出，文件组织顺序见 `pkg-structure.md`。

### Step 4：检查合规

**计算型传感器：**
```bash
go vet ./...
golangci-lint run ./...
go test -race -count=1 -timeout=5m ./...
go test -bench=. -benchmem ./...
```

**推理型自审**（按 `pkg-review.md`）

**合规摘要：**
```
## 合规检查摘要
- [x] Go 1.26.2 现代特性
- [x] 零/最小外部依赖
- [x] Functional Options
- [x] 导出 API 全部有 GoDoc
- [x] Example 测试
- [x] 测试覆盖 ≥ 80%
- [x] 错误用 sentinel + 自定义类型
- [x] 并发安全标注
- [x] 无编造内容
```

---

## 第三章：错误记忆

`.harness/error-journal.md`——犯错时追加，下次读取规避。

---

## Guides 目录

| 文件 | 内容 |
|-----|------|
| `pkg-structure.md` | 包结构、接口设计、Functional Options、命名、API 稳定性 |
| `pkg-errors.md` | sentinel error、自定义错误类型、error wrapping |
| `pkg-testing.md` | table-driven 测试、Example 测试、Benchmark、覆盖率 |
| `pkg-docs.md` | GoDoc、README、CHANGELOG、LICENSE |
| `pkg-generics.md` | 泛型函数/类型、类型约束、何时用何时不用 |
| `pkg-review.md` | 包级专项审查清单 |
