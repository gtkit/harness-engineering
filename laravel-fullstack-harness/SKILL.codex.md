---
name: laravel-fullstack-harness
description: Laravel + Vue 全栈 Harness Engineering skill。用于已安装 laravel-fullstack-harness 的项目；触发后读取项目根目录 AGENTS.md 和 .harness/guides/。
---

# Laravel Fullstack Harness Skill

本 skill 只负责触发，不承载完整规范。

如果项目内存在 `.harness/scripts/read-error-journal.sh` 或 `.harness/scripts/read-error-journal.ps1`，开始任务前先执行与当前 shell 匹配的读取脚本；只要用户提示词中出现“犯错”“错误”“错了”“不对”“有问题”“bug”“失败”“回归”等纠错信号，或发生用户纠正、命令失败、测试失败、审查缺陷时，执行对应的 `append-error-journal` 脚本。

Codex 的完整项目规则在：
- `AGENTS.md`
- `.harness/guides/`

当本 skill 被触发时：
1. 先读取并遵守项目根目录 `AGENTS.md`
2. 再按任务类型读取 `.harness/guides/` 中对应文档
3. 如果缺少 `AGENTS.md` 或 `.harness/guides/`，不要编造 harness 规则，提示用户先运行 `setup.sh` 或 `setup.ps1`
