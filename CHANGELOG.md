# Changelog

所有重要变更记录在此文件中。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

## [1.9.0] - 2026-08-25

### Added
- 四套 Go harness（`go-harness`、`go-grpc-harness`、`fullstack-harness`、`go-pkg-harness`）新增 **`go-modern.md`**：Go 1.27 现代语法的落地规范，一次性覆盖泛型方法、标准库 `uuid` 包、`errors.AsType`、`sync.WaitGroup.Go`、`new(expr)`、range-over-int / range-over-func、`slices`/`maps`/`cmp`、`omitzero` tag。文中每条签名、报错信息与编解码输出都在本机 go1.27.0 上实测过，代码片段整包 `go run` + `go vet` + `go fix -diff` 通过。该 guide 已登记进四套的 Guide 加载表，并在服务型三套里声明为"所有代码任务始终生效"。
  - **泛型方法**：写法 + 两条编译器强制约束的实测报错——接口里带类型参数的方法报 `interface method must have no type parameters`，未实例化的方法值报 `cannot use generic function ... without instantiation`；选型标准是"同一容器上随调用方类型变化的读取 / 转换用泛型方法，跨实现替换用接口 + 包级泛型函数"。`go-pkg-harness` 版指向已有的 `pkg-generics.md` 不重复，并补上"泛型方法进入导出面、改类型参数是破坏性变更"的 SemVer 影响。
  - **UUID**：标准库 `uuid` 包的完整取用表（`New` / `NewV4` / `NewV7` / `Nil` / `Max` / `Parse` / `MustParse` / `Compare` / `String`），加三条实测行为——① `uuid.Nil()` 是函数不是变量，漏括号写 `u == uuid.Nil` 报 `mismatched types uuid.UUID and func() uuid.UUID`；② `uuid.UUID` 未实现 `driver.Valuer`、`*uuid.UUID` 未实现 `sql.Scanner`，不能直接当 GORM 列类型，必须 `.String()`（`CHAR(36)`）/ `u[:]`（`BINARY(16)`）/ 成对自实现 Valuer+Scanner；③ 它是数组类型，`omitempty` 对其无效，可选字段的 JSON tag 必须用 `omitzero`——而 `go fix` 的 `omitzero` 改写器实测**不**标记数组类型上的 `omitempty`，这条门禁抓不到，只能人工核对。
  - `go-grpc-harness` 版额外给出 proto 侧落法：契约用 `string` 字段 + protovalidate 的 `(buf.validate.field).string.uuid = true`（该规则在 protovalidate v1.3.0 自带测试 proto 中已使用，已核对），transport 层 `uuid.Parse` 转换，`application` 只见 `uuid.UUID`。
- 服务型三套的 `db-patterns.md` 新增「主键与 UUID」一节：何时从自增整型换到 UUID、为什么主键选 `NewV7()`（高 48 位时间戳、B+ 树插入不随机跳页）、`CHAR(36)` 与 `BINARY(16)` 两种落库形态的取舍，以及存储形态切换属破坏性变更须走 `migration.md`。
- 四套 Go harness 的审查清单（三份 `review-checklist.md` + `pkg-review.md`）新增泛型方法与 UUID 检查项：泛型方法是否用在了该用的地方、ID 是否走 `uuid.NewV7()` / `uuid.New()`、入库转换是否显式且 Valuer/Scanner 成对、可选 UUID 字段是否用 `omitzero`。

### Fixed
- 「`go fix` 内置 27 个 modernizer」这个数字是错的：本机 go1.27.0 上 `go tool fix help` 实测注册 **26 个** analyzer，且其中 `buildtag`、`hostport`、`plusbuild`、`inline` 并不是现代化改写器。四份 `go-modern.md`、`pkg-review.md` 与 1.8.0 的 CHANGELOG 条目改为不写死数量、指向 `go tool fix help` 查清单，避免随 Go 版本继续漂移。

### Changed
- 四套 Go harness 的技术栈段从"使用现代特性"改为 **"必须使用现代语法"**，特性清单统一（此前 `go-pkg-harness` 缺 `errors.AsType` / `WaitGroup.Go` / `new(expr)`，三套服务型缺 `omitzero`），并写明门禁是 `go fix -diff ./...` 无输出、细则指向 `.harness/guides/go-modern.md`。UUID 那一行补上 `uuid.Nil()` 是函数的提示与转换约束入口。
- README 的四处安装说明树补入 `go-modern.md`，并把「N 个规范文档」的计数与清单改成与实际安装结果逐名一致（此前 `go-harness` 声称 9 实际 14、`fullstack-harness` 声称 12 实际 17、`go-pkg-harness` 声称 7 实际 8；现为 15 / 18 / 9 / 15，已用实跑 setup 的产物逐个核对）。
- setup 写入 `.gitignore` 的通用忽略规则新增 `*.out`（覆盖 `coverage.out`、`cpu.out`、`mem.out` 等覆盖率 / profile 产物），六套 harness 一致；除 `go-pkg-harness` 外的五套（`go-harness`、`go-grpc-harness`、`fullstack-harness`、`laravel-harness`、`laravel-fullstack-harness`）另加 `.env`——`go-pkg-harness` 是纯扩展包，没有 `.env` 运行配置。规则仍收敛在 `scripts/install-harness.sh` 的 `_harness_gitignore_patterns` 与 `scripts/install-harness.ps1` 的 `$gitignorePatterns` 单一源头，`sh` / `ps1` 两端行为一致。已被 git 跟踪的文件不受忽略规则影响，仍需 `git rm --cached` 才会退出版本库。
- `go-grpc-harness/templates/grpc-service/.gitignore` 同步补入 `*.out` 与 `.env`。
- 四套带「`.gitignore` 必备条目」清单的入口规则（`fullstack-harness`、`laravel-harness`、`laravel-fullstack-harness`、`go-pkg-harness` 的 `AGENTS.md` / `CLAUDE.md`）清单补入 `*.out`；`go-pkg-harness` 原有的 `coverage.out` 收敛为 `*.out`。README 的忽略规则说明同步更新。
- 三套 smoke 测试的忽略规则基线按模块区分：`tests/setup_smoke_test.sh` 的 `assert_gitignore_baseline` 与 `tests/setup_windows_smoke_test.ps1` 的 `Assert-GitignoreSplit` 改为必须传模块名，对 `go-pkg-harness` 断言 `.gitignore` **不含** `.env` 行、其余模块断言含该行，两端各新增 `assert_line_not_exists` / `Assert-LineNotExists` 精确整行断言；`tests/laravel_package_smoke_test.sh` 的基线补入 `*.out` 与 `.env`。

## [1.8.0] - 2026-08-24

> ⚠ 行为变更：Go 系列 harness 的统一检查入口新增 `go fix -diff`（`make check` / `make tool` / `go-pkg-harness` 发版门禁 / 三份 `ci-sensors.md` 的本地入口）。存量项目重跑门禁时，只要代码里还留着新版本 modernizer 能改写的旧写法（`interface{}`、三段式 for、`wg.Add`/`go`/`wg.Done` 等），检查即失败；先跑 `go fix ./...` 应用改写并复核后再提交。

### Added
- 全部 Go harness（`go-harness`、`go-grpc-harness`、`fullstack-harness`、`go-pkg-harness`）新增 **`go fix -diff` 现代写法门禁**：Go 1.27 的 `go fix` 内置一批改写器（`go tool fix help` 可查清单，go1.27.0 实测注册 26 个 analyzer，含 `errorsastype`、`waitgroupgo`、`rangeint`、`stringsseq`、`omitzero`、`newexpr`、`stditerators`），有输出即失败，把原先靠人工勾选的「现代写法合理使用」变成可执行检查。落点：三份 `ci-sensors.md` 的本地入口、三份 `review-checklist.md` 的对应条目、`grpc-service/Makefile` 的 `check`、`go-pkg-harness` 模板 `Makefile` 的 `tool` 与 `tag`（发版门禁）、`pkg-release-and-supply-chain.md` 的发布前门禁清单。`go fix -diff` 在无差异时退出 0、有差异时退出 1 并打印补丁，无包可查时与 `go vet` 同样退出 1，不引入比既有门禁更严的失败模式。
- `go-pkg-harness/guides/pkg-generics.md` 新增「泛型方法（Go 1.27）」一节：方法可自带类型参数，并写明两条编译器强制的使用约束——接口方法不能带类型参数（需要接口抽象时改用包级泛型函数），方法值必须先实例化（`s.GetAs[int]` 合法，`s.GetAs` 报 `cannot use generic function ... without instantiation`）。
- 三份 `ci-sensors.md` 新增「Go 版本升级核对」：升大版本时依次核对 `go fix -diff`、GODEBUG 兼容开关、`go mod tidy -diff` / `vet` / race 测试、`govulncheck`。Go 1.27 已移除 `asynctimerchan`、`tlsrsakex`、`tls10server`、`tls3des`、`x509keypairleaf`、`gotypesalias`、`tlsunsafeekm`，仍在设置这些开关的项目升级前要先改回标准行为。
- 各 Go harness 技术栈新增 UUID 选型：用标准库 `uuid` 包（Go 1.27 起提供，RFC 9562），`uuid.New()` 用于通用场景，`uuid.NewV7()` 生成时间有序 ID 适合作数据库主键。

### Fixed
- **`go-grpc-harness` 的 `AGENTS.md` 与 `CLAUDE.md` 从未进入版本库**，clone 出来的仓库跑 `go-grpc-harness/setup.sh` 会直接失败（`✗ 错误: 找不到 .../go-grpc-harness/CLAUDE.md`），该 harness 对本机之外的所有人都不可用。根因是本仓库 `.git/info/exclude` 里无斜杠的 `AGENTS.md` / `CLAUDE.md` 规则会匹配任意层级的同名文件；其余五套的同名文件在该规则生效前就已被跟踪，故不受影响，只有后加入的 gRPC 套被挡在库外。两个文件已纳入版本库，`tests/setup_smoke_test.sh` 新增 `assert_entry_files_tracked`：逐套校验入口文件确实被 git 跟踪，缺失即报错。
- `go-grpc-harness` 此前不在 `scripts/sync-claude-from-agents.sh` 的模块列表里，`CLAUDE.md` 与 `AGENTS.md` 只能手工对齐、CI 的 `--check` 也覆盖不到；现已纳入同步。同时纳入 CI 的 `bash -n`、`shellcheck`、PSScriptAnalyzer 检查，纳入冒烟测试的 guide 引用校验与完整安装场景，并在 README 补上包清单、仓库目录树、场景 F（含 `scaffold.sh` 脚手架用法）、全局 Skill 一览与核心差异表。
- `scripts/sync-claude-from-agents.sh` 渲染 `CLAUDE.md` 时会丢掉 `AGENTS.md` 的项目引言（如「本项目使用 Go 1.27 + Gin + GORM ...」），与文件自称的「与 `AGENTS.md` 应保持同级完整」不符。现在引言会被承接，仅排除 Codex 专属提示行；六套 `CLAUDE.md` 随之补回各自的引言。
- `tests/laravel_package_smoke_test.sh` 的忽略规则断言停留在 1.7.0 之前：夹具目录没有 `git init`，却断言 `.gitignore` 含 `.harness/`、`findings.md` 等——这些规则在 1.7.0 已迁往 `.git/info/exclude`，非 git 仓库下更是整段跳过，测试因此长期失败。现补上 `git init`，并改为与 `tests/setup_smoke_test.sh` 同一份基线：`.gitignore` 只校验通用产物且断言不含本地工具规则，`.git/info/exclude` 校验完整的 15 条本地忽略规则。

### Changed
- Go 版本基线由 1.26 提升到 1.27：四个 Go harness 的 `AGENTS.md` / `CLAUDE.md` / 审查清单，以及 `grpc-service` 模板的 `go.mod`（`go 1.26.4` → `go 1.27.0`，模板在 1.27 下 `build` / `vet` / `go fix -diff` / `go test -race` / `go mod tidy -diff` 全部通过）。技术栈的现代特性清单补入泛型方法、`errors.AsType`、`WaitGroup.Go`、`new(expr)`。
- 三份 `testing-and-validation.md` 补入 Go 1.27 测试 API：HTTP 桩优先 `httptest.NewTestServer(t, handler)`（随测试自动关闭，默认走内存网络，`srv.URL` 是 `http://example.com`，请求必须经 `srv.Client()` 发出）；定时/超时逻辑放进 `synctest.Test`，用 `synctest.Sleep(d)` 推进假时钟而非真实 `time.Sleep`。`go-pkg-harness/guides/pkg-testing.md` 的 `synctest` 说明同步补充 `Sleep`。
- `go-pkg-harness/guides/pkg-review.md` 的日志检查项由「用 `slog` 替代 `log`」改为「需要日志时用 `github.com/gtkit/logger`」，与其余 harness 禁用 `log/slog` 的规则对齐。

## [1.7.0] - 2026-08-03

> ⚠ 行为变更：setup 生成的忽略规则改为**分两处**落地——通用产物（`.idea/`、`.vscode/`、`.DS_Store`、`*.log`）留在 `.gitignore`；本地工具与 Agent 运行产物（`.harness/`、`CLAUDE.md`、`AGENTS.md`、`.claude/`、`.codex/`、`openspec/`、`tools/`、计划文件等）改写进 `.git/info/exclude`。老项目重跑 setup 会自动把这些规则从 `.gitignore` 剔除并迁移到 `.git/info/exclude`（业务自定义规则保持不动）。

### Added
- 全部 harness（`go-harness`、`go-grpc-harness`、`fullstack-harness`、`go-pkg-harness`、`laravel-harness`、`laravel-fullstack-harness`）的入口规则（`AGENTS.md` / `CLAUDE.md`）新增「本机容器与镜像纪律（铁律）」一节：需要容器时先用 `docker images` / `docker ps -a` 查本机，已有镜像与容器直接复用（停止的容器 `docker start`，不新建同类容器、不换端口再起一份），不擅自 `docker pull` 其他 tag；本机缺失时先向用户说明缺什么、准备用哪个 tag 并取得同意；`docker run`、`docker compose up`、testcontainers、Laravel Sail、Makefile / 脚本封装的容器命令等隐式拉取路径同样受限。两套 smoke 测试新增对应断言。

### Changed
- `go-pkg-harness` 生成 `version.go` 时，package 名改为**优先沿用目录内既有 `.go` 文件声明的 package 名**（同目录 package 名必须一致，否则编译失败）；目录里没有其它 Go 文件时按目录名推导，**横线直接去掉**（`lenovo-pay` → `package lenovopay`）。此前带横线的目录会被判为非法 package 名而整个跳过 `version.go`，现在能正常生成。横线去掉而非换成下划线，是因为 Go 包名不用下划线——`lenovo_pay` 会被 staticcheck 判为 `should not use underscores in package names`（ST1003）。转换后仍不合法（以数字开头等）或撞 Go 关键字时保持跳过并提示。`sh` / `ps1` 两端行为一致，两套 smoke 测试新增带横线目录、沿用既有 package 名和 `HARNESS_FORCE_PROJECT_FILES=1` 纠正错误 package 名的用例，README 场景 C 与 `guides/pkg-structure.md` 同步补充 `Makefile` / `version.go` 产物与 package 命名规则说明。
- `go-pkg-harness` 的 `Makefile` 模板发版流程改为**两步发布**，并补齐此前完全缺失的发版门禁。新增 `release-patch` / `release-minor` 语义化入口；`tag` 目标承载完整门禁——工作区干净检查、`git diff --check` 空白检查（上一个 tag..HEAD）、`go mod tidy -diff`、`go vet`、`golangci-lint`、`gofumpt` 只读检查、race 测试、可选 `EXTRA_TEST_TARGET`、覆盖率下限、benchmark、`govulncheck`、`gosec`——全部通过后才自增 `version.go` 的 `Version`、提交、打附注标签并推主干，**标签留在本地**；新增 `push-tag` 在远端 CI 全绿后发布标签，它核对该 commit 的 GitHub check-runs 结论，未全绿或查不到记录一律拒绝推送（已人工确认时用 `SKIP_CI_CHECK=1`）。原先 `tag` 目标没有任何门禁，且一步推完 commit 与标签——标签一旦被 Go module proxy 抓取即永久不可变，删除或覆盖都收不回来，来不及等远端 CI 结果。`BUMP` 只接受 `patch` / `minor`，传 `major` 明确拒绝并指向 MINOR 路径（只 bump tag 而不改 module path 是错误发布）。`REQUIRE_CHANGELOG=1`（默认）要求 `CHANGELOG.md` 已有 `## [vX.Y.Z] - YYYY-MM-DD` 条目，脚本把该条目正文写进 tag message。发版阈值按包可覆盖：`BUMP`、`RELEASE_REMOTE`、`COVERAGE_MIN`、`REQUIRE_CHANGELOG`、`EXTRA_TEST_TARGET`。
- `go-pkg-harness` 的 `make tool` 改为只读静态检查：发现未按 `gofumpt` 格式化的文件时打印清单并失败，不再就地改写代码；写文件的格式化移到新目标 `make fmt`。`version.go` 模板注释与 `AGENTS.md` / `CLAUDE.md` / `guides/pkg-release-and-supply-chain.md` / README 的发版指引同步指向 `make release-patch` / `make release-minor` / `make push-tag`。两套 smoke 测试新增发版入口、门禁配置项、`tag` 目标不推标签（两步发布不变量）和「`gofumpt -l -w` 只出现在 `fmt`」的断言。
- setup 生成的忽略规则由「全部写进 `.gitignore`」改为**按性质分流**：通用构建 / 编辑器 / OS 产物留在 `.gitignore`（可入库），本地工具与 Agent 运行产物（`.harness/`、`CLAUDE.md`、`AGENTS.md`、`.claude/`、`.codex/`、`.agents/`、`openspec/`、`.openspec-auto*/`、`tools/`、`.learnings/`、`findings.md`、`progress.md`、`task_plan.md`）改写进 `.git/info/exclude`（仅本地、绝不入库）。目的：避免忽略规则本身泄露「本项目使用了 AI 工具」。`sh` / `ps1` 两端模式串保持一致，`.git/info/exclude` 路径经 `git rev-parse --git-path` 解析以兼容 worktree / submodule；非 git 仓库时跳过并提示先 `git init`。README「日常使用」「Git 提交建议」两节与 CHANGELOG 同步。
- setup 重跑时对存量 `.gitignore` 做**迁移清理**：精确剔除旧版本误写入的本地工具规则与旧 `# Harness:` 标题，迁移到 `.git/info/exclude`，业务自定义规则与通用产物原样保留。两套 smoke 测试新增专门的迁移用例与 `.git/info/exclude` 断言，并为夹具补 `git init`。

## [1.6.0] - 2026-07-03

### Added
- 新增 `go-grpc-harness`：面向 grpc-go + buf + protovalidate 技术栈的 gRPC 微服务 harness，含服务模板、基础设施代码与配套规范文档。
- gRPC 服务模板新增 `grpc.health.v1` 健康探针；优雅关闭时先置 `NOT_SERVING`，等待超时后再强制停止。
- gRPC 拦截器链新增 `request_id` 透传，支持请求唯一标识的生成与回写；限流拦截器补齐 streaming 版本，保证流式调用同样受限流约束；protovalidate 校验支持对 stream 消息逐条校验。
- 模板 `Makefile` 新增 `proto-check` 目标，校验 proto 与 pb 产物的一致性，CI 必跑。

### Changed
- gRPC 配置新增优雅关闭等待超时字段（默认 30 秒），避免长请求阻塞进程退出。
- 架构检查脚本新增规则：禁止业务模块依赖 pb / transport 层，落实层次隔离。
- `go-grpc-harness` 规范补充禁止对 pb 产物做任何文本替换的说明——替换会破坏长度前缀并导致 proto 注册 panic；proto 是唯一事实源，文档只指向 proto 文件。

## [1.5.1] - 2026-06-26

### Changed
- `go-harness` 与 `fullstack-harness` 的配置管理方案改为**外置 YAML 文件加载**（`config/env/env.yml`），进程启动时一次性读取并校验；运行环境由配置文件里的 `env` 字段决定（dev / test / prod），不再通过文件名或命令行参数推断，避免环境混淆；敏感配置（密钥、密码、证书）不纳入版本控制，通过外部注入或文件挂载提供。

## [1.5.0] - 2026-06-25

### Added
- 为 `go-harness` 与 `fullstack-harness` 新增 `guides/testing-and-validation.md`，补齐 Go 后端业务服务缺失的测试、回归、race、API 契约和全栈联调验证专项 guide；入口加载表、README 和 smoke 测试同步纳入。
- 为 `go-harness` 与 `fullstack-harness` 新增 `guides/workers-and-scheduling.md`，补齐 Go 后端后台 goroutine、队列消费者、定时任务、outbox、幂等、优雅关闭和可观测性专项约束。
- 为 `go-pkg-harness` 新增 `guides/pkg-release-and-supply-chain.md`，补齐 Go 扩展包发布、SemVer/tag、v2+ module path、依赖治理、`govulncheck`、license 和安全发布专项约束。

### Changed
- `go-harness` 与 `fullstack-harness` 的后端分层改为**模块化分层结构**，细化各层职责与禁止引用规则；新增数据库迁移、缓存、可观测性、CI 传感器的 guide 加载入口；后端检查流程改为优先执行统一的 `make check`。
- 统一编码基线：强调错误包装与现代 Go 特性；API 设计规范明确响应格式、错误码与 handler 标准流程，并禁止 handler 直接操作数据库或触碰底层实现细节。
- 入口规则补充交叉验证与错误记忆的操作指南，强化质量门禁与自检流程。
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
