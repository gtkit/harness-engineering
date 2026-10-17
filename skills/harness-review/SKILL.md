---
name: harness-review
description: Review current changes against harness quality gates and project guides.
argument-hint: [optional scope]
---

# Harness Review

Use this before final delivery or before asking for human review.

## 验收 skill 路由

`harness-review` 负责识别变更面并调用全局验收 skill；本 skill 只编排，不复制验收正文。

- 看到后端运行行为、数据库、迁移、鉴权、队列、worker、定时任务或外部调用：**REQUIRED SUB-SKILL** `$backend-acceptance`。
- 看到前端页面、组件、路由、store、composable、API client 或浏览器安全/性能：**REQUIRED SUB-SKILL** `$frontend-acceptance`。
- 前后端契约、DTO、错误码、权限、数据库 schema、支付或消息状态变化：两个验收 skill 都要加载；先核对后端不变量，再核对前端契约和真实交互。
- 纯包/库变更没有服务入口或用户流程时，走包专属 review，不强行套业务后端验收。
- `go-harness`、`go-grpc-harness`、`laravel-harness` 默认是纯后端，任何运行行为交付都必须执行 `$backend-acceptance`；`fullstack-harness` 与 `laravel-fullstack-harness` 默认执行两个验收 skill。

验收结果必须区分通过、失败、未验证和不适用。关键业务、权限、数据一致性或核心依赖未验证时，不得给 Ready 结论。

## Guardrails

- Lead with findings by severity.
- Do not summarize first if there are defects.
- Use file paths and line references where possible.
- Keep output in Chinese.

## Steps

1. Inspect changed files:
   ```bash
   git status --short
   git diff --stat
   git diff --check
   ```
2. Load relevant guides:
   - `.harness/guides/review-checklist.md` or package review guide
   - `.harness/guides/acceptance-gates.md`
   - architecture / frontend / database guide as relevant
   - in a Go project `.harness/guides/skills-index.md`, then invoke the Go skills it maps to the changed areas before reviewing
3. Invoke the required acceptance skill(s) from the routing section before deciding readiness.
4. Review for:
   - correctness
   - security
   - performance
   - architecture and layering
   - code quality gate（代码质量门禁）
   - observability
   - compatibility and migration
   - tests and verification
5. Run available verification commands from the plan or guides.
6. Output:
   - Critical findings
   - Important findings
   - Minor findings
   - Test gaps
   - Verification run
   - Ready / not ready recommendation

## Exit Criteria

- The user can see whether the change is ready to deliver.
- Any remaining risk is explicit.
