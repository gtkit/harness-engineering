# Harness Engineering 工具包

> 让 AI 编码代理（Claude Code / OpenAI Codex）在严格约束下写出企业生产级代码。
>
> 基于 2026 年 Harness Engineering 理念：**同样的模型，不同的 Harness，产出质量天差地别。**

---

## 这是什么

五套针对不同场景的 AI 编码约束系统（Harness），安装后 AI 代理每次写代码都会自动遵守你定义的架构规范、编码标准和质量检查流程。

| 包名 | 适用场景 | 目录 |
|-----|---------|------|
| **go-harness** | 纯 Go 后端业务服务（Gin + GORM + gtkit） | `go-harness/` |
| **fullstack-harness** | Go 后端 + Vue 前端（同一项目目录） | `fullstack-harness/` |
| **go-pkg-harness** | Go 扩展包 / 第三方库开发 | `go-pkg-harness/` |
| **laravel-harness** | 纯 Laravel 项目（API / Web，默认纳入 Queue / Scheduler / Event / Notification） | `laravel-harness/` |
| **laravel-fullstack-harness** | Laravel 后端 + Vue 前端（`backend/` + `frontend/` 同仓库） | `laravel-fullstack-harness/` |

五套互相独立，按项目类型选用一套即可。

安装后还会在项目内安装一组可选的 Claude Code slash commands。普通小改动可以不用；复杂、高风险、跨模块任务可以用它把工作拆成可恢复的 Research → Plan → Implementation 流程：

| 命令 | 功能 |
|-----|------|
| `/harness:doctor` | 检查 harness、OpenSpec、命令和可选 MCP 工具状态 |
| `/harness:init-openspec` | 初始化或验证 OpenSpec |
| `/harness:research` | 将需求转成约束集和可验证成功标准 |
| `/harness:plan` | 生成零决策执行计划和 PBT / 不变量检查点 |
| `/harness:implement` | 按批准计划分阶段实现并验证 |
| `/harness:review` | 按 harness 质量门禁审查当前变更 |

---

## 目录结构

```
harness-engineering/
├── README.md                ← 你正在读的文件
├── commands/harness/        ← Claude Code slash commands
│   ├── doctor.md
│   ├── init-openspec.md
│   ├── research.md
│   ├── plan.md
│   ├── implement.md
│   └── review.md
│
├── go-harness/              ← 纯 Go 后端业务服务
│   ├── setup.sh
│   ├── SKILL.md
│   ├── CLAUDE.md
│   ├── AGENTS.md
│   └── guides/
│       ├── architecture.md
│       ├── api-conventions.md
│       ├── db-patterns.md
│       ├── llm-integration.md
│       ├── payment.md
│       ├── workers-and-scheduling.md
│       ├── pkg-design.md
│       ├── testing-and-validation.md
│       ├── review-checklist.md
│       └── error-journal-template.md
│
├── fullstack-harness/       ← Go + Vue 全栈项目
│   ├── setup.sh
│   ├── SKILL.md
│   ├── CLAUDE.md
│   ├── AGENTS.md
│   └── guides/
│       ├── architecture.md
│       ├── api-conventions.md
│       ├── db-patterns.md
│       ├── llm-integration.md
│       ├── payment.md
│       ├── workers-and-scheduling.md
│       ├── pkg-design.md
│       ├── testing-and-validation.md
│       ├── frontend-architecture.md
│       ├── frontend-api.md
│       ├── frontend-coding.md
│       ├── review-checklist.md
│       └── error-journal-template.md
│
└── go-pkg-harness/          ← Go 扩展包 / 第三方库
    ├── setup.sh
    ├── SKILL.md
    ├── CLAUDE.md
    ├── AGENTS.md
    └── guides/
        ├── pkg-structure.md
        ├── pkg-errors.md
        ├── pkg-testing.md
        ├── pkg-docs.md
        ├── pkg-generics.md
        ├── pkg-release-and-supply-chain.md
        ├── pkg-review.md
        └── error-journal-template.md
│
├── laravel-harness/         ← 纯 Laravel 项目
│   ├── setup.sh
│   ├── SKILL.md
│   ├── CLAUDE.md
│   ├── AGENTS.md
│   └── guides/
│       ├── architecture.md
│       ├── http-and-api.md
│       ├── data-and-eloquent.md
│       ├── queues-events-scheduling.md
│       ├── notifications-and-mail.md
│       ├── testing-and-validation.md
│       ├── laravel-modules.md
│       ├── review-checklist.md
│       └── error-journal-template.md
│
└── laravel-fullstack-harness/ ← Laravel + Vue 全栈项目
    ├── setup.sh
    ├── SKILL.md
    ├── CLAUDE.md
    ├── AGENTS.md
    └── guides/
        ├── architecture.md
        ├── http-and-api.md
        ├── data-and-eloquent.md
        ├── queues-events-scheduling.md
        ├── notifications-and-mail.md
        ├── testing-and-validation.md
        ├── laravel-modules.md
        ├── frontend-architecture.md
        ├── frontend-api.md
        ├── frontend-coding.md
        ├── review-checklist.md
        └── error-journal-template.md
```

---

## 前置要求

- macOS 或 Linux
- 已安装 Claude Code（`~/.claude/` 目录存在）和/或 OpenAI Codex（`~/.codex/` 目录存在）
- Bash（macOS 自带的 bash 3.2+ 或 zsh 均可）

---

## 安装步骤

### 第一步：下载并放到固定位置

将整个 `harness-engineering/` 文件夹放到你喜欢的位置，比如：

```bash
mv harness-engineering ~/tools/harness-engineering
```

以下所有命令假设你放在了 `~/tools/harness-engineering/`。如果放在别的位置，替换对应路径即可。

---

### 第二步：根据项目类型运行对应脚本

每个项目只需要运行一次。脚本会做四件事：

1. **全局 Skill** 安装到 `~/.claude/skills/` 和 `~/.codex/skills/`（只装一次，所有项目共享）
2. **项目文件** 安装到当前项目目录（每个项目各一份，完整规则在这里）
3. **Claude Code Commands** 安装到项目 `.claude/commands/harness/`
4. **忽略规则** 自动创建/补齐：通用产物（`.idea/`、`.vscode/`、`.DS_Store`、`*.log`）写进 `.gitignore`；本地工具与 Agent 运行产物（整个 `.harness/`、`CLAUDE.md`、`AGENTS.md`、`.claude/`、`.codex/`、`openspec/`、计划文件等）写进 `.git/info/exclude`（仅本地、不进版本库，避免忽略规则本身泄露 AI 工具链）

其中：

- Claude Code 全局 skill 是轻量入口，优先把运行时引到项目根目录 `CLAUDE.md`
- Codex 全局 skill 是轻量入口，把运行时引到项目根目录 `AGENTS.md`
- 详细专项规范统一放在 `.harness/guides/`
- Claude Code slash commands 统一放在 `.claude/commands/harness/`
- Codex 通过 `AGENTS.md` 中的 `harness ...` 自然语言别名走同一套流程

---

#### 场景 A：纯 Go 后端业务服务

适用于用 Gin + GORM + gtkit 开发的 Web 服务、API 服务。

```bash
# 进入你的 Go 项目根目录
cd ~/code/your-backend-project

# 运行安装脚本
bash ~/tools/harness-engineering/go-harness/setup.sh
```

安装完成后你的项目会多出：

```
your-backend-project/
├── CLAUDE.md                  ← Claude Code 每次对话自动读取
├── AGENTS.md                  ← Codex 每次任务自动读取
├── .claude/
│   └── commands/
│       └── harness/           ← /harness:* 命令
└── .harness/
    ├── error-journal.md       ← AI 错误记忆文件
    ├── guides/                ← 9 个规范文档
    │   ├── architecture.md         分层架构、依赖方向
    │   ├── api-conventions.md      统一响应格式、错误码
    │   ├── db-patterns.md          GORM、Repository、事务
    │   ├── llm-integration.md      大模型对接（SSE、重试降级）
    │   ├── payment.md              支付（幂等、验签、对账）
    │   ├── workers-and-scheduling.md Worker、队列、定时任务
    │   ├── pkg-design.md           扩展包设计
    │   ├── testing-and-validation.md 测试、回归、验证
    │   └── review-checklist.md     12 维度审查清单
    └── scripts/               ← error-journal 读写脚本
        ├── read-error-journal.sh
        ├── append-error-journal.sh
        ├── read-error-journal.ps1
        └── append-error-journal.ps1
```

---

#### 场景 B：Go + Vue 全栈项目（`backend/` + `frontend/` 同仓库）

适用于后端 Go 放在 `backend/`、前端 Vue 3 + Vite + TypeScript 放在 `frontend/` 的同仓库项目。

```bash
# 进入你的全栈项目根目录
cd ~/code/your-fullstack-project

# 运行安装脚本
bash ~/tools/harness-engineering/fullstack-harness/setup.sh
```

安装完成后你的项目会多出：

```
your-fullstack-project/
├── CLAUDE.md
├── AGENTS.md
├── .claude/
│   └── commands/
│       └── harness/
└── .harness/
    ├── error-journal.md
    ├── guides/                ← 12 个规范文档（后端 9 + 前端 3）
    │   ├── architecture.md
    │   ├── api-conventions.md
    │   ├── db-patterns.md
    │   ├── llm-integration.md
    │   ├── payment.md
    │   ├── workers-and-scheduling.md
    │   ├── pkg-design.md
    │   ├── testing-and-validation.md
    │   ├── frontend-architecture.md
    │   ├── frontend-api.md
    │   ├── frontend-coding.md
    │   └── review-checklist.md
    └── scripts/               ← error-journal 读写脚本
        ├── read-error-journal.sh
        ├── append-error-journal.sh
        ├── read-error-journal.ps1
        └── append-error-journal.ps1
```

---

#### 场景 C：Go 扩展包 / 第三方库开发

适用于开发独立的 Go package，供其他项目 `go get` 引用。

```bash
# 进入你的 Go 包项目根目录
cd ~/code/your-go-package

# 运行安装脚本
bash ~/tools/harness-engineering/go-pkg-harness/setup.sh
```

安装完成后你的项目会多出：

```
your-go-package/
├── CLAUDE.md
├── AGENTS.md
├── .claude/
│   └── commands/
│       └── harness/
└── .harness/
    ├── error-journal.md
    └── guides/                ← 7 个规范文档
        ├── pkg-structure.md        包结构、接口、Functional Options
        ├── pkg-errors.md           三层错误体系
        ├── pkg-testing.md          测试、Benchmark、Example、Fuzz
        ├── pkg-docs.md             GoDoc、README、CHANGELOG
        ├── pkg-generics.md         泛型应用
        ├── pkg-release-and-supply-chain.md 发布、依赖、供应链安全
        └── pkg-review.md           包级 9 维度审查清单
```

---

#### 场景 D：纯 Laravel 项目

适用于纯 Laravel 项目，兼容 API / Web 两类形态，并默认把 Queue、Scheduler、Event、Notification 纳入强约束。若项目使用 `nwidart/laravel-modules`，模板也支持 `Modules/` 结构。

```bash
# 进入你的 Laravel 项目根目录
cd ~/code/your-laravel-project

# 运行安装脚本
bash ~/tools/harness-engineering/laravel-harness/setup.sh
```

安装完成后你的项目会多出：

```text
your-laravel-project/
├── CLAUDE.md
├── AGENTS.md
├── .claude/
│   └── commands/
│       └── harness/
└── .harness/
    ├── error-journal.md
    └── guides/
        ├── architecture.md
        ├── http-and-api.md
        ├── data-and-eloquent.md
        ├── queues-events-scheduling.md
        ├── notifications-and-mail.md
        ├── testing-and-validation.md
        ├── laravel-modules.md
        └── review-checklist.md
```

---

#### 场景 E：Laravel + Vue 全栈项目（`backend/` + `frontend/` 同仓库）

适用于 Laravel 后端在 `backend/`、Vue 3 + Vite + TypeScript 前端在 `frontend/` 的同仓库项目。

```bash
# 进入你的 Laravel 全栈项目根目录
cd ~/code/your-laravel-fullstack-project

# 运行安装脚本
bash ~/tools/harness-engineering/laravel-fullstack-harness/setup.sh
```

安装完成后你的项目会多出：

```text
your-laravel-fullstack-project/
├── CLAUDE.md
├── AGENTS.md
├── .claude/
│   └── commands/
│       └── harness/
└── .harness/
    ├── error-journal.md
    └── guides/
        ├── architecture.md
        ├── http-and-api.md
        ├── data-and-eloquent.md
        ├── queues-events-scheduling.md
        ├── notifications-and-mail.md
        ├── testing-and-validation.md
        ├── laravel-modules.md
        ├── frontend-architecture.md
        ├── frontend-api.md
        ├── frontend-coding.md
        └── review-checklist.md
```

---

## 安装后的全局 Skill 一览

五套脚本各自安装到不同目录，互不覆盖：

```
~/.claude/skills/
├── go-harness/              ← 场景 A
│   └── SKILL.md
├── fullstack-harness/       ← 场景 B
│   └── SKILL.md
├── go-pkg-harness/          ← 场景 C
│   └── SKILL.md
├── laravel-harness/         ← 场景 D
│   └── SKILL.md
└── laravel-fullstack-harness/ ← 场景 E
    └── SKILL.md

~/.codex/skills/
├── go-harness/              ← 场景 A
│   └── SKILL.md
├── fullstack-harness/       ← 场景 B
│   └── SKILL.md
├── go-pkg-harness/          ← 场景 C
│   └── SKILL.md
├── laravel-harness/         ← 场景 D
│   └── SKILL.md
└── laravel-fullstack-harness/ ← 场景 E
    └── SKILL.md
```

全局 Skill 只是触发入口，实际规范内容在每个项目的 `CLAUDE.md`、`AGENTS.md` 和 `.harness/guides/` 下。

---

## 可选命令化 RPI 工作流

这不是强制流程引擎，而是一组轻量命令模板。普通小改动可以直接让 AI 按 harness 规则完成；复杂、高风险、跨模块需求建议走命令化流程，让上下文只专注一件事。

速查表和典型场景示例见 [Harness Command Workflow 速查](./docs/harness-command-workflow.md)。

想搞清楚 harness 与 Loop 架构（自动化调度 / worktree 隔离 / Skill / MCP / 子 Agent / 记忆）的能力边界——哪些归 harness、哪些归运行时——见 [harness 与 Loop 架构的关系](./docs/harness-and-loop-architecture.md)。

### Claude Code 怎么用

Claude Code 会读取项目里的 `.claude/commands/harness/*.md`，所以可以直接输入 slash command：

```text
/harness:doctor
```

```text
/harness:research
你的需求描述...
```

```text
/harness:plan
```

```text
/harness:implement
```

```text
/harness:review
```

### Codex 怎么用

Codex 不会把 `.claude/commands/` 自动注册成 slash command；它通过 `AGENTS.md` 里的兼容入口识别自然语言别名：

```text
harness doctor
```

```text
harness research: 你的需求描述...
```

```text
harness plan
```

```text
harness implement
```

```text
harness review
```

执行时 Codex 会先读取对应的 `.claude/commands/harness/<name>.md` 模板；如果模板不存在，会按 `AGENTS.md` 中定义的流程意图执行并提示缺少模板文件。不要把 `harness ...` 当作 shell 命令，它是给 Codex 的自然语言工作流别名。

### 命令说明

### 1. 诊断环境

```text
/harness:doctor
```

检查项目是否已安装 harness、OpenSpec 是否可用、`.claude/commands/harness/` 是否齐全，以及可选 MCP 工具是否可用。

Codex 等价写法：

```text
harness doctor
```

### 2. 初始化 OpenSpec（可选）

```text
/harness:init-openspec
```

用于需要 proposal / spec / task 管理的复杂需求。命令会先检查 `openspec`，缺失时询问是否安装，不会静默覆盖现有 OpenSpec 文件。

Codex 等价写法：

```text
harness init-openspec
```

### 3. Research：需求转约束集

```text
/harness:research
你的需求描述...
```

输出不是普通调研总结，而是：

- hard constraints
- soft constraints
- dependencies
- risks
- open questions
- verifiable success criteria

这一步只消除不确定性，不写实现代码。

Codex 等价写法：

```text
harness research: 你的需求描述...
```

### 4. Plan：生成零决策计划

```text
/harness:plan
```

把已批准的约束集变成实现阶段可机械执行的计划，包含：

- files to change
- sequential tasks
- verification per task
- rollback / migration notes
- PBT / invariant / boundary condition / falsification strategy

计划未获批准前不进入实现。

Codex 等价写法：

```text
harness plan
```

### 5. Implement：分阶段实现

```text
/harness:implement
```

按批准计划选择最小可验证任务执行。每完成一个阶段都要跑对应验证；如果上下文变大，会停在 checkpoint，给出下一次恢复方式。

Codex 等价写法：

```text
harness implement
```

### 6. Review：交付前审查

```text
/harness:review
```

按 `.harness/guides/review-checklist.md` 或包级 review guide 检查当前 diff，覆盖 correctness、安全、性能、分层、代码质量门禁、可观测性、兼容性与迁移、测试缺口。

Codex 等价写法：

```text
harness review
```

---

## 工作原理

### 为什么 AI 每次都会遵守规则

```
Claude Code 启动 → 触发轻量 xxx-harness skill → 读取项目 CLAUDE.md → 读取 .harness/guides/
Codex 启动      → 触发轻量 xxx-harness skill → 读取项目 AGENTS.md  → 读取 .harness/guides/
```

兼容旧项目时，Claude 的轻量 skill 会在 `CLAUDE.md` 明显过旧或缺失时，补读 `AGENTS.md` 兜底；Codex 不会去读 `CLAUDE.md`。

`CLAUDE.md` 和 `AGENTS.md` 是各自 Agent 的**无条件自动加载文件**——不需要关键词匹配，不需要手动指定，每次对话/任务都会读取。

### AI 写代码的强制流程（Logic 四步）

```
Step 1 理解需求 → 有歧义就问，不假设
Step 2 提取信息 → 加载对应的 guide 文档
Step 3 按结构写 → 严格按规范模板输出
Step 4 检查合规 → lint + 架构检查 + 自审 + 交叉验证 + 输出合规摘要
```

### 错误记忆机制

```
你的提示词里出现“犯错 / 错误 / 错了 / 不对 / 有问题 / bug / 失败 / 回归”
                或
你纠正 AI / 命令失败 / 测试失败
                ↓
AI 调用 .harness/scripts/append-error-journal.*
                ↓
      追加到 .harness/error-journal.md
                ↓
任务开始前调用 .harness/scripts/read-error-journal.*
                ↓
           主动规避同类错误
```

AI 犯过的错误会被记录下来，形成项目专属的"经验库"。这里的“自动”是指 agent 按项目规则调用脚本，而不是依赖外部黑盒 hook。

---

## 五套 Harness 的核心差异

| 包名 | 定位 | 默认结构 | 关键约束 |
|--|--|--|--|
| `go-harness` | Go 后端业务服务 | 单仓后端 | Gin + GORM + gtkit、分层、支付/LLM/DB 规范 |
| `fullstack-harness` | Go + Vue 全栈 | `backend/` + `frontend/` | Go 后端分层 + Vue 3 + TS strict + 契约同步 |
| `go-pkg-harness` | Go 扩展包 / 第三方库 | 单包 / 多包库 | GoDoc、Benchmark、Example、语义化版本 |
| `laravel-harness` | Laravel 项目 | 单仓 Laravel | HTTP、Eloquent、Queue、Scheduler、Event、Notification、可选 `Modules/` |
| `laravel-fullstack-harness` | Laravel + Vue 全栈 | `backend/` + `frontend/` | Laravel API 契约 + Vue 3 + TS strict + 可选 `Modules/` |

---

## 日常使用

### 安装完就不用管了

脚本只需运行一次。之后正常用 Claude Code 或 Codex 写代码，AI 会自动遵守所有规则。重复执行默认只补齐缺失文件，不覆盖你已经修改过的 guide。

### 修改规范

规则分三层：

- 通用项目入口：`CLAUDE.md` / `AGENTS.md`
- 专项规范：`.harness/guides/`
- 错误记忆运行时：`.harness/scripts/`

比如你想加一条新的 GORM 规则：

```bash
vim .harness/guides/db-patterns.md
# 加上你的新规则，保存
```

下次 AI 写代码时自动生效，Claude Code 和 Codex 都会读到。

### 查看错误记忆

```bash
cat .harness/error-journal.md
```

可以手动编辑，删除过时的条目或补充新的。

也可以直接调用追加脚本生成新条目骨架：

```bash
bash .harness/scripts/append-error-journal.sh . user-correction auth "用户纠正了入口文件边界"
```

### 查看 harness 版本

每次跑 `setup.sh` / `setup.ps1` 都会在项目下写入 `.harness/VERSION`，记录这次安装的 harness 包名、源仓库 commit、安装时间：

```bash
cat .harness/VERSION
# harness: go-harness
# source-commit: a3f4b9c2e8d1
# source-tag: 1.1.1
# installed-at: 2026-05-14T17:30:42+0800
# installer: setup.sh
```

排查"为什么我和同事的 `.harness/guides/` 不一样"时先看这个文件——commit / 安装时间不同就是差异原因。整个 `.harness/` 目录已自动加到项目 `.git/info/exclude`，本地忽略、不入库（含本文件）。

### 在新项目中使用

```bash
cd ~/code/new-project
bash ~/tools/harness-engineering/go-harness/setup.sh                  # Go 后端
bash ~/tools/harness-engineering/fullstack-harness/setup.sh           # Go + Vue 全栈
bash ~/tools/harness-engineering/go-pkg-harness/setup.sh              # Go 扩展包
bash ~/tools/harness-engineering/laravel-harness/setup.sh             # Laravel
bash ~/tools/harness-engineering/laravel-fullstack-harness/setup.sh   # Laravel + Vue 全栈
```

全局 Skill 已经装过了不会重复，只会安装项目级文件。

如果你要把一个老项目的 `CLAUDE.md` / `AGENTS.md` 刷新到最新模板，可显式加环境变量：

```bash
HARNESS_FORCE_PROJECT_FILES=1 bash ~/tools/harness-engineering/go-harness/setup.sh
```

这个开关会刷新项目根目录规则文件和 `.harness/scripts/` 里的运行时脚本，但不会强制覆盖你已经修改过的 `.harness/guides/`。

---

## Git 提交建议

默认策略：**所有 harness 产物都不入库，由每个成员各自运行 `setup.sh` / `setup.ps1` 再生**。setup 把忽略规则**分两处**落地：

`.gitignore`（可入库）——只放通用构建 / 编辑器 / OS 产物：

```
.idea/
.vscode/
.DS_Store
*.log
```

`.git/info/exclude`（仅本地、绝不入库）——本地工具与 Agent 运行产物：

```
.harness/      # 入口规则、guides、运行时脚本、error-journal、VERSION 整目录
CLAUDE.md
AGENTS.md
.claude/       # 含 commands/harness/、个人 Claude 运行状态
.codex/
.agents/
openspec/
.openspec-auto/
.openspec-auto-backup/
tools/
findings.md
progress.md
task_plan.md
```

这样做的两层理由：一是 `.harness/`、`CLAUDE.md`、`AGENTS.md` 都是脚本可重复生成的本地产物，统一来源是本仓库的模板，排除在版本库外可避免「同一份规则在每个业务仓库重复入库、又各自漂移」，需要升级规则时重新跑 setup 即可；二是把这些忽略规则放进 `.git/info/exclude` 而非被跟踪的 `.gitignore`，可避免忽略规则本身泄露「本项目使用了 AI 工具」。

> 老项目此前若已把这些规则写进 `.gitignore`，重跑 setup 会自动把它们从 `.gitignore` 剔除并迁移到 `.git/info/exclude`（你自己的业务规则保持不动）。

### 想在团队内共享定制规则怎么办

如果你确实改了 `.harness/guides/` 并希望团队共享，有两条路：

- **推荐**：把改动回流到本仓库（或你自己 fork 的 harness 模板仓库），团队统一从模板再生，单一可信源。
- **就地共享**：删掉/收窄 `.git/info/exclude` 里对应的整目录忽略行（如把 `.harness/` 换成更细的 `.harness/error-journal.md`、`.harness/VERSION`），再显式 `git add` 需要入库的路径；注意别把 `error-journal.md`、`VERSION` 这类本地状态一起提交。

如果你想让 `main` 分支必须等 CI 通过后才能合并，见：

- [GitHub Branch Protection](./docs/github-branch-protection.md)

---

## 常见问题

**Q：一个项目能同时装两套 Harness 吗？**

不建议。每个项目选一套最匹配的。如果你的项目是 Go 全栈，用 `fullstack-harness`；如果你的项目是 Laravel 全栈，用 `laravel-fullstack-harness`。

**Q：我用的不是 Claude Code 也不是 Codex，能用吗？**

可以。`.harness/guides/` 下的规范文档是通用的 Markdown，任何 AI 代理（Cursor、Windsurf 等）都可以读。你只需要在对应工具的配置文件里指向这些文件即可。`AGENTS.md` 本身也是一个跨 Agent 的开放标准。

**Q：全局 Skill 装错了怎么删？**

```bash
rm -rf ~/.claude/skills/go-harness
rm -rf ~/.claude/skills/fullstack-harness
rm -rf ~/.claude/skills/go-pkg-harness
rm -rf ~/.claude/skills/laravel-harness
rm -rf ~/.claude/skills/laravel-fullstack-harness

rm -rf ~/.codex/skills/go-harness
rm -rf ~/.codex/skills/fullstack-harness
rm -rf ~/.codex/skills/go-pkg-harness
rm -rf ~/.codex/skills/laravel-harness
rm -rf ~/.codex/skills/laravel-fullstack-harness
```

**Q：guides 改错了想恢复怎么办？**

默认重新跑 `setup.sh` 只会补齐缺失 guide，不会覆盖你已经修改过的内容。想强制恢复模板版本时，显式加环境变量：

```bash
HARNESS_FORCE_GUIDES=1 bash ~/tools/harness-engineering/go-harness/setup.sh
```

Laravel 系列同理：

```bash
HARNESS_FORCE_GUIDES=1 bash ~/tools/harness-engineering/laravel-harness/setup.sh
```

**Q：项目里的 `CLAUDE.md` / `AGENTS.md` 老了想升级怎么办？**

默认重新跑 `setup.sh` 不会覆盖项目里已存在的入口文件。想刷新到仓库当前模板时，显式加：

```bash
HARNESS_FORCE_PROJECT_FILES=1 bash ~/tools/harness-engineering/go-harness/setup.sh
```

Laravel / fullstack / go-pkg 也同理，只需要替换对应目录。

**Q：setup.sh 在 macOS 上能跑吗？**

能。脚本兼容 macOS 自带的 bash 3.2 和 zsh，没有用任何 Linux 专有语法。
---

## Windows 用法

现在 5 个 harness 模块都提供 Windows 原生入口：

- `setup.ps1`，用于 PowerShell
- `setup.bat`，用于 `cmd.exe`

建议先进入目标项目根目录，再执行对应模块脚本。下面用相对占位路径示例，避免依赖任何本机绝对路径。

### PowerShell 示例

```powershell
cd .\your-backend-project
powershell -ExecutionPolicy Bypass -File .\path\to\harness-engineering\go-harness\setup.ps1

cd .\your-fullstack-project
powershell -ExecutionPolicy Bypass -File .\path\to\harness-engineering\fullstack-harness\setup.ps1

cd .\your-go-package
powershell -ExecutionPolicy Bypass -File .\path\to\harness-engineering\go-pkg-harness\setup.ps1

cd .\your-laravel-project
powershell -ExecutionPolicy Bypass -File .\path\to\harness-engineering\laravel-harness\setup.ps1

cd .\your-laravel-fullstack-project
powershell -ExecutionPolicy Bypass -File .\path\to\harness-engineering\laravel-fullstack-harness\setup.ps1
```

### 命令提示符示例

```bat
cd /d .\your-backend-project
.\path\to\harness-engineering\go-harness\setup.bat

cd /d .\your-fullstack-project
.\path\to\harness-engineering\fullstack-harness\setup.bat

cd /d .\your-go-package
.\path\to\harness-engineering\go-pkg-harness\setup.bat

cd /d .\your-laravel-project
.\path\to\harness-engineering\laravel-harness\setup.bat

cd /d .\your-laravel-fullstack-project
.\path\to\harness-engineering\laravel-fullstack-harness\setup.bat
```

Windows 下同样支持先设置 `HARNESS_FORCE_GUIDES=1`，再执行任一脚本。

---

## 贡献本仓库（修改 harness 模板）

如果你要改 `setup.sh` / `setup.ps1`、`guides/*.md`、`CLAUDE.md` / `AGENTS.md`、或 `scripts/`，提交前先在本地跑这套门禁，与 CI 保持一致：

```bash
# 1. CLAUDE.md / AGENTS.md 同步检查（修改 AGENTS.md 后必跑）
bash scripts/sync-claude-from-agents.sh --check

# 2. setup.sh 语法 + 行为冒烟测试（5 套）
bash tests/setup_smoke_test.sh

# 3. error-journal 脚本契约单测
bash tests/error_journal_test.sh

# 4. Laravel 包结构冒烟
bash tests/laravel_package_smoke_test.sh
```

可选静态检查：

```bash
# 5. shellcheck（GitHub Ubuntu runner 自带，本地 macOS 可用 Docker）
docker run --rm -v "$PWD:/work" -w /work koalaman/shellcheck-alpine:v0.10.0 \
  shellcheck -S warning go-harness/setup.sh fullstack-harness/setup.sh \
    go-pkg-harness/setup.sh laravel-harness/setup.sh laravel-fullstack-harness/setup.sh \
    scripts/error-journal/*.sh scripts/sync-claude-from-agents.sh tests/*.sh
```

PowerShell 端门禁需要 Windows 环境或 Docker pwsh：

```bash
# 6. PSScriptAnalyzer（CI 用，本地可选）
docker run --rm -v "$PWD:/work" -w /work mcr.microsoft.com/powershell:7.4-ubuntu-22.04 \
  pwsh -NoProfile -Command "Install-Module PSScriptAnalyzer -Force -Scope CurrentUser -SkipPublisherCheck | Out-Null; \
    @('go-harness/setup.ps1','fullstack-harness/setup.ps1','go-pkg-harness/setup.ps1','laravel-harness/setup.ps1','laravel-fullstack-harness/setup.ps1', \
      'scripts/install-harness.ps1','scripts/error-journal/append-error-journal.ps1','scripts/error-journal/read-error-journal.ps1', \
      'tests/setup_windows_smoke_test.ps1','tests/error_journal_test.ps1') \
    | ForEach-Object { Invoke-ScriptAnalyzer -Path \$_ -Severity Warning,Error -ExcludeRule PSAvoidUsingWriteHost }"

# 7. Windows setup 冒烟测试
docker run --rm -v "$PWD:/work" -w /work mcr.microsoft.com/powershell:7.4-ubuntu-22.04 \
  pwsh -NoProfile -ExecutionPolicy Bypass -File tests/setup_windows_smoke_test.ps1

# 8. error-journal PS 脚本契约单测
docker run --rm -v "$PWD:/work" -w /work mcr.microsoft.com/powershell:7.4-ubuntu-22.04 \
  pwsh -NoProfile -ExecutionPolicy Bypass -File tests/error_journal_test.ps1
```

提交规范：见 [Git 提交建议](#git-提交建议)；CHANGELOG `[Unreleased]` 区段必须同步更新（见 `CHANGELOG.md`）。
