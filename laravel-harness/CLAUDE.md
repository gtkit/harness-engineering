# CLAUDE.md

> Claude Code 项目级完整规则入口。
> 为避免依赖全局厚 skill，本文件承载完整项目规则；与 `AGENTS.md` 应保持同级完整。

---
## 行为纪律

1. **禁止编造**：不确定的 Laravel / PHP API、artisan 命令、配置项、第三方包能力不写。
2. **禁止猜测**：不说“应该支持”“大概如此”，版本和项目结构都必须以仓库事实为准。
3. **严格按结构输出**：只做用户要求的事，不追加无关功能或重构。
4. **不扩展无关内容**：只处理 Laravel、PHP、HTTP、Eloquent、Queue、Event、Scheduler、Notification、Testing 相关内容。
5. **多解陈列**：指令存在多种合理解释时，并列呈现给用户选择，不默默择一实现。
6. **反推更简方案**：发现比用户原方案更简单的做法（Eloquent 够用就别上仓储、一个 Job 搞定就别加 Service），主动提出并说明权衡。
7. **量化自检**：写完自问"senior 会不会觉得过度复杂？200 行能否压到 50 行？"；单次使用的代码不写抽象 / 配置项 / 扩展点。

## 技术栈

- Laravel / PHP 版本优先跟随项目已有 `composer.json` / `composer.lock`
- 如果项目未体现明确版本，默认按当前稳定版 Laravel + PHP 理解，但必须标明这是默认基线
- 可选支持 `nwidart/laravel-modules`
- Queue / Scheduler / Event / Notification 默认纳入强约束

## Logic 四步

1. **理解需求**：判断是 HTTP、数据层、队列、事件、定时任务、通知、测试还是模块化问题
2. **提取信息**：识别项目版本、现有目录结构、受影响模块、验证范围
3. **按结构组织**：Controller / Form Request / Resource / Service / Repository / Job / Listener / Notification 各司其职
4. **检查合规**：运行验证命令、自审、交叉验证、输出合规摘要

## Codex 命令化工作流兼容入口

Claude Code 可以直接使用 `/harness:*` slash commands；Codex 不会自动注册 `.claude/commands/`。当用户在 Codex 中使用以下自然语言别名前缀时，必须把它当作同名 harness command 处理：

| Codex 输入前缀 | 对应流程 |
|---------------|----------|
| `harness doctor` / `harness doctor: <focus>` | 诊断 harness、OpenSpec、命令模板和可选 MCP 状态 |
| `harness init-openspec` | 初始化或验证 OpenSpec；安装全局工具前必须先确认 |
| `harness research: <需求>` | 只做需求研究，输出约束集、风险、开放问题和可验证成功标准，不写代码 |
| `harness plan` / `harness plan: <proposal_id>` | 基于已批准约束集生成零决策计划，不写代码 |
| `harness implement` / `harness implement: <proposal_id>` | 只按已批准计划分阶段实现并验证 |
| `harness review` / `harness review: <scope>` | 按 harness 质量门禁审查当前 diff |

执行规则：

1. 如果 `.claude/commands/harness/<name>.md` 存在，先读取对应模板并严格按模板执行。
2. 如果命令模板不存在，仍按上表的流程意图执行，但必须说明缺少模板文件。
3. 不把 `harness ...` 当作 shell 命令执行；它是 Codex 的自然语言工作流别名。
4. 简单小改动不强制走完整 RPI；复杂、高风险、跨模块任务优先使用 `research → plan → implement → review`。
5. `research` 和 `plan` 阶段不得修改代码；`implement` 必须基于用户已批准的计划。

## 外科式修改（Surgical Changes）

每一行 diff 必须能追溯到用户的本次请求。

- **不顺手改**：相邻无关代码、注释、格式、命名、use 顺序一律不动
- **不重构未坏的代码**：你偏好的写法（如把 Facade 改依赖注入）不是改动理由，匹配既有风格
- **只清自己的孤儿**：本次改动产生的未引用 use / 变量 / 方法 / 路由必须清理；既有死代码发现了**提一下，别删**
- **Migration / Seeder 零回溯**：已合并到主干的 migration 不可修改，需要调整时新建一份
- **边界测试**：提交前对着 diff 逐行问"这一行为什么存在？"——答不上来就删

## 代码质量门禁

每次实现、修复、重构后必须做质量自检；不通过就继续调整，不把低质量代码交付给用户。

- **复杂度阈值**：单类、单方法、单文件过长或嵌套过深时必须拆分或说明理由
- **隐式副作用禁令**：构造过程、ServiceProvider、middleware、事件注册阶段不得偷偷起复杂流程、写库或发请求
- **TODO 纪律**：不留无主 `TODO` / `FIXME`；要么删除，要么绑定 issue / 负责人 / 处理期限
- **变更单一职责**：一次改动尽量只解决一类问题，功能、重构、格式修正不要混在一起
- **减少冗余**：重复逻辑超过 2 次必须提取；重复结构相似但业务含义不同的，优先保持清晰，不为复用而复用
- **代码复用**：优先复用已有 Form Request、Resource、Service、Action、Repository、Policy、Job 和 helper；新增抽象必须至少解决真实重复或隔离复杂度
- **架构清晰**：代码必须放在职责匹配的位置；禁止为了方便把业务逻辑塞进 Controller、Model accessor、Resource、Job 或 Listener
- **分层合理**：Controller 只编排请求响应，Service/Action 承载业务，Repository/Query Object 封装数据访问；跨模块乱依赖、循环依赖、数据层反向依赖 HTTP 层均视为违规
- **健壮稳定**：错误路径、空值、边界输入、事务、幂等、队列重试、资源释放、外部依赖失败必须有明确处理
- **简单优先**：Laravel 原生能力能清晰解决时，不提前引入 Repository、Service、事件链、配置项或复杂抽象

## 可验证目标（Goal-Driven Execution）

动手前把模糊任务转成可验证目标，再编码。

**转换模板：**

| 模糊指令 | 可验证目标 |
|---------|----------|
| "加个校验" | 写 FormRequest + 非法输入 Feature 测试 → 让它通过 |
| "修这个 bug" | 写 Feature/Unit 测试复现 → 让它通过 |
| "重构 X" | 确认改前 `php artisan test` 全绿 → 改后仍全绿 |
| "加个 Job" | 写 Job 单测 + `Bus::fake()` dispatch 断言 → 让它通过 |
| "让它能跑" | 不可验证，退回用户澄清成功标准 |

**多步任务先列计划：**

    1. [步骤] → verify: [可观察的检查]
    2. [步骤] → verify: [可观察的检查]

强目标让你独立闭环；弱目标会把你和用户都拖进反复澄清循环。

### 迭代与停止纪律（Verify–Correct Loop）

把"写完就交"换成"改一轮验一轮"的闭环，但闭环必须有上界，不允许空转。

- **先观察再改**：每次修复前先读真实报错 / 失败用例 / 实际输出，禁止不看错误盲改。说不清"上一轮为什么失败"就不许进下一轮。
- **改完跑相关全量**：单点修复后重跑该模块相关的全部检查（lint + 受影响测试），不只跑新加的那条，防止按下葫芦浮起瓢的回归。
- **自纠上界**：同一问题连续自纠 3 轮仍不达标，立即停手——不再继续试错或换花样硬凑，转为向用户汇报：已尝试什么、当前现象、卡在哪、你的判断和建议的下一步。
- **进展为正才继续**：每轮结束确认"离目标更近"（失败项减少 / 错误更聚焦）。出现来回震荡（同一处反复改回原样）视同卡住，按上界处理。
- **回归确认**：修复后必须确认是真修复而非巧合通过；确认后按错误记忆规则追加 `.harness/error-journal.md`，避免重蹈覆辙。

停止并升级不是失败，是把不确定性交还给用户的正确动作；空转硬试才是。

## Guide 加载表

| 任务 | 读哪个 Guide |
| --- | --- |
| 结构设计 / 分层 / 目录边界 | `.harness/guides/architecture.md` |
| Controller / Form Request / Resource / API | `.harness/guides/http-and-api.md` |
| Eloquent / Repository / 事务 / 迁移 | `.harness/guides/data-and-eloquent.md` |
| Queue / Scheduler / Event / Listener | `.harness/guides/queues-events-scheduling.md` |
| Notification / Mail / Channel | `.harness/guides/notifications-and-mail.md` |
| 测试 / 回归 / 验证 | `.harness/guides/testing-and-validation.md` |
| 检测到 `Modules/` 或 `nwidart/laravel-modules` | `.harness/guides/laravel-modules.md` |
| 代码审查 | `.harness/guides/review-checklist.md` |

## 默认分层

```text
Controller / Form Request / Resource
        ↓
Action / Service / Domain
        ↓
Repository / Query Object / Eloquent
```

补充约束：

- Controller 只做参数接收、授权、调用、返回
- Form Request 承担输入校验与授权入口
- API Resource 负责输出序列化
- Job 只承接异步边界，不承接隐式事务编排
- Listener 保持轻量，跨边界逻辑优先下沉到 Service
- Notification / Mail 独立建类，避免内联模板和文案

## 提交前检查

优先使用项目已有统一入口：

```bash
composer test
composer pint --test
./vendor/bin/phpstan analyse
./vendor/bin/psalm
```

如果项目没有统一入口，至少执行：

```bash
php artisan about
php artisan test
php artisan route:list
```

## 必查风险

- Queue Job 是否幂等
- 定时任务是否可重复执行且无副作用失控
- 事件 / 监听器是否存在隐式递归或隐藏 IO
- Notification / Mail 是否泄漏敏感信息
- Eloquent 是否有 N+1、事务缺失、锁粒度错误
- 模块化项目是否存在跨 `Modules/` 乱依赖

## 合规检查摘要

每次交付附上：

```text
## 合规检查摘要
- [x] Laravel / PHP 版本按项目事实处理
- [x] Controller / Service / Data 边界明确
- [x] Queue / Scheduler / Event / Notification 已纳入检查
- [x] Modules 可选规则已按需加载
- [x] 验证命令已执行或明确说明缺失条件
- [x] 代码质量门禁：无明显冗余，复用合理，职责清晰，健壮性已检查
- [x] 无编造内容
```

## 错误记忆

`.harness/error-journal.md` —— 每次任务前读取，犯错时追加。

优先执行项目内脚本：

```bash
bash .harness/scripts/read-error-journal.sh .
bash .harness/scripts/append-error-journal.sh . user-correction laravel "用户指出控制器职责下沉不完整"
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .harness/scripts/read-error-journal.ps1 -RepoRoot .
powershell -NoProfile -ExecutionPolicy Bypass -File .harness/scripts/append-error-journal.ps1 -RepoRoot . -EventType user-correction -Area laravel -Summary "用户指出控制器职责下沉不完整"
```

用户提示词中出现“犯错”“错误”“错了”“不对”“有问题”“bug”“失败”“回归”等纠错或追责信号时，必须先追加错误记录再继续处理。
用户纠正、命令失败、测试失败、审查发现缺陷、回归问题时，也必须先追加错误记录再继续处理。

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
