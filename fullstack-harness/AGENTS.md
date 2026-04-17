# AGENTS.md

> Go 后端 + Vue 前端全栈项目，前后端代码在同一目录下。

## 行为纪律

1. **禁止编造**：不确定的 API、包名、组件 props 不写，问用户。
2. **禁止猜测**：不说"应该支持"、"大概是"。
3. **严格按结构输出**：只做用户要求的事，不扩展。
4. **前后端不混**：后端任务不自动补前端，反之亦然。
5. **清理杂物**：发现项目中有 `.idea/`、`.DS_Store` 或误写的 `.Ds_Store`，必须删除并保持工作区干净。

## 技术栈

**后端**：Go 1.26.2 + Gin + GORM + gtkit（代码在 `backend/`）
**前端**：Vue 3 + Vite + TypeScript strict + Pinia + Axios（代码在 `frontend/`）
**JSON**：后端统一使用 `github.com/gtkit/json` 或 `github.com/gtkit/json/v2`，禁止 `encoding/json`
依赖使用最新稳定版。

## Logic 四步

1. **理解需求**：判断是后端、前端还是联调，有歧义提问
2. **提取信息**：加载对应 Guide（见下表）
3. **按结构组织**：后端按 handler→service→repo，前端按 views→composables→api
4. **检查合规**：运行传感器 + 自审 + 交叉验证 + 合规摘要

## Guide 加载表

| 任务 | 读哪个 Guide |
|-----|-------------|
| 后端 API | `.harness/guides/architecture.md` + `.harness/guides/api-conventions.md` |
| 数据库 | `.harness/guides/db-patterns.md` |
| 大模型 | `.harness/guides/llm-integration.md` |
| 支付 | `.harness/guides/payment.md` |
| Go 扩展包 | `.harness/guides/pkg-design.md` |
| 前端页面/组件 | `.harness/guides/frontend-architecture.md` + `.harness/guides/frontend-coding.md` |
| 前端 API 对接 | `.harness/guides/frontend-api.md` |
| 前后端联调 | `.harness/guides/api-conventions.md` + `.harness/guides/frontend-api.md` |
| 代码审查 | `.harness/guides/review-checklist.md` |

## 后端分层

```
handler → service → repository
```
- handler 禁止 import gorm / repository
- service 禁止 import gin
- pkg/ 禁止 import internal/

## 前端分层

```
views → composables → api → 后端
```
- views/components 禁止直接 import axios
- components 只接收 props + emit，不调用 api/
- 禁止 `any`，禁止 Options API，禁止硬编码后端 URL

## 提交前检查

```bash
# 后端
cd backend && golangci-lint run ./...
cd backend && go vet ./...
cd backend && go test -race -count=1 -timeout=5m ./...

# 前端
cd frontend && npx vue-tsc --noEmit
cd frontend && npx eslint src/ --ext .vue,.ts,.tsx
cd frontend && npx vite build
```

## 前后端类型同步

后端 DTO 改了，前端 `frontend/src/api/types.ts` 必须同步：
- Go struct json tag ↔ TS interface 字段名
- Go 指针字段 ↔ TS 可选字段 `?`
- Go oneof ↔ TS union type

## 合规摘要

每次交付附上：
```
## 合规检查摘要
- [x] Go 1.26.2 / Vue 3 + TS strict
- [x] 后端分层 + 前端分层
- [x] 前后端类型同步
- [x] 错误处理完整
- [x] 无硬编码
- [x] 测试覆盖
- [x] 无编造内容
```

## 错误记忆

`.harness/error-journal.md`——每次任务前读取，犯错时追加。

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
