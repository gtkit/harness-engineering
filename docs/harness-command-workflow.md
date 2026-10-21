# Harness Command Workflow 速查

这组 skill 是可选的复杂任务编排入口，Claude Code 与 Codex 装的是同一份 `SKILL.md`（分别在 `.claude/skills/harness-*/` 与 `.agents/skills/harness-*/`），Claude Code 用 `/harness-xxx` 调用，Codex 用 `$harness-xxx` 或 `/skills` 选择。简单改字段、补小 bug、改文案时，直接让 AI 按 harness 规则改即可；跨模块、高风险、需求不清晰或需要先确认方案时，再使用命令化流程。

## 命令对照

| 目的 | Claude Code | Codex |
|-----|-------------|-------|
| 安装更新、环境变化或加载异常时诊断 | `/harness-doctor` | `$harness-doctor` |
| 初始化 OpenSpec | `/harness-init-openspec` | `$harness-init-openspec` |
| 研究需求和约束 | `/harness-research` | `$harness-research ...` |
| 生成执行计划 | `/harness-plan` | `$harness-plan` |
| 按计划实现 | `/harness-implement` | `$harness-implement` |
| 交付前审查 | `/harness-review` | `$harness-review` |

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

### 场景 1：安装更新、环境变化或加载异常时诊断

Claude Code:

```text
/harness-doctor
```

Codex:

```text
$harness-doctor
```

适用于 skills/harness 安装更新后、影响加载的环境变化或加载异常时，按变化或异常范围检查相关入口、Guide、技能与工具。优先复用当前会话 skills 清单和已加载规则，不默认完整体检；日常开发按任务直接读取相关技能正文，复杂任务、新会话或切换阶段本身不触发 doctor。

### 场景 2：复杂功能先研究

Claude Code:

```text
/harness-research
我要新增订单退款能力，涉及 API、数据库、支付回调、后台页面和权限控制。先不要写代码，先整理约束、风险、开放问题和成功标准。
```

Codex:

```text
$harness-research 我要新增订单退款能力，涉及 API、数据库、支付回调、后台页面和权限控制。先不要写代码，先整理约束、风险、开放问题和成功标准。
```

输出应停在约束集和问题清单，不进入实现。

### 场景 3：把约束集变成计划

Claude Code:

```text
/harness-plan
```

Codex:

```text
$harness-plan
```

适合在你确认 research 结果后，把需求拆成文件清单、顺序任务、每步验证、回滚说明和测试目标。

### 场景 4：按批准计划实现

Claude Code:

```text
/harness-implement
```

Codex:

```text
$harness-implement
```

只在计划已经批准后使用。实现过程应小步提交、每步验证，不能临场重新做架构决策。

### 场景 5：交付前审查

Claude Code:

```text
/harness-review
```

Codex:

```text
$harness-review
```

适合交付前检查当前 diff，重点看正确性、安全、性能、分层、代码质量门禁、测试缺口和兼容性。

### 场景 6：需要 OpenSpec 管理

Claude Code:

```text
/harness-init-openspec
```

Codex:

```text
$harness-init-openspec
```

只有需要 proposal / spec / task 管理的大需求才用。命令优先检查并复用 `openspec-auto`（仓库内 hooks + skill + 托管块的自动工作流），项目用 `init.sh` 初始化时它已经装好，此时命令只跑体检；缺少 OpenSpec CLI 时，必须先确认安装方式，不允许静默安装全局工具。

## 推荐路径

复杂需求优先使用：

```text
research -> plan -> implement -> review
```

`doctor` 不属于日常开发的前置步骤；除用户明确要求诊断外，仅在安装更新、影响加载的环境变化或加载异常时，针对相关范围单独使用。已有批准计划时可以直接从 `implement` 开始。简单任务不要强行套完整流程。
