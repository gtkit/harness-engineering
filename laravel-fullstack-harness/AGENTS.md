# AGENTS.md

> Laravel + Vue 全栈 Harness。后端代码在 `backend/`，前端代码在 `frontend/`。

## 行为纪律

1. **禁止编造**：不确定的 Laravel / PHP / Vue / Vite / TypeScript API、命令、配置项不写。
2. **禁止猜测**：版本、目录结构、构建方式必须以项目事实为准。
3. **严格按结构输出**：只做用户要求的事，不跨前后端乱扩展。
4. **前后端不混**：后端任务不自动补前端，前端任务不自动补后端。
5. **清理杂物**：发现 `.idea/`、`.DS_Store` 或误写的 `.Ds_Store`，必须删除并保持工作区干净。

## 技术栈

**后端**：Laravel / PHP，代码在 `backend/`  
**前端**：Vue 3 + Vite + TypeScript，代码在 `frontend/`  
**可选结构**：后端可支持 `nwidart/laravel-modules`

## Logic 四步

1. **理解需求**：判断是后端、前端还是联调
2. **提取信息**：读取对应 guide，确认项目版本和目录事实
3. **按结构组织**：后端保持 Laravel 分层，前端保持 views → composables → api
4. **检查合规**：执行验证命令、自审、交叉验证、输出合规摘要

## Guide 加载表

| 任务 | 读哪个 Guide |
| --- | --- |
| 后端结构 / 分层 | `.harness/guides/architecture.md` |
| 后端 HTTP / API | `.harness/guides/http-and-api.md` |
| 后端数据层 | `.harness/guides/data-and-eloquent.md` |
| Queue / Scheduler / Event | `.harness/guides/queues-events-scheduling.md` |
| Notification / Mail | `.harness/guides/notifications-and-mail.md` |
| 后端测试 / 验证 | `.harness/guides/testing-and-validation.md` |
| 检测到 `Modules/` 或 `nwidart/laravel-modules` | `.harness/guides/laravel-modules.md` |
| 前端结构 | `.harness/guides/frontend-architecture.md` |
| 前端 API 契约 | `.harness/guides/frontend-api.md` |
| 前端编码 | `.harness/guides/frontend-coding.md` |
| 代码审查 | `.harness/guides/review-checklist.md` |

## 后端约束

- 后端代码只在 `backend/`
- Controller / Form Request / Resource / Service / Repository / Job / Listener / Notification 分层明确
- Queue / Scheduler / Event / Notification 默认纳入强约束

## 前端约束

- 前端代码只在 `frontend/`
- `views -> composables -> api -> backend`
- 禁止 `any`
- 禁止组件直接写 axios
- 后端 API 契约变化时，前端类型必须同步

## 提交前检查

后端：

```bash
cd backend && php artisan about
cd backend && php artisan test
cd backend && php artisan route:list
```

前端：

```bash
cd frontend && npx vue-tsc --noEmit
cd frontend && npx eslint src/ --ext .vue,.ts,.tsx
cd frontend && npm run build
```

## 前后端契约同步

- Laravel Resource / 错误码 / 分页结构变更时，前端 API 类型同步
- 后端 DTO / Resource 变更时，检查 `frontend/src/api/` 与类型定义

## 合规检查摘要

```text
## 合规检查摘要
- [x] 后端在 backend/，前端在 frontend/
- [x] Laravel / Vue 版本按项目事实处理
- [x] Queue / Scheduler / Event / Notification 已检查
- [x] 前后端 API 契约已对齐
- [x] 验证命令已执行或明确说明缺失条件
- [x] 无编造内容
```

## 错误记忆

`.harness/error-journal.md` —— 每次任务前读取，犯错时追加。

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
