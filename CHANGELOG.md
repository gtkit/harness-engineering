# Changelog

所有重要变更记录在此文件中。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

> 版本号体系于 2026-09-18 重置，从 1.0.0 重新开始。此前的 1.0.0 ~ 1.17.0 条目与对应 tag 已移除；
> 那段历史连同其中记录的实测结论仍完整保留在 git 历史里，用 `git show 446246d:CHANGELOG.md` 取回。

## [Unreleased]

## [1.2.0] - 2026-09-21

### Added
- 三套 Go harness 新增 skill 调用索引与路径触发。起因是实际现象：开发 Go 项目时全局 skill 大多没被调用。排查结论是 skill 正文不会自动进上下文——系统提示里只有名字和描述，不显式调用等于没有；而 `rules/` 的路径触发过去只覆盖 guides（`grep` 全部 rules 文件，skill 一次都没出现），入口文件的 Guide 加载表里 skill 那行也只是陈述句「对应 skill：…」，没有调用动词。本次补齐：`shared/guides/go/skills-index.md`（21 项，go-harness 与 go-grpc-harness 共用）与 `go-pkg-harness/guides/skills-index.md`（11 项，砍掉 Gin / 微服务 / 长连接 / 可观测 / 稳定性 / 缓存与数据一致性等服务侧条目，DB / Redis / MQ 合成一行，因为 gtkit 那类工具库会直接操作它们）；三套新增 `rules/harness-go-skills.md`，`paths` 命中 `**/*.go` 与 `**/go.mod`。
- 索引表的加载纪律限定**一次最多调 3 个**：命中多条时按本次改动的主路径挑三个先调，其余写进计划、写到那段再调。初版写的是「命中多条一次性全调」，会让一个同时碰 DB、Redis、缓存、错误、并发的功能一口气拉进 5 份规范文本，把项目代码挤出上下文。

### Changed
- 三套 Go harness 的 `AGENTS.md`：Logic 四步第 2 步改为「读 guide + 按 skills-index 选出相关 skill，动手前就调用，不边写边补」；Guide 加载表里通用 Go 知识那行换成指向索引表的指令。`CLAUDE.md` 由 `sync-claude-from-agents.sh` 同步生成，`--check` 验证一致。
- `harness-implement` / `harness-research` / `harness-review` 三个工作流 skill，在各自「读 guides」的位置加上「Go 项目先读 skills-index 并调用它选中的 skill」。
- README 目录树同步新增 guide，并修正三套的 guides 计数：原写 16 / 9 / 16，实测安装分别是 18 / 11 / 18，差的一篇是三份清单都漏列的 `ai-safety.md`，一并补进清单；`shared/guides/go/` 的共用篇数由 9 改为 10，并写明 fullstack-harness 只拉其中 9 篇。

## [1.1.0] - 2026-09-21

### Added
- `go-pkg-harness/guides/pkg-api-compat.md` 新增「带键初始化守卫（`_ struct{}`）」一节，`shared/guides/go/pkg-design.md` 加同名精简节（该 guide 由 go / go-grpc / fullstack 三套共用，写成自包含短版）：对外导出结构体在首位加未导出空字段，编译器会拒绝跨包的位置初始化，字段顺序因此不进入兼容契约。规范给出加的两个条件（有 2 个及以上同类型字段；Config / Options / DTO 这类会持续新增字段的结构体）、不加的三种情况（`internal/` 类型、靠简洁字面量表达的小值类型、需要与同构 struct 互转的类型）与实施约束。Go 1.27.1 实测：跨包位置初始化报 `too few values in struct literal of type pkg.Config (type has unexported fields - use key:value pairs)`；守卫放首位 `unsafe.Sizeof` 与不加时同为 24，放末位因尾部零大小字段补齐涨到 32；未导出字段同时阻断跨包 struct 类型转换（`cannot convert ... to type ...`），所以给已发布结构体补加守卫算破坏性变更。附带核实：`$GOROOT/src` 与 `protobuf@v1.36.9` 生成代码里都没有 `_ struct{}` 写法（protobuf 用的是 `state protoimpl.MessageState` 等有实际用途的未导出字段，效果等价），规范因此只按实测写效果，不引用「标准库广泛使用」这类说法。

## [1.0.0] - 2026-09-18

版本号体系重置后的首个版本。本条目描述仓库在此版本的构成与本次的规则变更，不重述被移除的历史条目。

### Added
- 七套 harness：`go-harness`（Gin + GORM + gtkit 的 Go 后端业务服务）、`go-grpc-harness`（grpc-go + buf + protovalidate + ormx 的 Go gRPC 微服务）、`go-pkg-harness`（Go 扩展包 / 第三方库）、`fullstack-harness`（Go 后端 + Vue 前端同目录）、`laravel-harness`（纯 Laravel，默认纳入 Queue / Scheduler / Event / Notification）、`laravel-fullstack-harness`（Laravel + Vue 分目录）、`openresty-harness`（OpenResty / ngx_lua）。每套含入口文件（`CLAUDE.md` / `AGENTS.md`）、guides、rules、skills 与安装脚本。
- 跨套共用的 `shared/guides/`（`common/` 的 AI 行为安全与提交规范，以及 go / laravel / openresty 各自的技术 guide）。
- `scripts/hooks/pre_tool_use.py`：注册到 PreToolUse 的硬拦截层，在命令执行前直接拒绝不可恢复的操作；规则写在 md 里模型可以不遵守，这是唯一拦得住的一层。fail-open，脚本自身出错时放行。
- 七套 harness 的「行为纪律」新增一条「源材料逐行转清单」：用户给了参照实现（要移植的文件、要对接的接口、要复刻的行为）时，先逐行读完，把每个**外部耦合点**抄成清单再动手——连接与库号、键名与前缀、字段名、超时与 TTL、字符集与编码、调用方与被调用方；每项要么在新实现里有对应物，要么写明为什么不需要。起因是一次实际事故：把一个 111 行的 PHP 定时任务移植成 Go 后台任务，业务参数（字符集、目标容量、单批数量、锁 TTL）逐条对齐了，但源文件第 25 行 `Redis::connection('ocpc')  // 6 库走配置` 从提案、设计到实现一次都没被提及——而同一次交付里反复警告过「键名前缀配错会造成两侧都不报错的静默故障」，同一个文件里同类的库号问题却没看见。根因是核对清单凭印象生成：照着「移植这类东西该注意什么」的既有印象去对，清单里只装得下已经想到的东西。

### Changed
- 七套 harness 「行为纪律」的「严格按结构输出」条追加触发器：做用户没点名的动作前，先在他本轮原话里找这个词，找不到就不做，改成一句话汇报；「我在验证」「我发现了真问题」不构成理由；未验证前提不得抛提议，提议等于替用户创造任务。原条目只有原则（「只做用户要求的事，不扩展无关内容」），而范围扩张发生时每一步都自带正当理由，原则只能事后判定、拦不住当下；触发器把判据换成客观的「用户原话里有没有这个词」。七套的措辞与编号各不相同（该条在不同套里是第 3 或第 4 条，段内总条数 6/7/8），按各自原文就地追加，未统一措辞。
