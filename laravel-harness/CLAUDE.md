# CLAUDE.md

> Claude Code 每次对话自动加载，确保 laravel-harness skill 始终生效。

## 强制加载

**每次对话开始时，必须加载 laravel-harness skill 并遵守其全部规则。**

## 项目信息

- **后端**：Laravel / PHP 项目，版本优先跟随项目已有 `composer.json` / `composer.lock`
- **可选结构**：支持 `nwidart/laravel-modules`
- **强约束**：Queue、Scheduler、Event、Notification 默认纳入检查
- **规范文档**：`.harness/guides/`
- **错误记忆**：`.harness/error-journal.md`

## 行为底线

1. 禁止编造——不确定的 Laravel API、配置、命令不写
2. 禁止自由发挥——只做用户要求的事
3. 禁止跳过验证——交付前必须给出验证结果
4. 任务前读取错误日志——避免重复犯错
5. 清理杂物——发现 `.idea/`、`.DS_Store` 或 `.Ds_Store` 必须删除
