# Changelog

所有重要变更记录在此文件中。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### Added

### Changed

### Fixed

## [1.1.0] - 2026-04-28

### Added
- 为五套 harness 安装项目级 `error-journal` 读写脚本，补齐 `.harness/scripts/` 运行时能力。
- 为 shell / Windows 安装链补充 `error-journal` 追加回归测试，验证脚本可真实写入条目。
- 新增 `HARNESS_FORCE_PROJECT_FILES=1` 刷新路径，可更新项目内入口文件和运行时脚本。

### Changed
- 将 Claude / Codex 全局 skill 瘦身为运行时入口，规则中心下沉到项目内 `CLAUDE.md`、`AGENTS.md` 与 `.harness/guides/`。
- 统一 `CLAUDE.md` 与 `AGENTS.md` 的同步方式，避免两套入口文件内容漂移。
- 更新 README，明确 `error-journal` 的触发条件、脚本调用方式和项目结构。

### Fixed
- 修复 `error-journal` 仅有文档要求、没有通用追加实现的问题。
- 修复 shell 安装器错误忽略整个 `.harness/` 目录的问题，避免误伤应提交的 `guides/` 和 `scripts/`。
