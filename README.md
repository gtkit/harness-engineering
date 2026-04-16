# Go Harness Engineering 工具包

> 让 AI 编码代理（Claude Code / OpenAI Codex）在严格约束下写出企业生产级代码。
>
> 基于 2026 年 Harness Engineering 理念：**同样的模型，不同的 Harness，产出质量天差地别。**

---

## 这是什么

三套针对不同场景的 AI 编码约束系统（Harness），安装后 AI 代理每次写代码都会自动遵守你定义的架构规范、编码标准和质量检查流程。

| 包名 | 适用场景 | 目录 |
|-----|---------|------|
| **go-harness** | 纯 Go 后端业务服务（Gin + GORM + gtkit） | `go-harness/` |
| **fullstack-harness** | Go 后端 + Vue 前端（同一项目目录） | `fullstack-harness/` |
| **go-pkg-harness** | Go 扩展包 / 第三方库开发 | `go-pkg-harness/` |

三套互相独立，按项目类型选用一套即可。

---

## 目录结构

```
harness-engineering/
├── README.md                ← 你正在读的文件
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
│       ├── pkg-design.md
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
│       ├── pkg-design.md
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
        ├── pkg-review.md
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

每个项目只需要运行一次。脚本会做两件事：

1. **全局 Skill** 安装到 `~/.claude/skills/` 和 `~/.codex/skills/`（只装一次，所有项目共享）
2. **项目文件** 安装到当前项目目录（每个项目各一份）

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
└── .harness/
    ├── error-journal.md       ← AI 犯错时自动追加记录
    └── guides/                ← 7 个规范文档
        ├── architecture.md         分层架构、依赖方向
        ├── api-conventions.md      统一响应格式、错误码
        ├── db-patterns.md          GORM、Repository、事务
        ├── llm-integration.md      大模型对接（SSE、重试降级）
        ├── payment.md              支付（幂等、验签、对账）
        ├── pkg-design.md           扩展包设计
        └── review-checklist.md     12 维度审查清单
```

---

#### 场景 B：Go + Vue 全栈项目（前后端同目录）

适用于后端 Go + 前端 Vue 3 + Vite + TypeScript 放在同一个仓库的项目。

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
└── .harness/
    ├── error-journal.md
    └── guides/                ← 10 个规范文档（后端 7 + 前端 3）
        ├── architecture.md         后端分层架构
        ├── api-conventions.md      后端 API 规范
        ├── db-patterns.md          后端数据库规范
        ├── llm-integration.md      后端大模型对接
        ├── payment.md              后端支付模块
        ├── pkg-design.md           后端扩展包设计
        ├── frontend-architecture.md 前端目录结构、分层规则
        ├── frontend-api.md          前端 Axios 封装、类型对齐
        ├── frontend-coding.md       前端 TS 严格模式、组件规范
        └── review-checklist.md      全栈 16 维度审查清单
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
└── .harness/
    ├── error-journal.md
    └── guides/                ← 6 个规范文档
        ├── pkg-structure.md        包结构、接口、Functional Options
        ├── pkg-errors.md           三层错误体系
        ├── pkg-testing.md          测试、Benchmark、Example、Fuzz
        ├── pkg-docs.md             GoDoc、README、CHANGELOG
        ├── pkg-generics.md         泛型应用
        └── pkg-review.md           包级 9 维度审查清单
```

---

## 安装后的全局 Skill 一览

三套脚本各自安装到不同目录，互不覆盖：

```
~/.claude/skills/
├── go-harness/              ← 场景 A
│   └── SKILL.md
├── fullstack-harness/       ← 场景 B
│   └── SKILL.md
└── go-pkg-harness/          ← 场景 C
    └── SKILL.md

~/.codex/skills/
├── go-harness/              ← 场景 A
│   └── SKILL.md
├── fullstack-harness/       ← 场景 B
│   └── SKILL.md
└── go-pkg-harness/          ← 场景 C
    └── SKILL.md
```

全局 Skill 只是触发入口（告诉 AI "去读项目里的规范"），实际规范内容在每个项目的 `.harness/guides/` 下。

---

## 工作原理

### 为什么 AI 每次都会遵守规则

```
Claude Code 启动 → 自动读取项目 CLAUDE.md → 触发 go-xxx-harness skill → 读取 .harness/guides/
Codex 启动      → 自动读取项目 AGENTS.md  → 读取 .harness/guides/
```

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
你纠正 AI → AI 修正代码 → 自动追加到 .harness/error-journal.md
                                    ↓
                            下次任务开始时读取
                                    ↓
                            主动规避同类错误
```

AI 犯过的错误会被记录下来，形成项目专属的"经验库"，越用越准。

---

## 三套 Harness 的核心差异

| | go-harness | fullstack-harness | go-pkg-harness |
|--|-----------|-------------------|---------------|
| **定位** | 后端业务服务 | Go + Vue 全栈 | 扩展包/第三方库 |
| **分层** | handler → service → repo | 后端同左 + 前端 views → composables → api | 无分层，按功能文件拆分 |
| **依赖** | Gin、GORM、Redis 等 | 后端同左 + Vue、Vite、Pinia | 零依赖优先，第三方优先 gtkit |
| **JSON** | encoding/json 或 gtkit/json | 同左 | **必须 gtkit/json，禁止 encoding/json** |
| **错误** | AppError + HTTP 状态码 | 后端同左 + 前端 ApiError 类 | sentinel + 自定义类型 + wrapping |
| **配置** | 环境变量/config | 后端同左 + 前端 VITE_ 环境变量 | Functional Options |
| **测试** | 单元测试 ≥ 80% | 后端同左 + 前端 vue-tsc + Vitest | 单元 + Example + Benchmark + Fuzz |
| **文档** | 代码注释 | 同左 | GoDoc 全覆盖 + README + CHANGELOG |
| **版本** | 业务版本号 | 同左 | 语义化版本（semver） |
| **前端** | 无 | Vue 3 + TS strict + 禁止 any | 无 |
| **Guides 数量** | 7 个 | 10 个 | 6 个 |
| **审查维度** | 12 维度 | 16 维度 | 9 维度 |

---

## 日常使用

### 安装完就不用管了

脚本只需运行一次。之后正常用 Claude Code 或 Codex 写代码，AI 会自动遵守所有规则。

### 修改规范

只改项目里的 `.harness/guides/` 下的文件。比如你想加一条新的 GORM 规则：

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

### 在新项目中使用

```bash
cd ~/code/new-project
bash ~/tools/harness-engineering/go-harness/setup.sh   # 选对应的类型
```

全局 Skill 已经装过了不会重复，只会安装项目级文件。

---

## Git 提交建议

以下文件**建议提交到 Git**（团队共享规范）：

```
CLAUDE.md
AGENTS.md
.harness/guides/*.md
```

以下文件**不要提交**（本地开发用）：

```
.harness/error-journal.md   # 已自动添加到 .gitignore
```

---

## 常见问题

**Q：一个项目能同时装两套 Harness 吗？**

不建议。每个项目选一套最匹配的。如果你的项目是全栈的，用 fullstack-harness，它已经包含了 go-harness 的所有后端规范。

**Q：我用的不是 Claude Code 也不是 Codex，能用吗？**

可以。`.harness/guides/` 下的规范文档是通用的 Markdown，任何 AI 代理（Cursor、Windsurf 等）都可以读。你只需要在对应工具的配置文件里指向这些文件即可。`AGENTS.md` 本身也是一个跨 Agent 的开放标准。

**Q：全局 Skill 装错了怎么删？**

```bash
rm -rf ~/.claude/skills/go-harness          # 删 Claude Code 的
rm -rf ~/.codex/skills/go-harness           # 删 Codex 的
```

**Q：guides 改错了想恢复怎么办？**

重新跑一次 setup.sh，`.harness/guides/` 会被覆盖为初始版本。`CLAUDE.md`、`AGENTS.md`、`error-journal.md` 不会被覆盖（脚本检测到已存在会跳过）。

**Q：setup.sh 在 macOS 上能跑吗？**

能。脚本兼容 macOS 自带的 bash 3.2 和 zsh，没有用任何 Linux 专有语法。
