# Changelog

所有重要变更记录在此文件中。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

> ⚠ 行为变更：setup 生成的忽略规则改为**分两处**落地——通用产物（`.idea/`、`.vscode/`、`.DS_Store`、`*.log`）留在 `.gitignore`；本地工具与 Agent 运行产物（`.harness/`、`CLAUDE.md`、`AGENTS.md`、`.claude/`、`.codex/`、`openspec/`、`tools/`、计划文件等）改写进 `.git/info/exclude`。老项目重跑 setup 会自动把这些规则从 `.gitignore` 剔除并迁移到 `.git/info/exclude`（业务自定义规则保持不动）。

### Added
- 为 `go-harness` 与 `fullstack-harness` 新增 `guides/testing-and-validation.md`，补齐 Go 后端业务服务缺失的测试、回归、race、API 契约和全栈联调验证专项 guide；入口加载表、README 和 smoke 测试同步纳入。
- 为 `go-harness` 与 `fullstack-harness` 新增 `guides/workers-and-scheduling.md`，补齐 Go 后端后台 goroutine、队列消费者、定时任务、outbox、幂等、优雅关闭和可观测性专项约束。
- 为 `go-pkg-harness` 新增 `guides/pkg-release-and-supply-chain.md`，补齐 Go 扩展包发布、SemVer/tag、v2+ module path、依赖治理、`govulncheck`、license 和安全发布专项约束。

### Changed
- setup 生成的忽略规则由「全部写进 `.gitignore`」改为**按性质分流**：通用构建 / 编辑器 / OS 产物留在 `.gitignore`（可入库），本地工具与 Agent 运行产物（`.harness/`、`CLAUDE.md`、`AGENTS.md`、`.claude/`、`.codex/`、`.agents/`、`openspec/`、`.openspec-auto*/`、`tools/`、`findings.md`、`progress.md`、`task_plan.md`）改写进 `.git/info/exclude`（仅本地、绝不入库）。目的：避免忽略规则本身泄露「本项目使用了 AI 工具」。`sh` / `ps1` 两端模式串保持一致，`.git/info/exclude` 路径经 `git rev-parse --git-path` 解析以兼容 worktree / submodule；非 git 仓库时跳过并提示先 `git init`。README「日常使用」「Git 提交建议」两节与 CHANGELOG 同步。
- setup 重跑时对存量 `.gitignore` 做**迁移清理**：精确剔除旧版本误写入的本地工具规则与旧 `# Harness:` 标题，迁移到 `.git/info/exclude`，业务自定义规则与通用产物原样保留。两套 smoke 测试新增专门的迁移用例与 `.git/info/exclude` 断言，并为夹具补 `git init`。
- CI 的 Windows PowerShell 静态检查改为按需安装并导入 `PSScriptAnalyzer`，扫描范围从 5 个 `setup.ps1` 薄包装扩展到共享安装器、error-journal PowerShell 脚本和 PowerShell 测试脚本；README 本地门禁命令同步补齐 Windows setup smoke。

## [1.4.0] - 2026-06-17

> ⚠ 行为变更：setup 生成的 `.gitignore` 改为整目录忽略 `.harness/`（详见 Changed）。老项目重跑 setup 会追加 `.harness/` 规则；若此前依赖把 `.harness/guides/` 入库共享，请改用模板回流或在 `.gitignore` 中 `!.harness/guides/` 取消忽略。

### Added
- 新增 `docs/harness-and-loop-architecture.md`，澄清 harness（规则层）与 Loop 架构 6 模块的能力边界：harness 原生拥有「递归目标迭代纪律 + Skill 意图固化 + Memory 错误记忆」3 块，调度 / worktree 隔离 / MCP / 子 Agent 派发归运行时，并说明为保持跨工具中立刻意不实现后者。README 增链接。
- 五套 harness 的入口规则（`AGENTS.md` / `CLAUDE.md`）在「可验证目标（Goal-Driven Execution）」下新增「迭代与停止纪律（Verify–Correct Loop）」一节：显式约束 agent 的迭代闭环——先观察再改、改完跑相关全量防回归、同一问题自纠 3 轮为上界后停手并向用户汇报、进展为正才继续（震荡视同卡住）、修复后确认非回归并按错误记忆追加。补齐此前只隐含在 RPI / error-journal 中、缺乏停止条件与升级策略的 loop 工程缺口；零新增文件，活在已自动加载的入口文档内。

### Changed
- 全面修订五套 harness 的 `.harness/guides/` 规范文档（基于跨领域评审）：
  - **Go 后端**：`payment.md` 明确支付渠道统一走 `gtkit/go-pay` 的 `paymgr`（`PaymentGateway` 改为业务侧 port），消除与固定技术栈冲突；`llm-integration.md` 标明 `json` 指 `gtkit/json`、禁 `encoding/json`；`architecture.md` 增「日志库（选一种禁混用）」与「优雅关闭」；`api-conventions.md` 增「错误体系（apperror）与 ErrorHandler」「鉴权与限流」。
  - **Go 扩展包**：`pkg-generics.md` 修正"标准库 constraints"误述与 `maps.Keys`（1.23+ 返回 iterator，改 `slices.Collect`）；`pkg-structure.md` 增 v2+ module path / `v2/` 子目录落地、ctx 不入 struct、可返回 error 的 Option、废弃流程；`pkg-errors.md` 增自定义错误 `Unwrap`/`Is`；`pkg-testing.md` 增并发安全竞态测试与覆盖优先级；`pkg-docs.md` CHANGELOG 对齐 Keep-a-Changelog 六类。
  - **Laravel**：`queues-events-scheduling.md` 增 `withoutOverlapping`/`onOneServer`、Job `failed()`/`$maxExceptions`/`retryUntil`、同步 vs `ShouldQueue` 监听器边界；`data-and-eloquent.md` 增锁（`lockForUpdate`/乐观锁/死锁重试）、mass assignment / 原始 SQL 绑定、`preventLazyLoading`/`cursor`；`http-and-api.md` 增统一错误响应契约+状态码映射、Policy/Gate 授权、CSRF/限流/签名 URL；`testing-and-validation.md` 增 Factory/`RefreshDatabase`/Pest；`notifications-and-mail.md` 增防重发与脱敏；`laravel-modules.md` 增可检测的跨模块依赖硬规则。
  - **前端**：`laravel-fullstack-harness` 三份前端 guide 从约 111 行补齐到与 `fullstack-harness` 相当（约 465 行），整段移植与后端无关的纯前端规范（Axios 封装/拦截器、`ApiError`、tsconfig strict、props/emits、composable、命名、env.d.ts、样式），API 契约层改写为 Laravel Resource / 标准分页（`current_page`/`last_page`）/ `422 errors`；两套全栈前端同时补齐路由守卫鉴权、请求取消防竞态、loading/error/empty 三态、表单校验、性能与可访问性。
  - **review-checklist**：修复 `fullstack` 版前端段标题重号（8/9 重复→顺延 10-18）；`laravel-harness` 版补齐锁/授权/安全勾选项；各版同步新增上述能力的自查项。

- 重构 bash 安装链路：5 套 `setup.sh` 从各自约 300 行的近重复脚本收敛为薄包装，统一调用新增的共享库 `scripts/install-harness.sh`（`install_harness`），与早已重构的 PowerShell 端 `Invoke-HarnessSetup` 对齐。`.gitignore` 模式串、安装流程、`.harness/VERSION` 写入等收敛到单一源头，消除 sh / ps1 多处复制导致的漂移风险（参见 1.2.0 的 Windows `.gitignore` 漏写事故根因）。CI 的 `bash -n` 与 shellcheck 清单同步纳入新共享库。
- setup 生成的 `.gitignore` 改为整目录忽略 `.harness/`，取代原先的细粒度 `.harness/error-journal.md` 与 `.harness/VERSION` 两条；`sh` / `ps1` 两端模式串保持一致。配套更新三套 smoke 测试基线与 README「Git 提交建议」章节：明确所有 harness 产物（`.harness/`、`CLAUDE.md`、`AGENTS.md`、`.claude/`）默认不入库、由 setup 再生，并给出团队共享定制规则的两条路径。

### Fixed

## [1.3.0] - 2026-05-15

### Added
- 新增 `commands/harness/` Claude Code slash commands：`doctor`、`init-openspec`、`research`、`plan`、`implement`、`review`，用于可选的复杂任务 RPI 编排。
- 五套 harness 的安装脚本会把命令模板安装到项目 `.claude/commands/harness/`，并在默认模式保留用户本地已修改命令；`HARNESS_FORCE_PROJECT_FILES=1` 可强制刷新。
- 新增 Codex 命令化工作流兼容入口：在 `AGENTS.md` 中识别 `harness doctor`、`harness research: ...`、`harness plan`、`harness implement`、`harness review`、`harness init-openspec` 自然语言别名，并优先读取同名命令模板。
- 新增 `docs/harness-command-workflow.md`，提供 Claude Code / Codex 命令速查、典型场景和推荐路径。

### Changed
- README 增加可选命令化 RPI 工作流说明，分别说明 Claude Code 使用 `/harness:*`，Codex 使用 `harness ...` 自然语言别名。
- 五套 harness 的 `AGENTS.md` / `CLAUDE.md` 和相关 guide 增加强代码质量要求，覆盖减少冗余、代码复用、架构清晰、分层合理、健壮稳定和简单优先。
- CI、Bash smoke、Windows smoke、Laravel smoke 覆盖命令模板安装、保留/强制刷新行为、Codex 兼容入口和速查文档。

## [1.2.0] - 2026-05-14

### Added
- 引入 `tests/error_journal_test.sh`，独立覆盖 `scripts/error-journal/*.sh` 的 7 个关键契约（参数校验、缺失 journal 时退出、ID 生成与序号递增、多词 summary 合并、read 输出）。
- 引入 `tests/error_journal_test.ps1`，与 bash 版对称覆盖 `scripts/error-journal/*.ps1` 的同 7 个契约，并在 `smoke-windows` job 中执行，闭合 PowerShell 端单测缺口。
- CI 工作流新增 `shellcheck -S warning` 静态检查步骤，覆盖 5 套 `setup.sh`、`scripts/` 与 `tests/` 下全部 bash 脚本，提前抓出 `bash -n` 漏掉的常见隐患。
- CI 工作流新增 `Run error-journal test` 步骤，把上述独立单测纳入主干门禁。
- CI 工作流新增 `PSScriptAnalyzer` 静态检查步骤，对 5 套 `setup.ps1` 做 Warning/Error 级别审计（当前实测全部 0 issues）。
- 入库 `docs/github-branch-protection.md` 与 3 份 `docs/superpowers/{plans,specs}/*.md` 设计/实施留痕，README 加 "贡献本仓库（修改 harness 模板）" 一节，列出本地 7 步门禁命令（与 CI 对齐）。
- `setup.sh` / `setup.ps1` 新增 Step 5：在 `.harness/VERSION` 写入安装指纹（`harness` / `source-commit`（12 位 SHA）/ 可选 `source-tag` / `installed-at` / `installer`）；该文件已加入项目 `.gitignore`，不入库，仅供本地排查"成员间 .harness/ 差异来源"。`tests/setup_smoke_test.sh` 与 `tests/setup_windows_smoke_test.ps1` 同步加 `assert_version_file` 检查；README "日常使用" 章节新增 "查看 harness 版本" 一节。

### Changed
- 同步顶层全局规则 2026-05-09 决策：`gtkit/go-pay` v1.3.0 通过 `paymgr` 提供跨渠道统一抽象，不属于轻封装。`go-harness`、`fullstack-harness`、`go-pkg-harness` 的入口规则与 `pkg-structure.md` 改为：将 `gtkit/go-pay` 列入 gtkit 原生包推荐，事实标准例子去除 `go-pay/gopay`、改用 `redis/go-redis` / `gorm/gorm` / `gin-gonic/gin`。

### Removed
- 下线独立的 C++ Linux AI harness（原 `C++/` 目录），同步移除 `tests/cpp_package_smoke_test.sh`、CI 工作流中对应 smoke 步骤及分支保护文档中的引用。

### Fixed
- ⚠ **Windows 安装器 .gitignore 基线严重缺失**：`scripts/install-harness.ps1` 在 Step 3 只写入 6 条 `.gitignore` 规则（`.harness/error-journal.md`/`.idea/`/`.DS_Store`/`findings.md`/`progress.md`/`task_plan.md`），而 `setup.sh` 写入 18 条；缺失的 12 条里包括 `.claude/`、`.codex/`、`.agents/`、`AGENTS.md`、`CLAUDE.md`、`openspec/`、`*.log`、`.openspec-auto*/` 等敏感基线 —— Windows 用户装完后这些 agent 运行时产物**没被自动忽略**，可能误提交聊天历史、缓存的 token、本地工具产物。修复后 ps1 与 sh 完全对齐写入相同 18 条。
- 修正 `Add-UniqueLine` 大小写比较：之前用 PowerShell 默认大小写不敏感的 `-contains`，导致 `.Ds_Store` 已存在时 `.DS_Store` 被跳过；改用 `-ccontains` 与 `setup.sh` 的 `grep -Fxq` 行为对齐。
- `tests/setup_windows_smoke_test.ps1` 同步扩展 `.gitignore` baseline 检查到 18 条（与 ubuntu smoke 对齐），并补 `AGENTS.md` / `CLAUDE.md` 不含"清理杂物"等过时文案的 `Assert-FileNotContains` 检查，闭合 Windows 端覆盖缺口。
- 修复 GitHub Actions windows-latest 长期未通过的根因：`tests/setup_windows_smoke_test.ps1` 含 UTF-8 中文断言（`清理杂物` / `分层架构` 等），而 PS 5.1 默认用 Windows-1252 读脚本导致 parser 抛 `TerminatorExpectedAtEndOfString`。CI `smoke-windows` job 改用 `pwsh`（PowerShell 7+，默认 UTF-8）替代 `powershell`（PS 5.1）执行测试脚本；终端用户实际安装链路 (`setup.ps1` / `install-harness.ps1` / `error-journal/*.ps1`) 已全部无中文，PS 5.1 用户继续兼容。
- 修复 `Write-HarnessVersion` 在 PowerShell 7.3+ 上的 native command 错误传播：`$PSNativeCommandUseErrorActionPreference=true` + `$ErrorActionPreference=Stop` 下，shallow clone 无 tag 时 `git describe --tags --abbrev=0` 输出 `fatal: No names found` exit 128 会抛 RemoteException 中断 setup（`2>$null` 只静音 stderr，不阻止 ErrorAction 传播）；修复后用 `try/finally` 临时降级 EAP 为 `SilentlyContinue`，`LASTEXITCODE` 检查仍兜底。

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
