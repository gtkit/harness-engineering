# Changelog

所有重要变更记录在此文件中。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### Added
- 引入 `tests/error_journal_test.sh`，独立覆盖 `scripts/error-journal/*.sh` 的 7 个关键契约（参数校验、缺失 journal 时退出、ID 生成与序号递增、多词 summary 合并、read 输出）。
- CI 工作流新增 `shellcheck -S warning` 静态检查步骤，覆盖 5 套 `setup.sh`、`scripts/` 与 `tests/` 下全部 bash 脚本，提前抓出 `bash -n` 漏掉的常见隐患。
- CI 工作流新增 `Run error-journal test` 步骤，把上述独立单测纳入主干门禁。

### Changed
- 同步顶层全局规则 2026-05-09 决策：`gtkit/go-pay` v1.3.0 通过 `paymgr` 提供跨渠道统一抽象，不属于轻封装。`go-harness`、`fullstack-harness`、`go-pkg-harness` 的入口规则与 `pkg-structure.md` 改为：将 `gtkit/go-pay` 列入 gtkit 原生包推荐，事实标准例子去除 `go-pay/gopay`、改用 `redis/go-redis` / `gorm/gorm` / `gin-gonic/gin`。

### Removed
- 下线独立的 C++ Linux AI harness（原 `C++/` 目录），同步移除 `tests/cpp_package_smoke_test.sh`、CI 工作流中对应 smoke 步骤及分支保护文档中的引用。

### Fixed

## [1.1.1] - 2026-05-08

### Changed
- 调整 Go 系列 harness 的第三方包选型规则：标准库优先，其次使用 gtkit 原生包，再选择业界事实标准包；gtkit 同名包若仅是轻封装，可直接依赖事实标准库。
- 明确 JSON 仍为固定例外，必须使用 `github.com/gtkit/json` 或 `github.com/gtkit/json/v2`，禁止 `encoding/json`。
- 同步 `go-harness`、`fullstack-harness`、`go-pkg-harness` 的 Agent 入口、扩展包设计指南和 review 清单。

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
