# Go / TypeScript MCP Harness 方案与实施计划

日期：2026-10-30。最初需求为新增 `go-mcp-harness`，同时考虑 stdio 与 Streamable HTTP，并尽量使用 `github.com/gtkit/*`。用户随后授权修复共享安装元数据，并明确新增独立 `ts-mcp-harness`：Go 可以通过 npm 分发，TS 不使用 Go。授权覆盖规则包、安装/更新机制接入与路径修复、必要测试和文档；不包含安装到业务项目、用户级命令安装、提交或发布。原方案及首次验证保留于下方，补充阶段 5–8 记录最终范围。

## 目标与非目标

- 新增与现有 harness 并列的独立规则包，复用安装器、更新器、公共指南、工作流技能和错误记录机制。
- 统一工具契约、权限、错误、兼容性和测试要求；按项目实际传输加载 stdio 或 Streamable HTTP 指南，也允许项目明确选择两者。
- 在标准库能直接满足需求时保持简单；需要第三方能力时优先核实 gtkit 原生包。协议 SDK、OAuth 与流式传输不得由不适用的库替代。
- 保持原有八套入口、目录、安装 API 和更新格式；不移动业务代码、不生成 MCP 应用骨架、不修改任何业务项目或其依赖。
- 本次不运行 lint、脚本 lint、vet、modern、全量 race、覆盖率或聚合质量门禁，不创建项目副本、worktree、测试沙箱或容器，不启动 OpenSpec 流程。

## 已核实事实

- 原仓库工作目录与 Git 顶层一致；任务开始时 Git 工作区干净，最初存在八套 harness，没有 MCP 专用包。
- `install.sh` 和 `scripts/harness-init.sh` 按实际 `setup.sh` 发现包，无需新增硬编码注册表。
- Bash 入口调用 `scripts/install-harness.sh` 的 `install_harness`，PowerShell 入口调用 `scripts/install-harness.ps1` 的 `Invoke-HarnessSetup`。
- `scripts/safe_update.py` 的 `templates` 从原始文件生成内存中的分发清单，支持包私有指南/技能覆盖公共资源；单纯新增规则包不需要修改更新器。随后发现的元数据路径问题按补充阶段 5 修复。
- `shared-guides.txt` 使用相对资源名；包内同名指南优先。`scripts/sync-claude-from-agents.sh` 和现有 smoke 测试显式列举部分包名，需要接入新包。
- 现有全量 smoke 测试会创建临时项目和隔离用户目录，本轮不执行。只调用无落盘的分发逻辑、原仓库只读 CLI 入口和针对性测试。
- 项目历史错误记录位于 `.learnings/ERRORS.md`；已读取。前置检索误用了不存在的根 `install.ps1`，已记录 `ERR-20261030-001` 并改用实际清单。
- 既有源码依赖/工具链不升级。协议各版本、SDK 支持范围和 gtkit 具体能力在编写对应规则前通过官方材料核对；未核实的版本/API 不写成事实。

## 方案比较与决策

| 候选 | 适配与影响 | 决策 |
|---|---|---|
| 直接套用 Go Web 或 Go 库 harness | 会带入 Gin/GORM 分层或公共库导出 API 约束，MCP 传输与权限规则仍有缺口 | 不采用 |
| stdio 与 HTTP 各建一套 | 重复工具契约、依赖、安全和测试规则，后续易漂移 | 不采用 |
| 一个 Go MCP 包，按任务加载传输指南 | 共用规则单一来源，独立维护传输差异，复用既有分发 API | 采用 |

## 设计与兼容约束

1. **入口与路由**：`AGENTS.md` 为新包规则内容源；`CLAUDE.md` 按既有转换格式生成，正文一致。写清原项目操作、先计划、权限边界、受控检查、禁止真实本机路径、依赖版本与命名、按需技能和错误记录纪律。
2. **业务边界**：同一工具的参数、结果和副作用在两种传输中一致；仅运行装配、认证和连接管理因传输不同。保留项目既有布局，不强制 Gin、GORM、数据库、Redis、Node 或同时开启双传输。
3. **协议与安全**：锁定 SDK/协议/客户端组合；分别描述旧协议与新协议的握手、会话、SSE、取消与兼容边界。覆盖 tools/resources/prompts、schema、错误分层、注解不等于授权、输入与输出限制、文件与外部命令、SSRF、凭据、认证和跨用户资源隔离。
4. **运行**：本地 stdio 的输出纯净、进程退出、EOF、子进程回收；HTTP 的监听范围、Origin、认证、请求大小、流式刷新、代理缓冲、超时、关闭、限流、慢客户端和多副本状态策略。容量参数必须来自业务输入或测量，不编造通用性能承诺。
5. **依赖**：标准库直接能力 → 已核实适用的 gtkit 原生能力 → 当前项目已锁定/官方或成熟协议生态。记录适用条件、真实包名、模块主版本、输出去向和失败语义；不写未经证实的函数调用或“最新”版本号。日志不能污染 stdio stdout，JSON 替换不能改变协议语义。
6. **验收与分发**：区分工具功能、传输协议、真实客户端、真实外部依赖和安装/发布证据；覆盖取消、部分成功、重复调用、越权和资源耗尽。文档/规则与可执行程序分别验收；没有客户端实测时不宣称兼容。

## 预计文件范围

- 新增 `go-mcp-harness/{AGENTS.md,CLAUDE.md,setup.sh,setup.ps1,setup.bat,shared-guides.txt}`。
- 新增 `go-mcp-harness/guides/` 下的架构、依赖、协议契约、stdio、Streamable HTTP、安全、可观测、测试、分发、审查、Go 版本和技能路由指南；`rules/` 下的对应按需入口。
- 更新 `scripts/sync-claude-from-agents.sh` 包名列表；`install.sh`、`scripts/harness-init.sh` 的包类型说明，保持执行 API。
- 更新 `skills/harness-doctor/references/skill-dependencies.md` 和 `skills/harness-review/SKILL.md` 的 MCP 路由，不触发诊断或加载安装。
- 新增 `tests/test_go_mcp_harness.py`，更新 `tests/setup_smoke_test.sh`、`tests/setup_windows_smoke_test.ps1` 的新包覆盖；接入现有 `.github/workflows/ci.yml`，本轮不运行该工作流。
- 更新 `README.md`、`CHANGELOG.md` 和本计划；错误记录仅记录本轮真实错误。不修改其他仓库。
- 源模板跟踪：已有本地排除规则会忽略任意层级的 `AGENTS.md`/`CLAUDE.md`。在仓库 `.gitignore` 仅为新包的这两个源文件增加精确反忽略规则，使后续正常 Git 操作可见；不修改 Git 元数据或暂存区。

## 风险、失败处理与回滚

- 协议版本漂移：写明官方来源与适用版本；SDK 未确认支持时停在兼容性核对，不凭协议文档推定 SDK 已实现。
- gtkit 与传输冲突：逐包核对；不为优先选型牺牲 stdout 纯净、认证、schema 或取消语义。MCP SDK 无已核实 gtkit 替代时保留适用 SDK。
- 共享规则冲突：入口明确用户授权优先，技能/门禁不扩大当前任务。只增加 MCP 路由，不改其他包架构。
- 本机路径泄露：新规则、计划、测试记录与分发清单仅保留相对路径/占位符；Python 使用禁止字节码落盘方式运行。
- 安装测试越界：本轮不运行创建临时项目、克隆或用户级文件的脚本；真实首装、Windows、客户端运行保持未验证。新增分发测试仅在内存使用原始文件。
- 回滚：按最终文件清单移除本轮新增包与测试，逆向撤销本轮接入/文档变更；保留其他用户变更与真实错误记录。不使用强制重置，不改已安装项目。

## 分阶段实施与验收

| 阶段/步骤 | 前置条件 | 具体工作 | 检查及可复核证据 | 停止条件 | 交付物/状态 |
|---|---|---|---|---|---|
| 0. 核对与计划 | 原项目确认、规则与错误记录已读取 | 明确范围、完整方案落盘并回读；核对外部规范与依赖来源 | 本计划、真实读取记录与来源链接 | 原项目或关键来源无法核实 | 已完成，进入已授权实施 |
| 1. 新规则包 | 阶段 0 完成 | 先写通用入口与指南，再写传输/安全/依赖/测试/分发专项和规则路由；只生成新包的 CLAUDE | 回读新增文件；两个入口正文一致，指南引用闭合，无本机真实路径 | 协议/依赖冲突尚未解决，或需要改变业务目录 | 已完成：13 篇私有指南、6 个路径规则和双端入口 |
| 2. 分发接入 | 新包结构明确 | 薄包装调用现有安装器；补充同步清单、技能路由、文档和 CI/测试包列表 | 无业务/用户级写入的包发现与内存分发结果；原八套分发结果比较 | 需要改共享安装/更新 API 或引入外部依赖 | 原定接入完成；追加元数据修复已获准并在阶段 5 完成 |
| 3. 针对性验证 | 阶段 1、2 已完成 | 运行标准库 Python 分发测试及只读命令帮助；核对 Windows 包装内容与项目相对引用 | 命令、运行环境、退出码、用例数量与覆盖边界记录于下方 | 测试失败先记录并修复；禁止越界进入质量门禁/临时项目安装 | 已完成内存分发/命令发现验证；真实安装与 Windows 未验证 |
| 4. 回读交付 | 所有获准功能完成 | 回读实际原仓库文件、更新计划状态/未验证项，说明使用入口 | 文件清单、实际功能测试结果；质量检查须单独授权 | 不提交/发布/安装，不把静态/内存验证说成真实客户端验证 | 原定源规则包完成；后续交付见阶段 8 |

## 首次 Go 规则包执行结果（补充实施前）

规则包与原定接入完成。已读取原八套包的内存分发结果，保存本轮会话中的文件摘要并完成接入后比较；未生成项目副本或安装产物。

来源（2026-10-30 核对）：[旧版传输](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports)、[新版 Streamable HTTP](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http)、[授权](https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization)、[官方 Go SDK](https://github.com/modelcontextprotocol/go-sdk)、[MCP-Go](https://github.com/mark3labs/mcp-go)，以及 [logger](https://github.com/gtkit/logger)、[json](https://github.com/gtkit/json)、[golimit](https://github.com/gtkit/golimit)、[gojwt](https://github.com/gtkit/gojwt)、[redisx](https://github.com/gtkit/redisx)、[ormx](https://github.com/gtkit/ormx) 的维护者文档。

新增指南已使用私有 `acceptance-gates.md`，使 Node 分发脚本不被自动判为浏览器前端；继续复用公共 AI 行为安全、提交规范和错误模板。公共指南/技能的默认流程均服从入口中的任务范围、原目录和检查授权约束。

### 实际验证

- 环境：本机 Python 3.15.2、Bash 3.2.57；直接读取原仓库源码，禁止 Python 字节码落盘。
- 命令：`python3 -B tests/test_go_mcp_harness.py`，退出码 0，6 项通过（0.298 秒）。覆盖双传输与私有验收指南分发、指南引用、AGENTS/CLAUDE 正文一致、源入口未被忽略、双端技能/路径规则、无业务文件/本机目录的内存分发清单和 CLI 帮助/未知包处理。
- 原八套包前后逐文件摘要比较：变化仅为新增 MCP 路由的 `harness-review/SKILL.md` 和 `harness-doctor/references/skill-dependencies.md`，分别分发到两个客户端；各包入口/指南/其他资产无变化。
- 已回读本轮 39 个新增/修改文件（含本地错误记录），新包共 25 个文件；本轮涉及内容未发现真实本机目录或用户名。README 已披露共享安装元数据的已知限制；未以源文件或内存分发结果代替实际安装验收。
- 未执行：首装/落盘更新、Windows 原生运行、MCP 应用或真实客户端、全量 smoke、lint/脚本 lint/vet/modern/race/覆盖率、Docker、全局安装、提交和发布。

### 后续已授权修复的发现：共享安装元数据

接入回读时发现既有 Bash/PowerShell 首装把实际源码路径写入 `.harness/VERSION`，共享更新器把 `source_path` 写入 `.harness/update-base.json` 并再次写回版本文件。新包的内存资产不含本机路径，但这不能证明实际安装元数据符合规则。问题记录为 `ERR-20261030-002`；本轮没有安装产物需要清理。

用户随后明确授权一并修复共享链路，并要求保持接口和更新兼容。新增要求为两套独立规则包：`go-mcp-harness` 允许使用 npm 分发 Go 程序；`ts-mcp-harness` 用 TypeScript 实现，不引入 Go。原阶段 0–4 保留历史记录，后续按以下补充阶段实施。

## 已授权补充方案（2026-10-30）

### 目标、事实与边界

- 保留 `go-mcp-harness` 名称、路径和现有入口，新增并列 `ts-mcp-harness`，不建立通用替代入口，不搬迁现有模块或公共指南。两套都支持按需选择 stdio / Streamable HTTP。
- Go 的 npm 包只承担分发/启动职责：区分开发机 Go 工具链与安装端预编译二进制，不默认要求最终用户安装 Go，不把 npm 包误判为 TS MCP 服务。gtkit 偏好仍只用于 Go。
- TS 包提供独立入口、13 篇指南、6 个路径规则与三种 setup 包装；覆盖运行时/锁文件/SDK 版本、ESM/CJS、运行时 schema、AbortSignal、事件循环/流背压、npm bin/产物/安装脚本、双传输和安全验收。不要求 Go、gtkit 或 Go 质量工具。
- 沿用 Python/Bash/PowerShell 现有依赖，不安装新运行时或 SDK。TS/Node/npm 规则以官方文档和项目锁定版本为准，不指定未经项目核实的固定版本。
- 已确认更新器从命令参数取得模板源，合并基线只读取 schema/component/kind/files，旧 `source_path` 不参与三方合并。SessionStart 则依赖旧 `source-path` 进行可选版本提醒，需要提供运行时定位方式。
- 现有本地回归含跨仓库更新器逐字一致断言。只修改本源仓库：限定例外为 harness 元数据生成函数，继续对公共合并/事务/所有权代码做一致性断言；不修改另一个仓库或 OpenSpec 运行流程。

### 元数据与兼容设计

1. Bash 与 PowerShell 首装不再写 `source-path`。Python 快照保留 schema 1 和既有字段结构，`source_path` 写为 `null`，不持久化运行时源码目录。
2. 安全更新继续接受包含旧路径的基线与版本文件。成功更新时移除 VERSION 的 `source-path`，基线的 `source_path` 规范化为 `null`；保留其他版本信息、自定义字段、权限、三方合并、冲突停止和失败回滚语义。`--dry-run` 不迁移文件；冲突/失败不能伪称已经清理。
3. SessionStart 新增可选进程环境变量 `HARNESS_SOURCE_DIR`，仅用于定位模板仓库和读取 HEAD，不写入项目。非空时优先使用；未提供时兼容旧 VERSION 字段；两者都缺失时仅跳过模板新旧提醒，不影响错误记忆注入或显式 update/refresh。无效显式值不猜测其他路径。
4. 不扫描或更改已安装业务项目、历史备份或唯一用户数据。备份继续保存原始字节以支持失败恢复；本轮仅验证项目 VERSION/更新基线的新写入行为，不宣称历史副本已经清理。

### 文件与风险

- 修改 `scripts/install-harness.sh`、`scripts/install-harness.ps1`、`scripts/safe_update.py` 的元数据生成，以及 `scripts/hooks/session_start.py` 的模板定位；命令名称、参数、退出码和组件目录不变。
- 新增 `ts-mcp-harness/` 对应入口/指南/规则；只补充 Go 包的 npm 分发边界及相关规则路由。继续按包维护各自语言内容，避免加载错语言规则。
- 修改已涉及的 README、CHANGELOG、同步/发现说明、共享技能路由、`.gitignore`、CI 与 smoke 包列表；新增 `tests/test_mcp_metadata.py`，扩展 `tests/test_go_mcp_harness.py` 覆盖两套包，调整 `tests/test_go_harness_local.py` 的一致性边界。实际不运行会创建项目副本的 smoke/integration。
- 风险：无运行时源目录的新安装不再自动判断模板新旧，README 明确可选环境变量和显式 refresh；TS 文档不得把类型擦除视作类型检查，不得把 npm 安装成功视作 MCP 兼容。
- 回滚：只逆向撤销本次补充文件/改动，保留原 Go 包及用户改动；旧更新器仍能读取 schema 1 的 null 字段。恢复旧生成器会重新记录路径，不作为推荐运行状态。失败更新按既有事务恢复原字节，不删除历史证据。

### 补充实施与验收

| 阶段/步骤 | 前置条件 | 具体改动 | 检查方法与证据 | 停止条件 | 状态/交付物 |
|---|---|---|---|---|---|
| 5. 共享元数据修复 | 用户已授权；本补充方案落盘回读 | 首装去路径、快照 null、更新移除旧字段、SessionStart 运行时定位；同步配置说明 | 实际 Bash 元数据输出；Python 内存文件替身覆盖旧字段迁移、dry-run、二次更新、冲突、失败恢复；源代码回读 | 需要更改命令接口、无法保持原事务或需写其他仓库 | 已完成代码与针对性验证；Windows 原生运行未验证 |
| 6. 双语言规则包 | 阶段 5 范围明确；官方资料核实 | 新增独立 TS 包；完善 Go/npm 边界；同步分发、技能和说明 | 双入口正文一致、所有指南引用可分发、语言与 npm 职责隔离、命令帮助发现 | TS 内容需要引入 Go，或必须移动现有结构 | 已完成：两包各 25 个文件，独立入口、13 篇指南与 6 个路径规则 |
| 7. 针对性功能验证 | 补充代码/规则完成 | 运行元数据与双包分发 unittest；复核受影响公共代码一致性 | 记录环境、命令、退出码、通过/跳过数量；不安装到真实业务项目，不生成项目副本 | 失败先如实记录；未获质量检查授权不越界 | 已完成，26 项通过、无失败/跳过；证据如下 |
| 8. 回读交付 | 获准功能完成且证据可复核 | 回读原项目文件、清理本轮实际本机路径、更新计划与错误状态、交付两套入口 | 区分内存事务、真实 Bash 输出、未执行的 Windows/实际安装/客户端证据 | 不提交、发布、安装，不恢复无关任务 | 已完成原目录回读；后续获准的 Bash 语法检查通过，ShellCheck 缺失未运行 |

验收不运行 lint、脚本 lint、vet、modern、全量 race、覆盖率或聚合质量门禁；这些检查在功能完成后单独询问。元数据测试使用内存替身并明确不能证明真实磁盘故障原子性，Windows 无运行端时仅回读、不宣称实测。

## 补充阶段最终结果

- 两套规则分别以 Go / TypeScript 为服务实现语言，均有 stdio / Streamable HTTP 指南。Go 的 npm 层限于实际分发/启动需求，优先评估 gtkit；TS 使用自身 SDK/运行时/依赖规则，不引入 Go。未创建通用替代入口，未移动现有模块。
- Bash/PowerShell 首装删除路径写入；新快照保留 schema 1 的 `source_path: null`；旧基线和 VERSION 可继续读取，成功更新移除路径，冲突与失败不修改原状态。SessionStart 的 `HARNESS_SOURCE_DIR` 默认/回落及两种 shell 示例已同步 README，并将提示更新为真实安全更新命令。
- 新包已接入发现/同步、Bash/Windows smoke 名单、技能路由和 CI 测试入口。只修改本源仓库；公共合并/事务/所有权代码的一致性断言保留，harness 元数据两个函数的差异由针对性测试覆盖。

### 本轮真实测试

环境：本机 Python 3.15.2、Bash 3.2.57；本轮再次核对 Python 与命令可用性，Bash 版本沿用本会话前次证据。`pwsh` / `powershell` 均未找到，未安装运行端。所有 Python 调用使用 `-B`，未留下字节码产物。

| 命令 | 退出码 | 结果 |
|---|---|---|
| `python3 -B tests/test_go_mcp_harness.py` | 0 | 14 项通过，0.346 秒；双包指南/入口/技能/路径规则、语言隔离、npm 范围与只读 CLI 发现 |
| `python3 -B tests/test_mcp_metadata.py` | 0 | 11 项通过，0.199 秒；真实源码快照与 Bash 格式化输出、内存旧基线迁移/重复更新/预览/冲突/失败恢复、源路径回落及错误记忆 |
| `PYTHONPATH=tests python3 -B -m unittest test_go_harness_local.DistributionTests.test_update_engines_share_merge_and_transaction_contract -v` | 0 | 1 项通过，0.040 秒；读取对端源码比较共同的合并/事务/所有权代码，没有执行对端安装器 |

以上共 26 项，通过 26、失败 0、跳过 0。原八套前后摘要对比是首次 Go 包接入阶段的历史证据，不能用于宣称本次共享 hook/元数据逻辑未变化。

### 回读与未验证范围

已在原仓库回读本任务 70 个新增/修改文件（含错误记录）；两包各 25 个文件。此次实际读取内容未发现真实本机目录或用户名，未写入业务项目、用户级目录或项目副本。

未运行全量 smoke、实际首装/落盘更新、Windows 运行、真实 MCP 应用/客户端、npm 打包/安装、Docker、lint/脚本 lint/vet/modern/全量 race/覆盖率；未提交或发布。内存事务测试不能证明真实磁盘故障、跨平台权限或真实客户端兼容。现存业务项目及历史备份没有自动清理。

补充官方依据（2026-10-30 核对）：[TypeScript SDK](https://github.com/modelcontextprotocol/typescript-sdk)、[Node 类型擦除](https://nodejs.org/api/typescript.html)、[npm 包元数据与 bin](https://docs.npmjs.com/cli/v11/configuring-npm/package-json/)、[TypeScript 配置](https://www.typescriptlang.org/tsconfig/)。这些材料用于编写版本敏感规则，未据此自动升级或安装依赖。

## 追加质量检查（2026-10-30，已单独授权）

用户明确要求运行本轮改动 Shell 脚本的 Bash 语法与 ShellCheck 检查，不安装缺失工具。范围由 Git 已修改与新增的 `.sh` 文件确定，共 7 个；未扩展到其他质量门禁或业务测试。

环境：本机 Bash 3.2.57。逐文件执行 `/bin/bash -n <下表文件>`，只解析语法，不执行脚本业务逻辑：

| 文件 | 退出码 | 结果 |
|---|---|---|
| `install.sh` | 0 | 通过 |
| `scripts/harness-init.sh` | 0 | 通过 |
| `scripts/install-harness.sh` | 0 | 通过 |
| `scripts/sync-claude-from-agents.sh` | 0 | 通过 |
| `tests/setup_smoke_test.sh` | 0 | 通过 |
| `go-mcp-harness/setup.sh` | 0 | 通过 |
| `ts-mcp-harness/setup.sh` | 0 | 通过 |

ShellCheck：`command -v shellcheck` 未找到 PATH 中的可执行工具，未执行、未标通过，也未安装工具。

首次检查包装命令因默认 zsh 的只读变量 `status` 冲突而退出 1，尚未运行目标检查；已记录 `ERR-20261030-003`，改用任务专属变量和显式 Bash 后重跑，最终包装命令退出 0。未改动被检查脚本，未重跑功能测试，未安装、提交或发布。
