# AGENTS.md

> Go 扩展包（第三方库）开发专用。库代码标准比业务代码更高。

## 行为纪律

1. **禁止编造**：不确定的标准库 API、泛型语法不写，问用户。
2. **禁止猜测**：不说"应该支持"、"大概是"。
3. **严格按结构输出**：只写要求的功能，不自作主张加 feature。
4. **库代码零容忍**：不留 TODO、不留 panic、不留未处理的 error。
5. **清理杂物**：发现项目中有 `.idea/`、`.DS_Store` 或误写的 `.Ds_Store`，必须删除并保持工作区干净。

## 技术栈

- Go 1.26.2（使用所有现代特性：泛型、slices/maps/cmp、range-over-func、iterator）
- 零外部依赖优先，能用标准库的绝不引入第三方；JSON 场景统一视为例外
- **必须引入第三方时，优先使用 `github.com/gtkit/*`**
- **JSON 必须用 `github.com/gtkit/json` 或 `github.com/gtkit/json/v2`，禁止 `encoding/json`**

## Logic 四步

1. **理解需求**：包解决什么问题？给谁用？核心 API？是否需要并发安全/泛型？
2. **提取信息**：加载对应 Guide
3. **按结构组织**：按 `pkg-structure.md` 的目录模板
4. **检查合规**：传感器 + 自审 + 合规摘要

## Guide 加载表

| 场景 | 读哪个 Guide |
|-----|-------------|
| 包结构、接口、Options | `.harness/guides/pkg-structure.md` |
| 错误设计 | `.harness/guides/pkg-errors.md` |
| 测试、Benchmark、Example | `.harness/guides/pkg-testing.md` |
| 文档、README、CHANGELOG | `.harness/guides/pkg-docs.md` |
| 泛型 | `.harness/guides/pkg-generics.md` |
| 代码审查 | `.harness/guides/pkg-review.md` |
| 所有任务 | `pkg-structure.md` 始终生效 |

## 提交前检查

```bash
go vet ./...
golangci-lint run ./...
go test -race -count=1 -timeout=5m ./...
go test -bench=. -benchmem -count=3 ./...
go test -coverprofile=coverage.out ./...
```

## 合规摘要

每次交付附上：
```
## 合规检查摘要
- [x] Go 1.26.2 现代特性
- [x] 零/最小外部依赖
- [x] Functional Options + 合理默认值
- [x] 导出 API 全部有 GoDoc
- [x] Example 测试（可验证）
- [x] 测试覆盖 ≥ 80%
- [x] Benchmark（ReportAllocs）
- [x] 错误体系完整
- [x] 并发安全标注
- [x] 无编造内容
```

## 错误记忆

`.harness/error-journal.md`——犯错时追加，下次读取规避。

## 沟通与提交规范

### 沟通语言

**与用户的所有对话必须使用简体中文**，包括解释、确认、进度汇报、错误说明。

### Commit 规范（强制）

- 格式：`<类型>(<范围>): <标题>`，必要时附正文和页脚
- 语言：Header / Body / Footer 全部使用简体中文
- 类型：`feat` | `fix` | `docs` | `style` | `refactor` | `perf` | `test` | `chore` | `ci` | `revert`
- 标题：祈使句、现在时态（用"添加"而非"添加了"），结尾不加句号
- 范围：尽可能具体（如 `auth`、`ui`、`api`），不确定可省略括号
- 正文：仅在需要解释"为什么"时添加，说明动机而非实现
- 页脚：关联 Issue 用 `Closes #ID`；破坏性变更以 `BREAKING CHANGE:` 开头
- 输出限制：仅输出 Commit Message，不加代码块标记、不加寒暄
- 示例：
  - `fix(auth): 修复移动端登录页面显示异常`
  - `feat(cart): 添加购物车核心功能`

## 文档维护

- **新增功能或变更使用方法时，必须同步更新 README**（项目根 `README.md` 或模块对应 README）
- 更新范围：功能清单、安装/初始化步骤、命令示例、配置项说明、目录结构
- 提交纪律：README 更新与功能代码须在同一次提交中完成，避免文档滞后
- 交付前自检：若本次变更涉及对外接口、CLI 命令、环境变量、使用流程，而 README 未同步，判定为未完成
