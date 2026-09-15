# Harness Engineering 工具包

> 让 AI 编码代理（Claude Code / OpenAI Codex）在严格约束下写出企业生产级代码。
>
> 基于 2026 年 Harness Engineering 理念：**同样的模型，不同的 Harness，产出质量天差地别。**

---

## 这是什么

六套针对不同场景的 AI 编码约束系统（Harness），安装后 AI 代理每次写代码都会自动遵守你定义的架构规范、编码标准和质量检查流程。

| 包名 | 适用场景 | 目录 |
|-----|---------|------|
| **go-harness** | 纯 Go 后端业务服务（Gin + GORM + gtkit） | `go-harness/` |
| **go-grpc-harness** | 纯 Go gRPC 微服务（grpc-go + buf + protovalidate + ormx + gtkit） | `go-grpc-harness/` |
| **fullstack-harness** | Go 后端 + Vue 前端（同一项目目录） | `fullstack-harness/` |
| **go-pkg-harness** | Go 扩展包 / 第三方库开发 | `go-pkg-harness/` |
| **laravel-harness** | 纯 Laravel 项目（API / Web，默认纳入 Queue / Scheduler / Event / Notification） | `laravel-harness/` |
| **laravel-fullstack-harness** | Laravel 后端 + Vue 前端（`backend/` + `frontend/` 同仓库） | `laravel-fullstack-harness/` |

六套互相独立，按项目类型选用一套即可。

安装后还会在项目内装一组可选的工作流 skills，Claude Code 与 Codex 读的是同一份 `SKILL.md`。普通小改动可以不用；复杂、高风险、跨模块任务可以用它把工作拆成可恢复的 Research → Plan → Implementation 流程：

| Claude Code | Codex | 功能 |
|-----|-----|------|
| `/harness-doctor` | `$harness-doctor` | 检查 harness、OpenSpec、skills 和可选 MCP 工具状态 |
| `/harness-init-openspec` | `$harness-init-openspec` | 初始化或验证 OpenSpec（优先走 `openspec-auto`） |
| `/harness-research` | `$harness-research` | 将需求转成约束集和可验证成功标准 |
| `/harness-plan` | `$harness-plan` | 生成零决策执行计划和 PBT / 不变量检查点 |
| `/harness-implement` | `$harness-implement` | 按批准计划分阶段实现并验证 |
| `/harness-review` | `$harness-review` | 按 harness 质量门禁审查当前变更 |

---

## 目录结构

```
harness-engineering/
├── README.md                ← 你正在读的文件
├── install.sh               ← 往 ~/go/bin 写包装命令：六个 harness 名 + harness-refresh
├── scripts/
│   ├── harness-init.sh      ← harness 命令的实际逻辑：git init → setup.sh → openspec-auto install
│   ├── harness-refresh.sh   ← 批量查看 / 刷新清单里所有项目
│   ├── hooks/session_start.py ← SessionStart hook：注入未关闭的错误记忆与模板落后提示
│   ├── install-harness.sh   ← 六套 setup.sh 共用的安装逻辑
│   └── error-journal/       ← 装进项目 .harness/scripts/ 的错误记忆读写脚本
├── shared/guides/           ← 多套 harness 共用的 guide 唯一真源
│   ├── common/              ← 全部 harness 共用：commit-and-changelog.md
│   ├── go/                  ← go-harness / go-grpc-harness / fullstack-harness 共用 9 篇
│   └── laravel/             ← laravel-harness / laravel-fullstack-harness 共用 7 篇
├── skills/                  ← 六个工作流 skill（Claude Code 与 Codex 同一份）
│   ├── harness-doctor/SKILL.md
│   ├── harness-init-openspec/SKILL.md
│   ├── harness-research/SKILL.md
│   ├── harness-plan/SKILL.md
│   ├── harness-implement/SKILL.md
│   └── harness-review/SKILL.md
│
├── go-harness/              ← 纯 Go 后端业务服务
│   ├── setup.sh
│   ├── CLAUDE.md
│   ├── AGENTS.md
│   ├── shared-guides.txt    ← 从 shared/guides/ 拉哪些公共 guide；guides/ 里同名文件优先
│   ├── rules/               ← Claude Code 路径限定规则：读到匹配文件时把对应 guide 拉进上下文
│   └── guides/              ← 本 harness 独有的 guide（下面列的是装进项目后的完整清单）
│       ├── go-modern.md
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
├── go-grpc-harness/         ← 纯 Go gRPC 微服务
│   ├── setup.sh             ← 只装规则（存量项目）
│   ├── scaffold.sh          ← 从模板生成新项目骨架（新项目）
│   ├── CLAUDE.md
│   ├── AGENTS.md
│   ├── templates/
│   │   └── grpc-service/    ← 可运行的 gRPC 服务骨架
│   └── guides/
│       ├── go-modern.md
│       ├── architecture.md
│       ├── grpc-conventions.md
│       ├── db-patterns.md
│       ├── migration.md
│       ├── llm-integration.md
│       ├── payment.md
│       ├── workers-and-scheduling.md
│       ├── worker-and-cache.md
│       ├── observability.md
│       ├── internal-pkg.md
│       ├── pkg-design.md
│       ├── ci-sensors.md
│       ├── testing-and-validation.md
│       ├── review-checklist.md
│       └── error-journal-template.md
│
├── fullstack-harness/       ← Go + Vue 全栈项目
│   ├── setup.sh
│   ├── CLAUDE.md
│   ├── AGENTS.md
│   ├── rules/
│   └── guides/
│       ├── go-modern.md
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
├── go-pkg-harness/          ← Go 扩展包 / 第三方库
│   ├── setup.sh
│   ├── CLAUDE.md
│   ├── AGENTS.md
│   ├── rules/
│   └── guides/
│       ├── go-modern.md
│       ├── pkg-structure.md
│       ├── pkg-errors.md
│       ├── pkg-testing.md
│       ├── pkg-docs.md
│       ├── pkg-generics.md
│       ├── pkg-release-and-supply-chain.md
│       ├── pkg-review.md
│       └── error-journal-template.md
│
├── laravel-harness/         ← 纯 Laravel 项目
│   ├── setup.sh
│   ├── CLAUDE.md
│   ├── AGENTS.md
│   ├── rules/
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
    ├── CLAUDE.md
    ├── AGENTS.md
    ├── rules/
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

- macOS 或 Linux；Windows 用 Git Bash / WSL（见文末）
- 已安装 Claude Code（`~/.claude/` 目录存在）和/或 OpenAI Codex（`~/.codex/` 目录存在）
- Bash（macOS 自带的 bash 3.2+ 或 zsh 均可）
- 接 OpenSpec 工作流需要 [openspec-auto](https://github.com/gtkit/openspec-auto-bootstrap)：clone 到本仓库同级目录即可，或装到 PATH

---

## 安装步骤

### 第一步：把六个命令装到 PATH

把仓库放到固定位置后，在仓库根目录执行一次：

```bash
bash install.sh                          # 装到 ~/go/bin
HARNESS_BIN_DIR=~/.local/bin bash install.sh   # 换目录
```

目标目录下会多出 `go-harness`、`go-grpc-harness`、`fullstack-harness`、`go-pkg-harness`、`laravel-harness`、`laravel-fullstack-harness` 六个命令。它们是几行长的包装脚本，直接 `exec` 本仓库的 `scripts/harness-init.sh`：改了仓库里的 guides / 规则 / 安装脚本立即生效，不需要重装；仓库换了位置重跑一次 `install.sh` 即可。除 bash 外没有别的依赖。

不装命令也可以直接跑各目录下的 `setup.sh`，效果与命令加 `--no-openspec` 一致：

```bash
bash ~/tools/harness-engineering/go-harness/setup.sh
```

---

### 第二步：在项目目录里敲命令名

每个项目只需要运行一次。缺省目标是当前目录，也可以显式传目录（不存在则创建）：

```bash
cd ~/code/your-backend-project
go-harness                          # 装 go-harness 规则 + openspec-auto 工作流
go-harness ~/code/new-project       # 指定目录
go-harness --no-openspec            # 只装 harness
go-harness --force                  # 强制刷新 CLAUDE.md / AGENTS.md / skills / rules / guides，并给 openspec-auto 传 --force
go-harness --force-guides           # 只强刷 guides；--force-project-files 只强刷入口文件 / skills / rules / 运行脚本
go-harness -- --skip-codex-user-config   # -- 之后的参数原样传给 openspec-auto install
go-harness --version                # 打印本仓库当前 commit / tag
```

命令会做五件事：

1. 目标目录不是 git 仓库就 `git init`（忽略规则要写进 `.git/info/exclude`）
2. 清理旧版本装过的全局 skill（`~/.claude/skills/<harness>/`、`~/.agents/skills/<harness>/`、`~/.codex/skills/<harness>/`）：入口文件本来就自动加载，那个只说"去读 CLAUDE.md"的全局 skill 只在每个项目的 skill 列表里占位，现已不再安装
3. **项目文件** 安装到项目目录：`CLAUDE.md`、`AGENTS.md`、`.harness/`（guides、error-journal、运行脚本、SessionStart hook）、六个工作流 skill（`.claude/skills/harness-*/` 与 `.agents/skills/harness-*/`）、Claude Code 的路径限定规则 `.claude/rules/harness-*.md`
4. **忽略规则** 自动创建/补齐：通用产物（`.idea/`、`.vscode/`、`.DS_Store`、`*.log`、`*.out`，以及应用型 harness 的 `.env`）写进 `.gitignore`；本地工具与 Agent 运行产物（整个 `.harness/`、`CLAUDE.md`、`AGENTS.md`、`.claude/`、`.codex/`、`.agents/`、`openspec/`、`.openspec-auto/`、计划文件等）写进 `.git/info/exclude`（仅本地、不进版本库，避免忽略规则本身泄露 AI 工具链）
5. 运行 `openspec-auto install`，接入自动 OpenSpec 工作流（hooks、skill、`CLAUDE.md` / `AGENTS.md` 里的托管块）

### 为什么顺序固定为 harness 先、openspec-auto 后

两个安装器都要写 `CLAUDE.md` 和 `AGENTS.md`，但写法不同：harness 是**整文件写入**（模板就是完整的项目规则），openspec-auto 是**往文件末尾追加一段托管块**（`<!-- OPENSPEC-AUTO:START -->` … `<!-- OPENSPEC-AUTO:END -->`）。

- 先 harness 再 openspec-auto：harness 写出完整规则，openspec-auto 把托管块追加进去，两份内容都在。
- 反过来先 openspec-auto：`CLAUDE.md` / `AGENTS.md` 已经存在且只有托管块，harness 默认不覆盖已存在的入口文件，会判定为"与模板不同、保留未动"并跳过，项目就只剩 OpenSpec 规则而没有 harness 规则；只有加 `--force` 强刷才能补回来。

harness 这一侧已经做了配合：日常重跑比对入口文件是否为本版本时会忽略托管块，`--force` 刷新时先写模板再把托管块原样追加回去；入口文件里只剩托管块、没有任何 harness 规则时（先装 openspec-auto 的老项目就是这样），普通 setup 会直接补齐规则并保留块，不再按"用户定制"跳过。所以装好之后以任意顺序重复执行任意一个安装器都不会互相破坏。

### openspec-auto 从哪里来、怎么保持最新

命令按下面的顺序找 `openspec-auto`，找到第一个就用，并在输出里打印用的是哪一个：

1. `$OPENSPEC_AUTO_BIN` 指定的可执行文件
2. openspec-auto-bootstrap 的仓库目录：`$OPENSPEC_AUTO_BOOTSTRAP_DIR`，缺省为本仓库同级的 `../openspec-auto-bootstrap`，直接调用它的 `install.sh`
3. PATH 上的 `openspec-auto`（通常在 `~/go/bin`，由它仓库里的 `install-cli.sh` 生成，同样是指向仓库的包装脚本）

openspec-auto 与本仓库一样是纯 sh 实现，三条路都是直接运行仓库里的脚本：它的模板或脚本更新后不需要重装，下次运行就是新版。三处都没有时 harness 部分已经装好，命令以非零退出并提示 clone 地址（或加 `--no-openspec`）。

其中：

- Claude Code 自动加载项目根目录 `CLAUDE.md`，Codex 自动加载 `AGENTS.md`，两份内容同级完整，不需要任何全局 skill 做入口
- 详细专项规范统一放在 `.harness/guides/`
- 工作流 skills 双端各一份：Claude Code 读 `.claude/skills/harness-*/`，Codex 读 `.agents/skills/harness-*/`，内容相同
- `.claude/rules/harness-*.md` 是 Claude Code 的路径限定规则：只在 Claude 读到匹配路径的文件时，把对应 guide 拉进上下文；Codex 没有对应机制，仍按 `AGENTS.md` 的 Guide 加载表读 guide

下面按场景说明各 harness 装出的文件；命令名换成对应 harness 即可，`bash …/setup.sh` 是只装 harness 的等价写法。Windows 在 Git Bash / WSL 里用法相同，见文末。

---

#### 场景 A：纯 Go 后端业务服务

适用于用 Gin + GORM + gtkit 开发的 Web 服务、API 服务。

```bash
# 进入你的 Go 项目根目录
cd ~/code/your-backend-project

# 装规则并接 openspec-auto；只装规则用 bash ~/tools/harness-engineering/go-harness/setup.sh
go-harness
```

安装完成后你的项目会多出：

```
your-backend-project/
├── CLAUDE.md                  ← Claude Code 每次对话自动读取
├── AGENTS.md                  ← Codex 每次任务自动读取
├── .claude/
│   ├── skills/harness-*/      ← /harness-doctor 等六个工作流 skill
│   └── rules/harness-*.md     ← 路径限定规则，读到匹配文件时拉进对应 guide
├── .agents/
│   └── skills/harness-*/      ← Codex 读的同一份六个 skill（$harness-doctor）
└── .harness/
    ├── error-journal.md       ← AI 错误记忆文件
    ├── guides/                ← 16 个规范文档
    │   ├── go-modern.md            Go 1.27 现代语法、泛型方法、UUID
    │   ├── architecture.md         分层架构、依赖方向
    │   ├── api-conventions.md      统一响应格式、错误码
    │   ├── db-patterns.md          GORM、Repository、事务、UUID 主键
    │   ├── migration.md            数据库迁移
    │   ├── llm-integration.md      大模型对接（SSE、重试降级）
    │   ├── payment.md              支付（幂等、验签、对账）
    │   ├── workers-and-scheduling.md Worker、队列、定时任务
    │   ├── worker-and-cache.md     cache / Redis / PubSub / 延迟队列
    │   ├── observability.md        日志、指标、链路
    │   ├── internal-pkg.md         internal/pkg 边界
    │   ├── pkg-design.md           扩展包设计
    │   ├── ci-sensors.md           CI 与架构传感器
    │   ├── testing-and-validation.md 测试、回归、验证
    │   ├── review-checklist.md     12 维度审查清单
    │   └── commit-and-changelog.md 写 commit / 改 CHANGELOG / 发版时读
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

# 装规则并接 openspec-auto；只装规则用 bash ~/tools/harness-engineering/fullstack-harness/setup.sh
fullstack-harness
```

安装完成后你的项目会多出：

```
your-fullstack-project/
├── CLAUDE.md
├── AGENTS.md
├── .claude/
│   ├── skills/harness-*/
│   └── rules/harness-*.md
├── .agents/
│   └── skills/harness-*/
└── .harness/
    ├── error-journal.md
    ├── guides/                ← 19 个规范文档（后端 15 + 前端 3 + 通用 1）
    │   ├── go-modern.md
    │   ├── architecture.md
    │   ├── api-conventions.md
    │   ├── db-patterns.md
    │   ├── migration.md
    │   ├── llm-integration.md
    │   ├── payment.md
    │   ├── workers-and-scheduling.md
    │   ├── worker-and-cache.md
    │   ├── observability.md
    │   ├── internal-pkg.md
    │   ├── pkg-design.md
    │   ├── ci-sensors.md
    │   ├── testing-and-validation.md
    │   ├── frontend-architecture.md
    │   ├── frontend-api.md
    │   ├── frontend-coding.md
    │   ├── review-checklist.md
    │   └── commit-and-changelog.md
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

# 装规则并接 openspec-auto；只装规则用 bash ~/tools/harness-engineering/go-pkg-harness/setup.sh
go-pkg-harness
```

安装完成后你的项目会多出：

```
your-go-package/
├── CLAUDE.md
├── AGENTS.md
├── Makefile                  ← lint / govulncheck / release-patch·release-minor 两步发版
├── version.go                ← const Version = "v0.1.0"
├── .claude/
│   ├── skills/harness-*/
│   └── rules/harness-*.md
├── .agents/
│   └── skills/harness-*/
└── .harness/
    ├── error-journal.md
    └── guides/                ← 9 个规范文档
        ├── go-modern.md            Go 1.27 现代语法、UUID
        ├── pkg-structure.md        包结构、接口、Functional Options
        ├── pkg-errors.md           三层错误体系
        ├── pkg-testing.md          测试、Benchmark、Example、Fuzz
        ├── pkg-docs.md             GoDoc、README、CHANGELOG
        ├── pkg-generics.md         泛型应用、泛型方法
        ├── pkg-api-compat.md       API 兼容性、导出面、SemVer 影响
        ├── pkg-release-and-supply-chain.md 发布、依赖、供应链安全
        └── pkg-review.md           包级 9 维度审查清单
```

`version.go` 的 package 名优先沿用目录内既有 `.go` 文件声明的 package 名（同目录 package 名必须一致，否则编译失败）；目录里没有其它 Go 文件时按目录名推导，横线直接去掉：

| 项目目录 | 生成的 package 名 |
|--|--|
| `~/go/src/my-gtkit-package/lenovo-pay` | `package lenovopay` |
| `~/code/cachex` | `package cachex` |

横线是去掉而不是换成下划线——Go 包名不用下划线，`lenovo_pay` 会被 staticcheck 判为 `should not use underscores in package names`（ST1003）。目录名转换后仍不是合法 Go 标识符（如以数字开头）或撞上 Go 关键字时，跳过 `version.go` 并打印提示，其余文件照常安装。`Makefile` 与 `version.go` 已存在则默认不覆盖，`HARNESS_FORCE_PROJECT_FILES=1` 可强制刷新。

`Makefile` 的发版分两步。`make release-patch` / `make release-minor` 先跑完整门禁（工作区干净、空白检查、`go mod tidy -diff`、`go vet`、`golangci-lint`、`gofumpt` 只读检查、race 测试、覆盖率、benchmark、`govulncheck`、`gosec`），通过后自增 `version.go` 的 `Version`、提交、打附注标签并推主干，**标签留在本地**；远端 CI 全绿后再 `make push-tag` 发布标签，它会核对该 commit 的 check-runs 结论，未全绿拒绝推送。分两步的原因是 Go module proxy 抓取标签后永久缓存，删除或覆盖都收不回来。门禁阈值可按包覆盖：`COVERAGE_MIN`、`REQUIRE_CHANGELOG`、`RELEASE_REMOTE`、`EXTRA_TEST_TARGET`。

---

#### 场景 D：纯 Laravel 项目

适用于纯 Laravel 项目，兼容 API / Web 两类形态，并默认把 Queue、Scheduler、Event、Notification 纳入强约束。若项目使用 `nwidart/laravel-modules`，模板也支持 `Modules/` 结构。

```bash
# 进入你的 Laravel 项目根目录
cd ~/code/your-laravel-project

# 装规则并接 openspec-auto；只装规则用 bash ~/tools/harness-engineering/laravel-harness/setup.sh
laravel-harness
```

安装完成后你的项目会多出：

```text
your-laravel-project/
├── CLAUDE.md
├── AGENTS.md
├── .claude/
│   ├── skills/harness-*/
│   └── rules/harness-*.md
├── .agents/
│   └── skills/harness-*/
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
        ├── review-checklist.md
        └── commit-and-changelog.md
```

---

#### 场景 E：Laravel + Vue 全栈项目（`backend/` + `frontend/` 同仓库）

适用于 Laravel 后端在 `backend/`、Vue 3 + Vite + TypeScript 前端在 `frontend/` 的同仓库项目。

```bash
# 进入你的 Laravel 全栈项目根目录
cd ~/code/your-laravel-fullstack-project

# 装规则并接 openspec-auto；只装规则用 bash ~/tools/harness-engineering/laravel-fullstack-harness/setup.sh
laravel-fullstack-harness
```

安装完成后你的项目会多出：

```text
your-laravel-fullstack-project/
├── CLAUDE.md
├── AGENTS.md
├── .claude/
│   ├── skills/harness-*/
│   └── rules/harness-*.md
├── .agents/
│   └── skills/harness-*/
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
        ├── review-checklist.md
        └── commit-and-changelog.md
```

---

#### 场景 F：纯 Go gRPC 微服务

适用于用 grpc-go + buf + protovalidate + ormx + gtkit 开发的 gRPC 微服务。

存量项目只装规则：

```bash
# 进入你的 gRPC 项目根目录
cd ~/code/your-grpc-service

# 装规则并接 openspec-auto；只装规则用 bash ~/tools/harness-engineering/go-grpc-harness/setup.sh
go-grpc-harness
```

新项目可以先用脚手架生成骨架，它在末尾会自动调 `setup.sh` 把规则一起装好，骨架与规则同版本交付：

```bash
bash ~/tools/harness-engineering/go-grpc-harness/scaffold.sh my-order-service ~/code/my-order-service
```

脚手架只对新项目生效：目标目录出现 `go.mod` / `cmd` / `internal` 任一即拒绝，任何目标文件已存在即中止。

安装完成后你的项目会多出：

```text
your-grpc-service/
├── CLAUDE.md                  ← Claude Code 每次对话自动读取
├── AGENTS.md                  ← Codex 每次任务自动读取
├── .claude/
│   ├── skills/harness-*/      ← /harness-doctor 等六个工作流 skill
│   └── rules/harness-*.md     ← 路径限定规则，读到匹配文件时拉进对应 guide
├── .agents/
│   └── skills/harness-*/      ← Codex 读的同一份六个 skill（$harness-doctor）
└── .harness/
    ├── error-journal.md       ← AI 错误记忆文件
    ├── guides/                ← 16 个规范文档
    │   ├── go-modern.md            Go 1.27 现代语法、泛型方法、UUID
    │   ├── architecture.md         分层架构、依赖方向
    │   ├── grpc-conventions.md     proto / buf / 契约与拦截器
    │   ├── db-patterns.md          GORM、Repository、事务、UUID 主键
    │   ├── migration.md            数据库迁移
    │   ├── llm-integration.md      大模型对接（流式、重试降级）
    │   ├── payment.md              支付（幂等、验签、对账）
    │   ├── workers-and-scheduling.md Worker、队列、定时任务
    │   ├── worker-and-cache.md     cache / Redis / PubSub / 延迟队列
    │   ├── observability.md        日志、指标、链路
    │   ├── internal-pkg.md         internal/pkg 边界
    │   ├── pkg-design.md           扩展包设计
    │   ├── ci-sensors.md           CI 与架构传感器
    │   ├── testing-and-validation.md 测试、回归、验证
    │   ├── review-checklist.md     审查清单
    │   └── commit-and-changelog.md 写 commit / 改 CHANGELOG / 发版时读
    └── scripts/               ← error-journal 读写脚本
        ├── read-error-journal.sh
        ├── append-error-journal.sh
        ├── read-error-journal.ps1
        └── append-error-journal.ps1
```

---

## 可选命令化 RPI 工作流

这不是强制流程引擎，而是六个轻量 skill。普通小改动可以直接让 AI 按 harness 规则完成；复杂、高风险、跨模块需求建议走命令化流程，让上下文只专注一件事。

速查表和典型场景示例见 [Harness Command Workflow 速查](./docs/harness-command-workflow.md)。

想搞清楚 harness 与 Loop 架构（自动化调度 / worktree 隔离 / Skill / MCP / 子 Agent / 记忆）的能力边界——哪些归 harness、哪些归运行时——见 [harness 与 Loop 架构的关系](./docs/harness-and-loop-architecture.md)。

### Claude Code 怎么用

Claude Code 读项目里的 `.claude/skills/harness-*/SKILL.md`，目录名就是命令名：

```text
/harness-doctor
```

```text
/harness-research
你的需求描述...
```

```text
/harness-plan
```

```text
/harness-implement
```

```text
/harness-review
```

### Codex 怎么用

Codex 读项目里的 `.agents/skills/harness-*/SKILL.md`，与 Claude Code 是同一份文件。显式调用用 `$` 前缀，或输入 `/skills` 从列表里选：

```text
$harness-doctor
```

```text
$harness-research 你的需求描述...
```

```text
$harness-plan
```

```text
$harness-implement
```

```text
$harness-review
```

### 命令说明

### 1. 诊断环境

```text
/harness-doctor
```

检查项目是否已安装 harness、OpenSpec 与 openspec-auto 是否可用、`.claude/skills/harness-*/` 与 `.agents/skills/harness-*/` 是否齐全，以及可选 MCP 工具是否可用。

### 2. 初始化 OpenSpec（可选）

```text
/harness-init-openspec
```

用于需要 proposal / spec / task 管理的复杂需求。命令优先复用 `openspec-auto`：已装（`.openspec-auto/version` 存在）只跑体检；未装优先 `openspec-auto install .`，它不可用时才回退到 `openspec init --tools claude`。不会静默安装全局工具，也不会覆盖现有 OpenSpec 文件。

### 3. Research：需求转约束集

```text
/harness-research
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

### 4. Plan：生成零决策计划

```text
/harness-plan
```

把已批准的约束集变成实现阶段可机械执行的计划，包含：

- files to change
- sequential tasks
- verification per task
- rollback / migration notes
- PBT / invariant / boundary condition / falsification strategy

计划未获批准前不进入实现。

### 5. Implement：分阶段实现

```text
/harness-implement
```

按批准计划选择最小可验证任务执行。每完成一个阶段都要跑对应验证；如果上下文变大，会停在 checkpoint，给出下一次恢复方式。

### 6. Review：交付前审查

```text
/harness-review
```

按 `.harness/guides/review-checklist.md` 或包级 review guide 检查当前 diff，覆盖 correctness、安全、性能、分层、代码质量门禁、可观测性、兼容性与迁移、测试缺口。

Codex 侧把 `/` 换成 `$` 即可，六个 skill 一一对应。

---

## 工作原理

### 为什么 AI 每次都会遵守规则

```
Claude Code 启动 → 自动加载项目 CLAUDE.md → SessionStart hook 注入未关闭的错误记忆 → 按任务读 .harness/guides/（.claude/rules 按路径自动拉取）
Codex 启动      → 自动加载项目 AGENTS.md  → SessionStart hook 注入未关闭的错误记忆 → 按 Guide 加载表读 .harness/guides/
```

`CLAUDE.md` 和 `AGENTS.md` 是各自 Agent 的**无条件自动加载文件**——不需要关键词匹配，不需要手动指定，每次对话/任务都会读取。入口文件只放每次都要用的规则；专项规范放 `.harness/guides/`，按"做什么时读哪份"的表按需加载，不做"每次先读完全部文档"。

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

AI 犯过的错误会被记录下来，形成项目专属的"经验库"。追加靠 agent 按项目规则调用脚本；**读取不再只靠模型自觉**：setup 会把 `.harness/hooks/session_start.py` 注册进 `.claude/settings.json` 与 `.codex/hooks.json` 的 SessionStart 事件，每次会话开始时自动把 `Status: open` 的条目摘要注入上下文（最多 10 条），同时对比 `.harness/VERSION` 里记录的模板 commit 与模板仓库当前 HEAD，落后就提示运行 `<harness> --force-guides`。两条都没有可说的时 hook 不输出任何内容。hook 由 Claude Code 与 Codex 共用同一份脚本，按 `python3` → `python` 探测解释器；本机没有 Python 时 setup 跳过注册并提示。

---

## 六套 Harness 的核心差异

| 包名 | 定位 | 默认结构 | 关键约束 |
|--|--|--|--|
| `go-harness` | Go 后端业务服务 | 单仓后端 | Gin + GORM + gtkit、分层、支付/LLM/DB 规范 |
| `go-grpc-harness` | Go gRPC 微服务 | 单仓后端 + `proto/` / `pb/` | grpc-go + buf + protovalidate、pb 产物一致性门禁、可选脚手架 |
| `fullstack-harness` | Go + Vue 全栈 | `backend/` + `frontend/` | Go 后端分层 + Vue 3 + TS strict + 契约同步 |
| `go-pkg-harness` | Go 扩展包 / 第三方库 | 单包 / 多包库 | GoDoc、Benchmark、Example、语义化版本 |
| `laravel-harness` | Laravel 项目 | 单仓 Laravel | HTTP、Eloquent、Queue、Scheduler、Event、Notification、可选 `Modules/` |
| `laravel-fullstack-harness` | Laravel + Vue 全栈 | `backend/` + `frontend/` | Laravel API 契约 + Vue 3 + TS strict + 可选 `Modules/` |

---

## 日常使用

### 安装完就不用管了

脚本只需运行一次。之后正常用 Claude Code 或 Codex 写代码，AI 会自动遵守所有规则。重复执行默认只补齐缺失文件，不覆盖你已经修改过的 guide。

### 修改规范

harness 只写**项目约定**（gtkit 技术栈、分层与依赖方向、DTO 与错误码、支付与迁移流程、门禁命令、错误记忆）；**通用工程知识**（现代 Go 写法、并发、数据库、缓存、MQ、稳定性、安全、测试、性能）归 [skills 仓库](../skills) 的对应 skill，每套 Go guide 开头的归属行写明指向哪个 skill，`go-modern.md` 已收成指向 `use-modern-go` 的一页。同一主题只在一处写全，避免两边各自漂移。

规则分三层：

- 通用项目入口：`CLAUDE.md` / `AGENTS.md`
- 专项规范：`.harness/guides/`
- 错误记忆运行时：`.harness/scripts/`、`.harness/hooks/`

在模板仓库里改 guide 时先看它的来源：多套 harness 共用的放在 `shared/guides/go/`、`shared/guides/laravel/`，各 harness 的 `shared-guides.txt` 声明拉取哪些；只属于某一套的放在该套自己的 `guides/`，同名时以自己的为准。改一条 GORM 规则只需改 `shared/guides/go/db-patterns.md`，go-harness、go-grpc-harness、fullstack-harness 下次安装同时生效。

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

也可以直接调用追加脚本生成新条目骨架，处置完后关闭：

```bash
bash .harness/scripts/append-error-journal.sh . user-correction auth "用户纠正了入口文件边界"
bash .harness/scripts/close-error-journal.sh . ERR-20260915-001 "已在 architecture.md 补规则"
```

只有 `Status: open` 的条目会被 SessionStart hook 在每次会话开始时注入，关闭后不再出现。

### 批量查看 / 刷新多个项目

把常用项目登记进清单后，一条命令看所有项目是否落后、入口文件是否被本地改过：

```bash
harness-refresh add ~/code/proj-a ~/code/proj-b   # 清单在 ~/.config/harness-engineering/projects.txt，可用 HARNESS_PROJECTS_FILE 换位置
harness-refresh                                   # 只读报告：harness 名、已装 commit、是否落后、CLAUDE.md / AGENTS.md 是否与模板不同
harness-refresh apply                             # 对落后的项目逐个执行 <harness> <dir> --force（含 openspec-auto --force）
harness-refresh apply --all --no-openspec         # 全部刷新、只刷 harness
harness-refresh apply --no-force                  # 不强刷：只补缺失文件、修复只剩托管块的入口文件，本地改动一律保留
```

`apply` 每次覆盖前先把该项目的 `CLAUDE.md`、`AGENTS.md`、`.harness/guides/` 备份到 `~/.config/harness-engineering/backups/<UTC 时间戳>/<项目名>/`，因为这些文件在 `.git/info/exclude` 里不入库，覆盖后没有别处可找回。默认等价于进每个目录跑 `<harness> --force`：openspec-auto 的托管块保留，其余本地改动被模板覆盖；先看报告再决定用不用 `--no-force`。

### 查看 harness 版本

每次跑 `setup.sh` / `setup.ps1` 都会在项目下写入 `.harness/VERSION`，记录这次安装的 harness 包名、源仓库 commit、安装时间：

```bash
cat .harness/VERSION
# harness: go-harness
# source-path: /Users/you/Ai/harness-engineering
# source-commit: a3f4b9c2e8d1
# source-tag: v1.10.0
# installed-at: 2026-05-14T17:30:42+0800
# installer: setup.sh
```

`source-path` 是安装时模板仓库的位置，SessionStart hook 与 `harness-refresh` 用它对比当前 HEAD 判断是否落后。

排查"为什么我和同事的 `.harness/guides/` 不一样"时先看这个文件——commit / 安装时间不同就是差异原因。整个 `.harness/` 目录已自动加到项目 `.git/info/exclude`，本地忽略、不入库（含本文件）。

### 在新项目中使用

```bash
go-harness ~/code/new-project             # Go 后端 + openspec-auto
go-grpc-harness ~/code/new-grpc-service   # Go gRPC 微服务（全新项目可先用 go-grpc-harness/scaffold.sh 生成骨架）
fullstack-harness ~/code/new-fullstack    # Go + Vue 全栈
go-pkg-harness ~/code/new-package         # Go 扩展包
laravel-harness ~/code/new-laravel        # Laravel
laravel-fullstack-harness ~/code/new-lf   # Laravel + Vue 全栈
```

不传目录就装到当前目录。只装 harness 加 `--no-openspec`，或直接跑对应目录的 `setup.sh`。命令直接运行仓库里的脚本，仓库改了什么，下次运行就是什么。

如果你要把一个老项目的 `CLAUDE.md` / `AGENTS.md` 刷新到最新模板：

```bash
go-harness --force-project-files
HARNESS_FORCE_PROJECT_FILES=1 bash ~/tools/harness-engineering/go-harness/setup.sh   # 直接跑 setup.sh 的等价写法
```

这个开关会刷新项目根目录规则文件、六个工作流 skill、`.claude/rules/` 和 `.harness/scripts/` 里的运行时脚本，但不会强制覆盖你已经修改过的 `.harness/guides/`（那个用 `--force-guides` / `HARNESS_FORCE_GUIDES=1`，`--force` 两者都刷）。`CLAUDE.md` / `AGENTS.md` 里 openspec-auto 写入的托管块（`OPENSPEC-AUTO:START/END`）在刷新时原样保留；日常重跑 setup 比对入口文件是否为本版本时也会忽略这个块。

---

## Git 提交建议

默认策略：**所有 harness 产物都不入库，由每个成员各自运行 `go-harness` 等命令（或 `setup.sh` / `setup.ps1`）再生**。setup 把忽略规则**分两处**落地：

`.gitignore`（可入库）——只放通用构建 / 编辑器 / OS 产物：

```
.idea/
.vscode/
.DS_Store
*.log
*.out          # coverage.out、cpu.out、mem.out 等覆盖率 / profile 产物
.env           # go-pkg-harness 不写这一行：纯扩展包没有 .env 运行配置
```

`.git/info/exclude`（仅本地、绝不入库）——本地工具与 Agent 运行产物：

```
.harness/      # 入口规则、guides、运行时脚本、error-journal、VERSION 整目录
CLAUDE.md
AGENTS.md
.claude/       # skills/harness-*、rules/、openspec-auto 的 settings.json、个人 Claude 运行状态
.codex/
.agents/       # Codex 读的 skills/harness-*、openspec-auto skill
openspec/
.openspec-auto/         # openspec-auto 的 hooks、工具库、运行状态
.openspec-auto-backup/
.learnings/
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

**Q：guides 改错了想恢复怎么办？**

默认重跑只会补齐缺失 guide，不会覆盖你已经修改过的内容。想强制恢复模板版本：

```bash
go-harness --force-guides
HARNESS_FORCE_GUIDES=1 bash ~/tools/harness-engineering/go-harness/setup.sh   # 脚本等价写法
```

Laravel 系列同理：

```bash
HARNESS_FORCE_GUIDES=1 bash ~/tools/harness-engineering/laravel-harness/setup.sh
```

**Q：项目里的 `CLAUDE.md` / `AGENTS.md` 老了想升级怎么办？**

默认重跑不会覆盖项目里已存在的入口文件。想刷新到仓库当前模板时：

```bash
go-harness --force-project-files
HARNESS_FORCE_PROJECT_FILES=1 bash ~/tools/harness-engineering/go-harness/setup.sh   # 脚本等价写法
```

`CLAUDE.md` / `AGENTS.md` 里 openspec-auto 的托管块会原样保留。

Laravel / fullstack / go-pkg 也同理，只需要替换对应目录。

**Q：setup.sh 在 macOS 上能跑吗？**

能。脚本兼容 macOS 自带的 bash 3.2 和 zsh，没有用任何 Linux 专有语法。
---

## Windows 用法

### 推荐：Git Bash 或 WSL，与 macOS / Linux 完全一致

Claude Code 的原生 Windows 版本本身要求安装 Git for Windows，hook 在 Git Bash 里执行，所以能跑 Claude Code 的 Windows 机器上一定有 bash。在 Git Bash 里执行与 macOS / Linux 相同的命令即可，包括接 openspec-auto 的一键流程：

```bash
cd /c/path/to/harness-engineering && bash install.sh     # 命令写进 ~/go/bin（Git Bash 的 HOME 就是 C:\Users\<你>）
cd /c/code/your-backend-project && go-harness            # harness + openspec-auto
```

openspec-auto 也是 bash + Python 实现，在 Git Bash 里同样按 `python3` → `python` 探测解释器。WSL 里则与 Linux 完全一致。

### 只装 harness：PowerShell / cmd 原生入口

6 个 harness 模块另外提供 Windows 原生入口，装出的内容与 `setup.sh` 一致，但只装 harness；接 openspec-auto 要走上面的 Git Bash 路径。

- `setup.ps1`，用于 PowerShell
- `setup.bat`，用于 `cmd.exe`

建议先进入目标项目根目录，再执行对应模块脚本。下面用相对占位路径示例，避免依赖任何本机绝对路径。

### PowerShell 示例

```powershell
cd .\your-backend-project
powershell -ExecutionPolicy Bypass -File .\path\to\harness-engineering\go-harness\setup.ps1

cd .\your-grpc-service
powershell -ExecutionPolicy Bypass -File .\path\to\harness-engineering\go-grpc-harness\setup.ps1

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

如果你要改 `setup.sh` / `setup.ps1`、`guides/*.md`、`shared/guides/`、`rules/*.md`、`skills/*/SKILL.md`、`CLAUDE.md` / `AGENTS.md` 或 `scripts/`，提交前先在本地跑这套门禁：

```bash
# 0. 入口脚本语法
bash -n install.sh scripts/harness-init.sh scripts/harness-refresh.sh && python3 -m py_compile scripts/hooks/session_start.py

# 1. CLAUDE.md / AGENTS.md 同步检查（修改 AGENTS.md 后必跑）
bash scripts/sync-claude-from-agents.sh --check

# 2. setup.sh 语法 + 行为冒烟测试（6 套）
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
