# CLAUDE.md

> 本文件由 Claude Code 每次对话自动加载，确保 go-harness skill 始终生效。

## 强制加载指令

**每次对话开始时，必须加载 go-harness skill 并遵守其全部规则。**

无论用户的请求看起来多简单（改个 bug、加个字段、写个函数），
只要涉及本项目的 Go 代码，go-harness skill 的所有章节都生效。

## 项目信息

- **语言**：Go 1.26.2
- **框架**：Gin + GORM + github.com/gtkit/*
- **类型**：企业级 Web 服务

## 规范文档位置（单一来源）

所有 Guide 文档统一存放在 `.harness/guides/`，Claude Code 和 Codex 共用。
skill 的 `references/` 目录不存在，所有路径指向 `.harness/guides/`。

## 错误记忆

每次任务开始前先读取 `.harness/error-journal.md`（如果存在）。
用户纠正 Agent 输出时，将错误追加到该文件。

## 行为底线

1. 禁止编造——不确定的 API、包名、参数不写，问用户
2. 禁止自由发挥——只做用户要求的事，不扩展
3. 禁止跳过检查——每次交付必须附合规摘要
4. Logic 四步必须走完——理解需求 → 提取信息 → 按结构组织 → 检查合规
