# Error Journal

## 使用规则

1. 每次任务开始前先读取本文件
2. 每次出现以下情况必须追加记录：
   - 命令失败
   - 测试失败
   - 用户纠正
   - 审查发现缺陷
   - 回归问题
   - 误判
3. 每次任务结束前必须执行“历史错误对照检查”
4. 同类问题第二次出现时，必须新增更强预防措施
5. 关闭问题前必须补充验证证据

## 条目模板

## [ERR-YYYYMMDD-001] event_type

**Logged**: YYYY-MM-DDTHH:MM:SS+0800
**Status**: open / closed
**Area**: architecture / cpp / linux / ai / build / test / security / release
**Severity**: P0 / P1 / P2 / P3

### Summary
一句话描述问题

### What Happened
问题现象、触发方式、失败位置

### Root Cause
根因说明

### Corrective Action
本次修复动作

### Prevention Rule
以后如何避免再犯

### Related Files
- path/to/file

### Validation Added
- 新增测试 / 新增检查 / 新增审查项

### Linked History
- 相关旧条目 ID，没有则写 `none`

---

## [ERR-INIT-001] bootstrap

**Logged**: 2026-04-13T18:30:00+0800
**Status**: open
**Area**: process
**Severity**: P2

### Summary
初始化错误日志模板，后续任务开始前必须先读取本文件

### What Happened
项目刚接入 Harness，需要建立统一错误记忆机制

### Root Cause
此前缺少统一错误记录与对照流程

### Corrective Action
引入本文件并在 AGENTS 与 Skill 中设为强制步骤

### Prevention Rule
所有任务在开始前读取，结束前对照，出错时追加

### Related Files
- AGENTS.md
- .harness/error-journal.md

### Validation Added
- pre-commit / pre-merge / pre-release 检查中增加错误日志对照项

### Linked History
- none

---

## [ERR-20260413-001] gitignore-shadowing

**Logged**: 2026-04-13T18:45:00+0800
**Status**: open
**Area**: release
**Severity**: P1

### Summary
新增的 Harness、README 和 plan 文件被仓库忽略规则屏蔽，导致内容已落盘但不会被 git 追踪

### What Happened
在验证阶段发现 `git status` 未显示新建的 Harness 资产。进一步检查确认父仓库 `.gitignore` 忽略了 `.harness/` 和 `docs/`，当前子项目 `.gitignore` 又忽略了 `*.md`，导致本次新增的核心文件全部被忽略。

### Root Cause
仓库现有忽略规则面向旧约束编写，没有为项目内 Harness、Skill、plan 和专用 README 预留白名单。

### Corrective Action
在父仓库与当前项目的 `.gitignore` 中增加针对 `api/AGENTS.md`、`api/.harness/`、`api/docs/superpowers/plans/`、`api/doc/harness/README.md` 和 `api/openspec/changes/cpp-linux-ai-harness/` 的例外规则。

### Prevention Rule
以后新增治理目录、Skill 目录、spec/plan 文档时，必须在验证阶段执行 `git check-ignore -v` 或等价检查，确认关键文件可被版本控制追踪。

### Related Files
- ../.gitignore
- .gitignore
- .harness/error-journal.md

### Validation Added
- 在本次任务中补充 `git check-ignore -v` 与 `git status --short --untracked-files=all` 检查

### Linked History
- ERR-INIT-001

---

## [ERR-20260413-002] validation-env-gap

**Logged**: 2026-04-13T18:55:00+0800
**Status**: open
**Area**: test
**Severity**: P3

### Summary
使用 `python3` 解析 Skill YAML 时缺少 `yaml` 模块，导致验证命令失败

### What Happened
在验证 `agents/openai.yaml` 时，尝试使用 `python3` + `yaml.safe_load` 解析文件，但当前环境未安装 PyYAML，命令直接报 `ModuleNotFoundError: No module named 'yaml'`。

### Root Cause
验证命令隐含依赖第三方 Python 模块，而当前仓库和运行环境并未保证该依赖存在。

### Corrective Action
改用系统自带 Ruby 的 `YAML.load_file` 完成本次元数据解析验证，不再依赖 PyYAML。

### Prevention Rule
后续为 Harness 或 Skill 设计验证命令时，优先选择无额外依赖的系统工具；若必须依赖第三方模块，必须先声明环境前提。

### Related Files
- docs/superpowers/plans/2026-04-13-cpp-linux-ai-harness.md
- .harness/error-journal.md

### Validation Added
- 使用 `ruby -e 'require "yaml"; ...'` 作为无依赖 YAML 解析验证

### Linked History
- ERR-INIT-001

---
