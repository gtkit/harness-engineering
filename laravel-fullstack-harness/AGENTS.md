# AGENTS.md

> Laravel + Vue 全栈 Harness。后端代码在 `backend/`，前端代码在 `frontend/`。

## 行为纪律

1. **禁止编造**：不确定的 Laravel / PHP / Vue / Vite / TypeScript API、命令、配置项不写。
2. **禁止猜测**：版本、目录结构、构建方式必须以项目事实为准。
3. **严格按结构输出**：只做用户要求的事，不跨前后端乱扩展。
4. **前后端不混**：后端任务不自动补前端，前端任务不自动补后端。
5. **清理杂物**：发现 `.idea/`、`.DS_Store` 或误写的 `.Ds_Store`，必须删除并保持工作区干净。
6. **多解陈列**：指令存在多种合理解释时，并列呈现给用户选择，不默默择一实现。
7. **反推更简方案**：发现比用户原方案更简单的做法时，主动提出并说明权衡，不默默按原方案堆代码。
8. **量化自检**：写完自问"senior 会不会觉得过度复杂？200 行能否压到 50 行？"；单次使用的代码不写抽象 / 配置项 / 扩展点。

## 技术栈

**后端**：Laravel / PHP，代码在 `backend/`  
**前端**：Vue 3 + Vite + TypeScript，代码在 `frontend/`  
**可选结构**：后端可支持 `nwidart/laravel-modules`

## Logic 四步

1. **理解需求**：判断是后端、前端还是联调
2. **提取信息**：读取对应 guide，确认项目版本和目录事实
3. **按结构组织**：后端保持 Laravel 分层，前端保持 views → composables → api
4. **检查合规**：执行验证命令、自审、交叉验证、输出合规摘要

## 外科式修改（Surgical Changes）

每一行 diff 必须能追溯到用户的本次请求。

- **不顺手改**：相邻无关代码、注释、格式、命名、use/import 顺序一律不动
- **不重构未坏的代码**：你偏好的写法不是改动理由，匹配既有风格
- **只清自己的孤儿**：本次改动产生的未引用 use / import / 变量 / 方法 / composable / store 字段必须清理；既有死代码发现了**提一下，别删**
- **前后端边界**：改 `backend/` 时不顺手动 `frontend/`，反之亦然
- **Migration 零回溯**：已合并到主干的 migration 不可修改，需要调整时新建一份
- **边界测试**：提交前对着 diff 逐行问"这一行为什么存在？"——答不上来就删

## 可验证目标（Goal-Driven Execution）

动手前把模糊任务转成可验证目标，再编码。

**转换模板：**

| 模糊指令 | 可验证目标 |
|---------|----------|
| "加个校验" | 后端写 FormRequest + 非法输入测试；前端写组件测试 → 让它通过 |
| "修这个 bug" | 写 Feature/Unit 测试复现 → 让它通过 |
| "重构 X" | 确认改前测试全绿（`php artisan test` / `pnpm test`）→ 改后仍全绿 |
| "联调接口" | 先定好 DTO 契约 → 后端 FeatureTest + 前端 mock 请求断言对齐 |
| "让它能跑" | 不可验证，退回用户澄清成功标准 |

**多步任务先列计划：**

    1. [步骤] → verify: [可观察的检查]
    2. [步骤] → verify: [可观察的检查]

强目标让你独立闭环；弱目标会把你和用户都拖进反复澄清循环。

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

## 敏感信息与 .gitignore 安全基线

### 禁止入库（零容忍）

- 环境变量文件：`.env`、`.env.local`、`.env.production` 等
- 密钥文件：`*.pem`、`*.key`、`id_rsa`、`secrets.*`、`credentials.*`
- 带真实密钥的配置文件（`config.*.yml`、`application.properties` 含密钥版本等）
- 云服务凭据：AWS / 阿里云 / 腾讯云 AccessKey、Service Account JSON
- 系统 / IDE 产物：`.DS_Store`、`.idea/`、`.vscode/`（除非团队共享）
- 构建 / 测试产物：`dist/`、`build/`、`coverage/`、`*.log`

### 代码内禁止硬编码

- API Key、密码、Token、私钥、JWT Secret、Session Secret、加密 Salt 一律从环境变量或密钥管理服务读取
- 本地开发用 `.env.example` 提供占位符，真实值放 `.env`（不入库）
- 日志禁止打印完整密钥，必要时脱敏（如 `sk-****abcd`、`Bearer ****`）
- 返回给客户端的错误信息、响应体必须过滤敏感字段
- 测试禁止使用真实密钥，用 mock / fixture 替代

### .gitignore 必备条目

    .env
    .env.*
    !.env.example
    *.pem
    *.key
    secrets.*
    credentials.*
    .DS_Store
    .idea/
    dist/
    build/
    coverage/
    *.log

各技术栈按需补齐（Go `bin/`、Node `node_modules/`、PHP `vendor/` 等）。

### 事故响应

- 发现敏感信息已入库：**立即吊销该密钥**，再从 Git 历史清除（`git filter-repo` / BFG）
- 已推送到远端的密钥视作"已泄露"，不可靠删除掩盖
- 事件记录到 `.harness/error-journal.md`，避免重蹈覆辙

## CHANGELOG 规范（Keep a Changelog）

根目录维护 `CHANGELOG.md`，遵循 [Keep a Changelog 1.1.0](https://keepachangelog.com/zh-CN/1.1.0/) 格式。

### 区段结构（示例）

    # Changelog

    ## [Unreleased]

    ### Added
    ### Changed
    ### Deprecated
    ### Removed
    ### Fixed
    ### Security

    ## [1.2.0] - 2026-04-17

    ### Added
    - 新增用户导出 API（支持 CSV / Excel 格式）

    ### Fixed
    - 修复移动端登录页面显示异常

### 变更类别

- **Added** 新功能
- **Changed** 现有功能的变更
- **Deprecated** 即将移除的功能
- **Removed** 已移除的功能
- **Fixed** Bug 修复
- **Security** 安全相关修复

### 写作约束

- 语言：简体中文
- 视角：站在下游用户 / 消费者角度描述，不写实现细节
- 粒度：一条一件事，对应一个 PR 或一组强相关 commit
- 关联：条目尾部附 Issue / PR 链接，如 `（#123）`
- 禁止写入：`refactor xxx`、`bump version`、`update deps` 等内部动作

### 维护纪律

- 每个 PR 合并主干时，同步更新 `[Unreleased]` 区段
- 发版时：将 `[Unreleased]` 内容剪切到新版本区段，附日期（`YYYY-MM-DD`），Unreleased 清空
- 破坏性变更在对应版本条目顶部用 **⚠ 破坏性变更** 标注
