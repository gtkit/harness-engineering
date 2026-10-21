# apply_patch PreToolUse 漏拦修复方案与实施计划

日期：2026-10-21。需求：用户明确要求修复 harness-engineering 的 apply_patch 漏拦，再用临时项目验证；暂不刷新 gin_api 或任何现有业务项目。另一项上游 Go skills 请求只做差距分析，不安装、新增或同步 skills。

## 事实、范围与兼容契约

- 真实先前证据：/private/tmp/codex-harness-verification-9pid263x/evidence/10-trusted-apply-patch.jsonl 记录合成 fixtures/.git/probe.txt 的 file_change 成功。直接输入同路径 Write 时脚本拒绝，而规范 apply_patch 输入返回 {}。
- 修改前源码 scripts/hooks/pre_tool_use.py 仅分发 Bash 和 Write/Edit/MultiEdit/NotebookEdit；check_file_write 只展开 ~，未按事件 cwd 归一化相对路径或符号链接。两端安装器 matcher 依赖 Write/Edit 别名，没有显式列出 apply_patch。
- 官方事件契约：https://learn.chatgpt.com/docs/hooks：apply_patch 的规范 tool_name 仍为 apply_patch，补丁在 tool_input.command；Edit/Write 是 matcher 别名，不会改写 payload 工具名。该事实与当前本地复现一致。
- 任务开始时源码仓库工作区干净；无根级 AGENTS，遵守已读取的全局规则。存在 docs/ 与 tests/，沿用既有目录。当前 CLI 0.163.0-alpha.11（不同于前次 alpha.10.2），Python 3.13.11；不改版本、不加第三方依赖，保持脚本已有 Python 3.10+ 语法范围。当前未找到 pwsh，PowerShell 真实执行未验证。
- 获准源文件：scripts/hooks/pre_tool_use.py、scripts/install-harness.sh、scripts/install-harness.ps1、README.md、shared/guides/common/ai-safety.md；新增 tests/test_pre_tool_use.py 和本计划 docs/apply-patch-hook-fix-plan.md。safe_update.py 现有解析动态提取注册，不预先修改；仅在相关测试出现真实兼容问题时按既有接口修复，不改业务或目录架构。
- 兼容：拒绝输出沿用 permissionDecision=deny，正常放行沿用 {}；现有 Bash 规则、事件名称、timeout 和其他 hook 注册不变；继续沿用脚本内部异常的既有 fail-open 机制，但可识别 apply_patch 的缺失/无法识别补丁须明确拒绝，不能吞异常后无条件放行。普通项目文件的新增、更新、删除、移动保持可用。

## 实施设计

1. 为规范 apply_patch 分支读取字符串 command。按 Begin/End、Add/Delete/Update/Move to 和带前缀的正文行识别控制头，提取所有源路径和移动目标；不把正文中的伪 header、危险命令或文档内容当成目标。遍历整份补丁再返回决定，任一保护路径命中时整次操作拒绝。无法识别的格式明确拒绝并说明，而不猜测语法。
2. 复用 check_file_write 的保护类别：用户级配置、/etc 与 .git 元数据。路径基于 hook 的实际 cwd（缺失时以项目 ROOT 回落）处理 ~、.、..，同时检查词法与符号链接解析后的路径，防止别名逃逸；只扩展这次文件保护相关语义，不重写 Bash 命令分析。
3. 两端安装器 matcher 显式增加 apply_patch；同步 README 与安全 guide 的覆盖、解析失败及信任前提说明，不宣称完整权限边界。配置名称与默认值均不新增。
4. unittest 使用标准库与临时文件，覆盖真实 payload、四种文件操作及移动两端、多操作整批拒绝、危险词正文不误伤、空/未知补丁、cwd 子目录、绝对/相对/空白路径、..、符号链接、home 前缀相邻路径、旧工具名及 Bash 回归。相关安装/safe_update 校验只在临时夹具运行，不执行实际业务更新。

## 风险、失败处理与回滚

- 解析格式与工具不一致会误拒绝，故只接受有依据的控制头并测试普通补丁；未知格式拒绝需给出原因，不修改工具参数绕过。
- resolve 可受并发文件系统变更影响，本 hook 不是内核权限边界；保留该限制，不声称阻断所有工具或 TOCTOU。
- 保护类别不增加，不把普通项目目录一律拒绝；.git 的词法/解析路径均保护，含合成目录。
- 只在此前已获准的临时 project (/private/tmp/codex-harness-verification-9pid263x/project) 重装修复后的 harness hooks，不强制覆盖定制 AGENTS。原始证据不覆盖，新的测试日志放 /private/tmp/skills-gap-hook-fix-9b_0oq2z/evidence/。
- 按用户既有临时项目信任授权和本次修复验证授权，只在运行验证期间正常登记该精确路径及两条已核对定义 hash，备份配置并在 finally 删除唯一临时块、回读比对；不使用 bypass、不关闭沙箱，不信任其他项目或 foreign hooks。若有并发配置改动保留其内容，只移除本任务块。
- 源回滚：保留修改前文件副本和 SHA256，只回退本任务的 hunks，不使用 reset/clean，不覆盖别人改动。测试失败先记录原始事实并修复本次问题；无法确认解析契约或作用域则停止依赖步骤。

## 阶段步骤与验收

### 阶段 1：方案与复现（已完成：计划回读、旧漏洞证据与 5 个源文件基线已保存）
前置：已读全局规则、源码、旧实测证据、安装器注册及相关测试入口。
步骤：保存本计划到 docs/ 并回读；保存源基线和临时证据目录；只读固定上游技能仓库 commit 做差距分析。
验收：完整范围、依赖、兼容、回滚、后续步骤与用户授权一致；有真实旧 payload 和源码证据。
停止：目标或协作规则无法核实；工作区出现未归属变更。
交付：本计划、源基线、旧漏洞复现。

### 阶段 2：源修复与必要回归（已完成，21 项专项通过；Windows 实际执行未验证）
前置：阶段 1 完成并回读计划/错误记录/用户最新指令。
步骤：实现补丁路径检查和规范工具分发；同步两端 matcher、说明及新增专项测试；运行专项 unittest，相关 safe_update tests 和 Bash setup smoke；PowerShell 可用时核对实际安装，否则明确未验证，不安装运行端。
验收：保护目标拒绝、普通四种操作放行、混合补丁整次拒绝、正文不误伤、旧 Bash/Write 行为回归，安装注册包含规范名且不删除 foreign hooks。记录真实命令、版本、退出码和失败修复。
停止：必须改变无关保护类别、依赖、架构或业务项目；未获准的外部写入。
交付：源 diff、单测与安装证据、计划状态。

### 阶段 3：真实 Codex 临时项目复验（已完成，最终三项通过）
前置：必要回归已通过；仅临时项目更新源脚本/注册并回读哈希；运行端列出两条已启用受信任 hooks。
步骤：新会话以真实 apply_patch 完成普通路径的新增/更新/删除/移动；另用独立安全样本复验先前漏拦的合成 .git 新增和移动目标，并确认被拒绝后所有受影响文件未变化。保留事件日志、stderr、源/目标文件和配置恢复证据；无需重跑与本次代码无关的全部 skills 触发样本。
验收：普通补丁确实成功，受保护补丁由运行端 PreToolUse 明确拒绝，不能把模型自述或沙箱拒绝当成 hook 拒绝；全局配置恢复到此次信任前基线；没有业务项目写入。
停止：网络或认证阻塞、回调不可观测、信任与所核对定义不符；未验证项照实报告。
交付：临时复验报告、日志与哈希。

### 阶段 4：交付（已完成：改动范围、报告及证据已复核）
前置：阶段 2/3 有真实结果。
步骤：只读复核两个仓库的改动范围，更新本计划；交付上游技能差距分析（不擅自实施补充）、hook 变更与实测结论。
验收：未刷新 gin_api/其他业务项目，未同步全局 skills、未提交发布；实际运行与未验证范围清楚。
交付：报告、计划和最终答复。

## 执行记录

以下按发生顺序保留，历史“待执行/进行中”仅表示当时状态；最终状态以阶段标题与末尾验收记录为准。

- 阶段 1 已完成：上游固定 commit 8e899e20ff0cd4dc524af3993e4c62d8ee8c5717，当前实际 46 个 SKILL.md；原始漏洞已由前次真实 file_change 与本次回读确认。5 个待改源文件备份于 /private/tmp/skills-gap-hook-fix-9b_0oq2z/source-before/。
- 读取时曾在 harness cwd 用相对路径请求 go-engineering-governance/SKILL.md，sed 报不存在并退出 1；未创建替代文件，已改用已核实的 /Users/xiaozhaofu/Ai/skills/... 绝对路径核对。防复发：跨仓读取一律使用实际内容源绝对路径。
- command -v pwsh 未找到运行端；不安装。Windows/PowerShell 实际执行待验证，源码 matcher 将同步并回读；Bash 安装与真实 Codex 复验按计划继续。

- 阶段 2 首轮专项 unittest：20 个测试，19 通过、符号链接环用例 1 失败，退出 1。实际 CPython 3.13 非严格 resolve 返回未解析路径而未抛错；实现误把它当成可核对目标，返回 {}。补救：对最深现存路径前缀先做严格解析，环/损坏链接不能伪装成安全新文件；保留测试而不降低保护。相关 safe_update 与 Bash smoke 当时仍在运行，不提前报告通过。
- 上游只读检查曾请求未核实的 references/debugging-tools.md，cat 报不存在；随后按真实文件清单定位，未编造该参考内容。跨仓路径和参考文件必须先列清单再读取。

- 阶段 2 首版修复回归结果：`python3 -B -m unittest discover -s tests -p test_pre_tool_use.py -v` 20/20，退出 0（日志 evidence/hook-unit-final.log）；`PYTHONDONTWRITEBYTECODE=1 python3 -B -m unittest discover -s tests -p test_safe_update.py -v` 25/25，退出 0；`/bin/bash tests/setup_smoke_test.sh` 输出 setup smoke test passed，退出 0。后两条已在本会话真实执行，不补造原始日志。Bash/PowerShell 两端 matcher 与 README/安全 guide 已逐项回读；safe_update.py 现有动态解析兼容，无需改动。
- 安装入口核对曾请求不存在的 go/setup.sh，rg 退出 2；已用 rg --files 得到真实 go-harness/setup.sh 并实际读取。防复发：后续只使用该实际入口，不从模块简称构造路径。
- 阶段 3 前置核对：三处旧全局 go-harness/SKILL.md 均不存在；CODEX_HOME/HARNESS_FORCE_GUIDES/HARNESS_FORCE_PROJECT_FILES 均未设置；临时项目当前无用户级 project trust 表。仅在此前已获准的临时路径运行安装，不触碰业务项目。

- 阶段 3 首轮真实 CLI 三项均完成，退出 0：普通四操作 84.47 秒、受保护新增 76.26 秒、混合移动目标 61.49 秒。两项负例均有运行端 PreToolUse 明确拒绝且夹具快照未变化。用户配置 SHA256 恢复到本次信任前基线 7d451b6386a015c6ca6d824c634975a54b59a334a88278a197c5213fe0ab147e。对应源脚本 SHA256 为 229842414ce576535657d63c37b6c65e0411f5a5afd318773d0eb4bdf477dfe5；这是初版修复的实测，不冒充后续源码结果。
- 源复核补充：已实际读取 OpenAI 官方 parser.rs 与 streaming_parser.rs（https://github.com/openai/codex/blob/main/codex-rs/apply-patch/src/streaming_parser.rs）。控制头会去掉行尾空白，现有提取保留该空白，可能把 `.git ` 或用户配置文件名判成普通文件。这仍属本计划补丁目标解析范围，不新增保护类别、依赖或架构。先补负例并记录结果，再将控制头路径按行尾空白归一化；正文保留原始前缀语义。
- 补充步骤（已获准，待执行）：在现有 tests/test_pre_tool_use.py 增加控制头尾空白的源路径/移动目标回归；相关专项通过后仅向同一临时项目安装最终脚本，最终版真实运行普通四操作与含尾空白保护移动目标的混合补丁。保留首轮证据不覆盖，最终复验另放 evidence/final/；验收和回滚沿用原阶段 2/3 标准。官方 main 源码用于识别解析差异，当前 alpha.11 的真实行为仍以本地复验为准。

- 控制头尾空白负例已真实执行：`python3 -B tests/test_pre_tool_use.py PreToolUseTests.test_control_header_trailing_whitespace_cannot_hide_paths -v`，1 个方法内 7 个失败，退出 1；Add/Delete/Update 的 `.git` 与合成 home/.zshrc 以及 Move to 均错误返回 {}。日志 evidence/trailing-space-before-fix.log。根因为 hook 保留控制头路径尾空白，与官方实际解析语义不同；修复控制头提取，不修改正文或降低测试。

- 补充修复后最终专项：`python3 -B -m unittest discover -s tests -p test_pre_tool_use.py -v` 21/21，退出 0，日志 evidence/hook-unit-complete.log；`git diff --check` 退出 0。控制头尾空白的新负例从失败转为通过，原有测试均保留通过。未重复未变更的 safe_update/安装 smoke；它们前次实际通过的证据仍限于对应范围。
- 最终临时复验仍为已获准阶段 3，证据单独保存 evidence/final/，使用新夹具 fixtures/patch-final 保留首轮夹具。完整执行普通四操作、原始受保护新增和混合移动三项；移动目标使用控制头尾空白的合成 `.git` 文件，专项测试负责准确输入语义，运行端日志和文件快照负责真实回调。当前最终 CLI 三项待验证。

- 阶段 3 最终验收：最终源脚本 SHA256 d587560ede0d48bda026c4436e3e677a08466d40e3fad32b90221518207f3f7d 与临时安装副本一致；Codex CLI 0.163.0-alpha.11 / Python 3.13.11。普通四操作真实完成（102.06 秒）、受保护新增由 PreToolUse 拒绝（84.52 秒）、混合移动由 PreToolUse 拒绝（67.21 秒），三会话均退出 0。两负例均有原生 codex_core::tools::router stderr，且所有受影响夹具前后快照一致，无成功 file_change。尾空白的准确 payload 由最终专项证明，CLI 未导出原始 tool_input，不把提示当成原始调用参数证据。
- 正常临时信任的项目与两条 hook hash 已撤销；恢复及交付前回读配置 SHA256 均为 7d451b6386a015c6ca6d824c634975a54b59a334a88278a197c5213fe0ab147e，与各次即时信任前基线一致。没有 trust bypass 或关闭沙箱。CLI WebSocket 重置后自动回退 HTTP，最终运行均完成，不隐瞒重试也不将其误判成 hook 失败。
- 阶段 4 验收：harness 工作区仅本计划列明 7 个文件有本次改动，skills 内容源工作区干净；无 gin_api/其他业务项目刷新或修改，无全局 skills 同步、提交或发布。PowerShell/Windows 真实执行仍未验证，未安装 pwsh。
- 交付物：/private/tmp/skills-gap-hook-fix-9b_0oq2z/verification-report.md（真实运行、命令、退出码、限制和证据链接）；/private/tmp/skills-gap-hook-fix-9b_0oq2z/skills-gap-analysis.md（固定上游 commit 的 46 项映射与建议，只分析未新增）。源 diff 与新增 tests/test_pre_tool_use.py 保留在当前工作区供复核。
