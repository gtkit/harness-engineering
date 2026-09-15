# CLAUDE.md

> Claude Code 项目级完整规则入口。
> 为避免依赖全局厚 skill，本文件承载完整项目规则；与 `AGENTS.md` 应保持同级完整。
> Go 扩展包（第三方库）开发专用。库代码标准比业务代码更高。

---
## 行为纪律

1. **禁止编造**：不确定的标准库 API、泛型语法不写，问用户。
2. **禁止猜测**：不说"应该支持"、"大概是"。
3. **严格按结构输出**：只写要求的功能，不自作主张加 feature。
4. **库代码零容忍**：不留 TODO、不留 panic、不留未处理的 error。
5. **多解陈列**：指令存在多种合理解释时，并列呈现给用户选择，不默默择一实现。
6. **反推更简方案**：发现比用户原方案更简单的做法时，主动提出并说明权衡，不默默按原方案堆代码。
7. **量化自检**：写完自问"senior 会不会觉得过度复杂？200 行能否压到 50 行？"；库导出面积能小则小，单次使用的内部代码不写抽象 / 配置项 / 扩展点。

## 自主执行边界

**直接做，不用问**：读任何文件；改本次任务范围内的代码与测试；跑 build / vet / lint / 测试 / 架构传感器；修复本次改动引入的失败并重跑相关检查；`docker ps` / `docker images` 查看本机状态；按错误记忆规则追加 `.harness/error-journal.md`。

**先停下问用户**：拉镜像、新建容器（细则见「本机容器与镜像纪律」）；安装全局工具或改用户级配置；`git commit` / `push` / 打 tag；删除或改写非本次任务产生的文件、数据、迁移；任何触达生产或外部系统的操作；需求有多种读法且会导向不同实现。

**默认完成标准**（用户没另说时）：编译通过；提交前检查的门禁全部通过；受影响的测试实际跑过；行为验证过——接口发过请求看响应、任务或消费者实际触发过、页面打开点过；汇报里写清跑了什么、结果如何，做不下去就说明卡在哪。只讨论方案、只做研究、只出计划时不改代码；计划批准前不进入实现。

## 技术栈

- Go 1.27，**必须使用现代语法**：泛型、泛型方法、`errors.AsType`、`sync.WaitGroup.Go`、`new(expr)`、range-over-int / range-over-func、`iter.Seq` 迭代器、`slices`/`maps`/`cmp`、`omitzero` tag；落地写法与实测约束见 `.harness/guides/go-modern.md`，门禁是 `go fix -diff ./...` 无输出
- UUID 用标准库 `uuid` 包：`uuid.New()` 用于通用场景，`uuid.NewV7()` 生成时间有序 ID（适合作数据库主键）；`uuid.Nil()` 是函数不是变量，导出 UUID 类型的入库与 JSON 约束见 `.harness/guides/go-modern.md`
- 零外部依赖优先，能用标准库的绝不引入第三方；JSON 场景按 `pkg-structure.md` 的 JSON 选择规则处理
- **第三方包选型顺序**：标准库 → `github.com/gtkit/*` 下的原生包（如 `gtkit/logger`、`gtkit/json`、`gtkit/go-pay`，其中 `gtkit/go-pay` 通过 `paymgr` 提供跨渠道统一抽象，非轻封装）→ 业界事实标准（如 `redis/go-redis`、`gorm/gorm`、`gin-gonic/gin`，gtkit 下无原生包或同名包仅是轻封装时可直连）→ 其他第三方
- **JSON 默认优先 `github.com/gtkit/json` 或 `github.com/gtkit/json/v2`；纯零依赖公共库允许使用 `encoding/json`，但必须记录取舍原因**

## Logic 四步

1. **理解需求**：包解决什么问题？给谁用？核心 API？是否需要并发安全/泛型？
2. **提取信息**：加载对应 Guide
3. **按结构组织**：按 `pkg-structure.md` 的目录模板
4. **检查合规**：传感器 + 自审 + 合规摘要

## 工作流 skills（Claude Code 与 Codex 同一套）

setup 把六个工作流 skill 各装一份到 `.claude/skills/harness-*/`（Claude Code）和 `.agents/skills/harness-*/`（Codex），内容完全相同：

| Claude Code | Codex | 用途 |
|-------------|-------|------|
| `/harness-doctor` | `$harness-doctor` | 诊断 harness、OpenSpec、skills 与可选 MCP 状态 |
| `/harness-init-openspec` | `$harness-init-openspec` | 初始化或验证 OpenSpec（优先复用 openspec-auto） |
| `/harness-research <需求>` | `$harness-research <需求>` | 只做需求研究，输出约束集、风险、开放问题和可验证成功标准，不写代码 |
| `/harness-plan` | `$harness-plan` | 基于已批准约束集生成零决策计划，不写代码 |
| `/harness-implement` | `$harness-implement` | 只按已批准计划分阶段实现并验证 |
| `/harness-review` | `$harness-review` | 按 harness 质量门禁审查当前 diff |

执行规则：

1. 被显式调用或任务明显匹配某个 skill 的 description 时，读取并严格按该 `SKILL.md` 执行。
2. 简单小改动不强制走完整 RPI；复杂、高风险、跨模块任务优先使用 `research → plan → implement → review`。
3. `research` 和 `plan` 阶段不得修改代码；`implement` 必须基于用户已批准的计划。

## 外科式修改（Surgical Changes）

每一行 diff 必须能追溯到用户的本次请求。库代码的 diff 粒度比业务代码更严——导出面积不可因顺手扩大。

- **不顺手改**：相邻无关代码、注释、格式、命名、import 顺序一律不动
- **不重构未坏的代码**：你偏好的写法不是改动理由，匹配既有风格
- **只清自己的孤儿**：本次改动产生的未引用 import / 变量 / 函数必须清理；既有死代码发现了**提一下，别删**
- **导出面保护**：改 bug 不新增导出符号；新增导出 API 必须是用户明确要求的功能，且 MINOR 版本同步更新
- **边界测试**：提交前对着 diff 逐行问"这一行为什么存在？"——答不上来就删

## 代码质量门禁

每次实现、修复、重构后必须做质量自检；不通过就继续调整，不把低质量库代码交付给用户。

- **复杂度阈值**：单函数/方法过长、嵌套过深、参数过多、单文件过大时必须拆分或说明理由
- **隐式副作用禁令**：构造函数、`init`、包级初始化、导入阶段不得偷偷起 goroutine、写库、发请求或做复杂流程
- **TODO 纪律**：不留无主 `TODO` / `FIXME`；要么删除，要么绑定 issue / 负责人 / 处理期限
- **变更单一职责**：一次改动尽量只解决一类问题，功能、重构、格式修正不要混在一起
- **减少冗余**：重复逻辑超过 2 次必须提取；重复结构相似但语义不同的，优先保持 API 清晰，不为复用而复用
- **代码复用**：优先复用已有内部 helper、option、error helper、测试 fixture 和标准库能力；新增抽象必须至少解决真实重复或隔离复杂度
- **架构清晰**：导出 API、内部实现、错误类型、配置选项、测试辅助必须边界清楚；禁止把一次性内部细节暴露成公共 API
- **分层合理**：公共 API 只表达稳定契约，内部包承载实现细节；测试辅助不反向污染生产代码；禁止循环依赖
- **健壮稳定**：错误路径、nil、边界输入、并发安全、资源释放、兼容性、性能回退必须有明确处理或测试
- **简单优先**：能用清晰直写解决的问题，不提前设计扩展点、配置项、接口或复杂抽象；导出面积能小则小

## 可验证目标（Goal-Driven Execution）

动手前把模糊任务转成可验证目标，再编码。

**转换模板：**

| 模糊指令 | 可验证目标 |
|---------|----------|
| "加个校验" | 写非法输入 table-driven 测试 → 让它通过 |
| "修这个 bug" | 写复现用例测试 → 让它通过 |
| "重构 X" | 确认改前测试全绿 → 改后测试仍全绿 + benchmark 不退化 |
| "新增 API" | 先写 Example 测试定义用法 → 实现让它通过 |
| "让它能跑" | 不可验证，退回用户澄清成功标准 |

**多步任务先列计划：**

    1. [步骤] → verify: [可观察的检查]
    2. [步骤] → verify: [可观察的检查]

强目标让你独立闭环；弱目标会把你和用户都拖进反复澄清循环。

### 迭代与停止纪律（Verify–Correct Loop）

把"写完就交"换成"改一轮验一轮"的闭环，但闭环必须有上界，不允许空转。

- **先观察再改**：每次修复前先读真实报错 / 失败用例 / 实际输出，禁止不看错误盲改。说不清"上一轮为什么失败"就不许进下一轮。
- **改完跑相关全量**：单点修复后重跑该模块相关的全部检查（lint + 受影响测试），不只跑新加的那条，防止按下葫芦浮起瓢的回归。
- **自纠上界**：同一问题连续自纠 3 轮仍不达标，立即停手——不再继续试错或换花样硬凑，转为向用户汇报：已尝试什么、当前现象、卡在哪、你的判断和建议的下一步。
- **进展为正才继续**：每轮结束确认"离目标更近"（失败项减少 / 错误更聚焦）。出现来回震荡（同一处反复改回原样）视同卡住，按上界处理。
- **回归确认**：修复后必须确认是真修复而非巧合通过；确认后按错误记忆规则追加 `.harness/error-journal.md`，避免重蹈覆辙。

停止并升级不是失败，是把不确定性交还给用户的正确动作；空转硬试才是。

## Guide 加载表

| 场景 | 读哪个 Guide |
|-----|-------------|
| 包结构、接口、Options | `.harness/guides/pkg-structure.md` |
| 错误设计 | `.harness/guides/pkg-errors.md` |
| 测试、Benchmark、Example | `.harness/guides/pkg-testing.md` |
| 文档、README、CHANGELOG | `.harness/guides/pkg-docs.md` |
| 泛型 | `.harness/guides/pkg-generics.md` |
| API 兼容性、导出面、SemVer 影响 | `.harness/guides/pkg-api-compat.md` |
| 发版、打 tag、SemVer、依赖、供应链安全 | `.harness/guides/pkg-release-and-supply-chain.md` |
| 代码审查 | `.harness/guides/pkg-review.md` |
| 新增或改动 `.go` 文件（现代语法 / 泛型 / UUID） | `.harness/guides/go-modern.md` |

## 本机容器与镜像纪律（铁律）

- **先查后用**：需要镜像时先 `docker images` 看本机有没有；本机已有就用本机这一版，不再 `docker pull` 别的 tag（含 `latest`）。
- **复用已启动容器**：先 `docker ps -a` 看目标容器在不在；正在运行就直接连，已存在但停止就 `docker start` 复用，不新建同类容器、不换端口再起一份。
- **缺了先问**：本机确实没有所需镜像或容器时停下来，告诉用户缺什么、准备用哪个镜像和 tag，得到明确同意后才执行 `docker pull` / `docker run`。
- **隐式拉取同样受限**：`docker run`（镜像缺失时自动拉）、`docker compose up`、testcontainers、Makefile 与脚本里封装的容器命令，执行前一律先确认本机镜像与容器状态。
- **版本以本机为准**：不因为"官方推荐更新版本"就替换本机镜像 tag；需要外部依赖的集成测试连本机已启动的服务实例，不另起一份。

## 提交前检查

```bash
go vet ./...
golangci-lint run ./...
go test -race -count=1 -timeout=5m ./...
go test -bench=. -benchmem -count=3 ./...
go test -coverprofile=coverage.out ./...
```

## 合规摘要

多文件改动或走 `/harness-review` 时附上；一处小修复只汇报跑了哪些检查与结果：
```
## 合规检查摘要
- [x] Go 1.27 现代特性
- [x] 零/最小外部依赖
- [x] Functional Options + 合理默认值
- [x] 导出 API 全部有 GoDoc
- [x] Example 测试（可验证）
- [x] 测试覆盖 ≥ 80%
- [x] Benchmark（ReportAllocs）
- [x] 错误体系完整
- [x] 并发安全标注
- [x] API 兼容性与导出面已检查
- [x] 代码质量门禁：无明显冗余，复用合理，职责清晰，健壮性已检查
- [x] 无编造内容
```

## 错误记忆

`.harness/error-journal.md`——未关闭的条目由 SessionStart hook 在会话开始时注入，不用自己去读；犯错时追加。

优先执行项目内脚本：

```bash
bash .harness/scripts/append-error-journal.sh . user-correction pkg "用户指出包导出面设计不合理"
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .harness/scripts/append-error-journal.ps1 -RepoRoot . -EventType user-correction -Area pkg -Summary "用户指出包导出面设计不合理"
```

用户提示词中出现“犯错”“错误”“错了”“不对”“有问题”“bug”“失败”“回归”等纠错或追责信号时，必须先追加错误记录再继续处理。
用户纠正、命令失败、测试失败、审查发现缺陷、回归问题时，也必须先追加错误记录再继续处理。

## 沟通语言

**与用户的所有对话必须使用简体中文**，包括解释、确认、进度汇报、错误说明。

## 文档维护

- **新增功能或变更使用方法时，必须同步更新 README**（项目根 `README.md` 或模块对应 README）
- 更新范围：功能清单、安装/初始化步骤、命令示例、配置项说明、目录结构
- 提交纪律：README 更新与功能代码须在同一次提交中完成，避免文档滞后
- 交付前自检：若本次变更涉及对外接口、CLI 命令、环境变量、使用流程，而 README 未同步，判定为未完成

## 敏感信息与 .gitignore 安全基线

### 禁止入库（零容忍）

- 环境变量文件：`.env`、`.env.local`、`.env.production` 等
- 密钥文件：`*.pem`、`*.key`、`id_rsa`、`secrets.*`、`credentials.*`
- 带真实密钥的配置文件（`config.*.yml`、`application.properties` 含密钥版本等）
- 云服务凭据：AWS / 阿里云 / 腾讯云 AccessKey、Service Account JSON
- 系统 / IDE 产物：`.DS_Store`、`.idea/`、`.vscode/`（除非团队共享）
- 构建 / 测试产物：`dist/`、`build/`、`bin/`、`coverage/`、`*.log`

### 代码内禁止硬编码

- API Key、密码、Token、私钥、JWT Secret、Session Secret、加密 Salt 一律从环境变量或密钥管理服务读取
- 本地开发用 `.env.example` 提供占位符，真实值放 `.env`（不入库）
- 日志禁止打印完整密钥，必要时脱敏（如 `sk-****abcd`、`Bearer ****`）
- 返回给调用方的错误信息必须过滤敏感字段
- 测试禁止使用真实密钥，用 mock / fixture 替代
- **库代码额外约束**：导出 API 参数/返回值禁止包含明文密钥；文档与 Example 使用占位符

`.gitignore` 基线由 setup 写好，不要删其中条目；项目新增产物类型时补进去。

### 事故响应

- 发现敏感信息已入库：**立即吊销该密钥**，再从 Git 历史清除（`git filter-repo` / BFG）
- 已推送到远端的密钥视作"已泄露"，不可靠删除掩盖
- 事件记录到 `.harness/error-journal.md`，避免重蹈覆辙

