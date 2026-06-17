# harness 与 Loop 架构的关系

这篇文档解决一个常见误解：**Loop 架构里那些能力，哪些是 harness 提供的、哪些是运行时（Claude Code / Codex）提供的。**

结论先行：harness 是**规则层**（静态文本：规则、guides、setup 脚本、命令模板），它不是执行引擎。Loop 架构里的大多数模块是**运行时能力**，harness 实现不了，只能调用或下达策略。harness 真正原生拥有的是其中 3 块：**递归目标的迭代纪律 + Skill（意图固化）+ Memory（错误记忆）**。

---

## Loop 架构 6 模块归属

| 模块 | 谁实现 | harness 现状 |
|-----|-------|-------------|
| **中心：递归目标 / 迭代直到完成** | harness（治理）+ 运行时（执行） | 入口规则的「迭代与停止纪律（Verify–Correct Loop）」提供"怎么循环、何时停、何时升级"的纪律 |
| **③ Skill（SKILL.md / 固化意图 / 分发）** | **harness 原生** | 5 套 `SKILL.md` / `SKILL.codex.md` 即意图固化，`setup.sh` / `setup.ps1` 即分发 |
| **⑥ 记忆机制（markdown / 持久化）** | **harness 原生** | `.harness/error-journal.md` + `.harness/guides/` 即"模型会忘、仓库不会" |
| **① 自动化调度（Automations / `/loop` / cron / `/goal`）** | 运行时 | 实现不了，只能在命令模板里引用；且仅 Claude Code 有 |
| **② 工作树隔离（git worktree / 自动清理）** | 运行时 | 实现不了，只能下达"用隔离环境跑并行子任务"的策略 |
| **④ 插件与连接器（MCP / Connectors）** | 外部 MCP server | 实现不了；`/harness:doctor` 会检查其可用性 |
| **⑤ 子 Agent（写代码 Agent / 检查 Agent 协作）** | 运行时派发 | 实现不了真正的并行派发；`/harness:implement`、`/harness:review` 是角色化提示词，是它的"轻量版" |

直观地说：**harness 占住了图的内核（递归目标的纪律）和两个角（Skill、Memory）；其余四块属于运行时。**

---

## 为什么 harness 不去实现那四块

不是做不到包一层，而是**刻意不做**，理由：

1. **保持跨工具中立**。`/loop`、worktree、子 Agent 派发、cron 这些 Codex 没有。把这套机械塞进 harness，就等于焊死在 Claude Code 上，放弃 Codex / Cursor 等同时读同一套 guides 的能力——而这正是项目的立身之本。
2. **不重造运行时的轮子**。调度、隔离、子 Agent、MCP 运行时原生就有，harness 再包一层只增加维护面，不增加能力。
3. **遵守项目自己的「简单优先」**。harness 的护城河是"规则 + 记忆 + 意图固化"，不是当 loop 引擎。

---

## 各角色分工

- **递归目标（中心）**：harness 给纪律，运行时给执行力。
  - harness 侧：见各模块 `CLAUDE.md` / `AGENTS.md` 的「可验证目标（Goal-Driven Execution）」→「迭代与停止纪律（Verify–Correct Loop）」——先观察再改、改完跑相关全量、自纠 3 轮为上界后停手并向用户汇报、进展为正才继续、回归确认并写 `.harness/error-journal.md`。
  - 运行时侧：Claude Code 的 `/loop`、`/goal`、cron、Workflow 负责真正驱动迭代。
- **Skill（③）**：harness 全包。改规则就改这里，再 `setup` 分发。
- **Memory（⑥）**：harness 全包。`.harness/error-journal.md` 跨会话记忆，guides 跨成员沉淀。
- **调度 / 隔离 / 连接器 / 子 Agent（①②④⑤）**：交给运行时。harness 只在命令模板和规则里"调用"或"要求"它们，不实现。

---

## 实践指引

- 想让 AI"定义目标 → 持续迭代到完成"：在 **Claude Code** 上用 `/loop` / `/goal` / Workflow 驱动，harness 的迭代纪律会自动约束它怎么循环、何时停。
- 想沉淀经验、不让模型重复犯错：靠 `.harness/error-journal.md`（Memory），这是 harness 的强项。
- 想固化团队意图、统一规范：靠 `SKILL.md` + guides（Skill），改完重新 `setup` 即可分发。
- **不要期待 harness 自己去调度、开 worktree、派子 Agent**——那是运行时的事；harness 只负责"该怎么做"的规则与"别忘了什么"的记忆。
