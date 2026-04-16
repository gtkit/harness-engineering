# Proposal: cpp-linux-ai-harness

## 背景（Why）

需要一套可直接落地到企业级 `C++20/23 + Linux + AI` 项目的 Harness 模板，并将其封装为可复用 Skill，统一 AI 的工作流程、输出纪律、验证门槛与错误记忆机制。

## 目标（What）

本变更需要实现以下目标：

1. 提供项目级 `AGENTS.md`
2. 提供 `.harness/` 目录及治理文件
3. 提供可复用 Skill
4. 提供详细使用文档
5. 提供错误记忆、交叉验证、风险排查和发布门槛

## 影响范围（Impact）

涉及新增目录与文件：

- `AGENTS.md`
- `.harness/**`
- `doc/harness/README.md`
- `openspec/changes/cpp-linux-ai-harness/**`
- `docs/superpowers/plans/2026-04-13-cpp-linux-ai-harness.md`

当前不影响现有 Go / Vue 业务代码行为。

## 歧义确认记录

| # | 需求原文 | 确认结果 | 决策方 |
| --- | --- | --- | --- |
| 1 | 落地 Harness 模板 | 在当前仓库新增 `.harness/` 与 `AGENTS.md` | 用户 |
| 2 | 做成 Skill | 将 Skill 放入 `.harness/skills/cpp-linux-ai-harness/` | AI 决策 |
| 3 | 写详细 README | 新增 `doc/harness/README.md`，不覆盖现有根 README | AI 决策 |
