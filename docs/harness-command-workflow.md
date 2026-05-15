# Harness Command Workflow 速查

这组命令是可选的复杂任务编排入口。简单改字段、补小 bug、改文案时，直接让 AI 按 harness 规则改即可；跨模块、高风险、需求不清晰或需要先确认方案时，再使用命令化流程。

## 命令对照

| 目的 | Claude Code | Codex |
|-----|-------------|-------|
| 检查环境 | `/harness:doctor` | `harness doctor` |
| 初始化 OpenSpec | `/harness:init-openspec` | `harness init-openspec` |
| 研究需求和约束 | `/harness:research` | `harness research: ...` |
| 生成执行计划 | `/harness:plan` | `harness plan` |
| 按计划实现 | `/harness:implement` | `harness implement` |
| 交付前审查 | `/harness:review` | `harness review` |

## 什么时候不用命令

- 单文件小改动
- 明确的编译错误或测试失败
- 简单字段、文案、样式、配置修改
- 已经非常清楚的局部 bugfix

这类任务直接描述需求即可：

```text
修复这个 handler 的参数校验 bug，并补对应测试。
```

## 典型场景

### 场景 1：安装后检查环境

Claude Code:

```text
/harness:doctor
```

Codex:

```text
harness doctor
```

适合刚执行 setup 后确认 `AGENTS.md`、`CLAUDE.md`、`.harness/guides/`、`.claude/commands/harness/` 是否齐全。

### 场景 2：复杂功能先研究

Claude Code:

```text
/harness:research
我要新增订单退款能力，涉及 API、数据库、支付回调、后台页面和权限控制。先不要写代码，先整理约束、风险、开放问题和成功标准。
```

Codex:

```text
harness research: 我要新增订单退款能力，涉及 API、数据库、支付回调、后台页面和权限控制。先不要写代码，先整理约束、风险、开放问题和成功标准。
```

输出应停在约束集和问题清单，不进入实现。

### 场景 3：把约束集变成计划

Claude Code:

```text
/harness:plan
```

Codex:

```text
harness plan
```

适合在你确认 research 结果后，把需求拆成文件清单、顺序任务、每步验证、回滚说明和测试目标。

### 场景 4：按批准计划实现

Claude Code:

```text
/harness:implement
```

Codex:

```text
harness implement
```

只在计划已经批准后使用。实现过程应小步提交、每步验证，不能临场重新做架构决策。

### 场景 5：交付前审查

Claude Code:

```text
/harness:review
```

Codex:

```text
harness review
```

适合交付前检查当前 diff，重点看正确性、安全、性能、分层、代码质量门禁、测试缺口和兼容性。

### 场景 6：需要 OpenSpec 管理

Claude Code:

```text
/harness:init-openspec
```

Codex:

```text
harness init-openspec
```

只有需要 proposal / spec / task 管理的大需求才用。缺少 OpenSpec CLI 时，必须先确认安装方式，不允许静默安装全局工具。

## 推荐路径

复杂需求优先使用：

```text
doctor -> research -> plan -> implement -> review
```

已确认环境时可以跳过 `doctor`。已有批准计划时可以直接从 `implement` 开始。简单任务不要强行套完整流程。
