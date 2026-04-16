# C++ Linux AI Harness README

这份 README 只做三件事：

1. 说明这套 Harness 包里的文件和目录分别是什么
2. 说明这些文件和目录安装到项目后应该放在哪些位置
3. 说明安装完成后怎么使用这些文件

不讨论无关业务实现。

## 0. 文档导航

如果你要快速上手，优先看这三份：

1. [包根 README](../../README.md)
2. [Windows 安装说明](./windows-install.md)
3. [安装后项目目录示例](./project-layout-example.md)

## 1. 这套包是什么

这是一套面向 `C++20/23 + Linux + AI` 项目的企业级 Harness 包，内容包括：

1. 项目级入口约束
2. `.harness/` 治理目录
3. 可复用 Skill
4. 错误记忆机制
5. 审查、验证、回归和风险控制文档
6. 设计与实施留痕文档
7. Windows 一键安装脚本

## 2. 安装包目录应该怎么摆

如果你把这套内容当成一个可分发安装包，包根目录推荐如下：

```text
C++/
├── README.md
├── install.bat
├── install.ps1
├── AGENTS.md
├── .harness/
├── doc/
│   └── harness/
│       ├── README.md
│       ├── windows-install.md
│       └── project-layout-example.md
├── openspec/
│   └── changes/
│       └── cpp-linux-ai-harness/
└── docs/
    └── superpowers/
        └── plans/
            └── 2026-04-13-cpp-linux-ai-harness.md
```

说明：

- `install.bat` 和 `install.ps1` 只属于安装包目录
- `AGENTS.md`、`.harness/`、`doc/`、`openspec/`、`docs/` 是要安装进目标项目里的内容

## 3. 安装到目标项目后，文件应该放在哪

假设你的目标项目根目录是：

```text
C:\your-cpp-project
```

安装完成后，文件和目录应该放在以下位置：

```text
C:\your-cpp-project
├── AGENTS.md
├── .harness/
├── doc/
│   └── harness/
│       └── README.md
├── openspec/
│   └── changes/
│       └── cpp-linux-ai-harness/
└── docs/
    └── superpowers/
        └── plans/
            └── 2026-04-13-cpp-linux-ai-harness.md
```

更完整的示例请看：

- [安装后项目目录示例](./project-layout-example.md)

## 4. 每个文件或目录分别应该放哪里

| 安装包内路径 | 安装到项目后的路径 | 是否必须安装 | 作用 |
| --- | --- | --- | --- |
| `README.md` | 不安装到项目内，保留在安装包根目录 | 建议保留 | 包总入口 |
| `install.bat` | 不安装到项目内，保留在安装包根目录 | 是 | Windows 双击入口 |
| `install.ps1` | 不安装到项目内，保留在安装包根目录 | 是 | Windows PowerShell 安装脚本 |
| `AGENTS.md` | `<项目根目录>/AGENTS.md` | 是 | 项目级 AI 行为入口 |
| `.harness/` | `<项目根目录>/.harness/` | 是 | 全部治理、验证、风险、模板、Skill 资产 |
| `.harness/error-journal.md` | `<项目根目录>/.harness/error-journal.md` | 是 | 错误记忆核心文件；已有文件默认保留 |
| `.harness/guides/` | `<项目根目录>/.harness/guides/` | 是 | 架构、编码、Linux、AI、构建、测试、审查规范 |
| `.harness/checklists/` | `<项目根目录>/.harness/checklists/` | 是 | pre-commit / pre-merge / pre-release 检查 |
| `.harness/validation/` | `<项目根目录>/.harness/validation/` | 是 | 测试矩阵、交叉验证、回归策略 |
| `.harness/reviews/` | `<项目根目录>/.harness/reviews/` | 是 | 风险清单与隐患排查 |
| `.harness/templates/` | `<项目根目录>/.harness/templates/` | 是 | 固定输出模板 |
| `.harness/skills/cpp-linux-ai-harness/` | `<项目根目录>/.harness/skills/cpp-linux-ai-harness/` | 是 | 仓库内可复用 Skill |
| `doc/harness/README.md` | `<项目根目录>/doc/harness/README.md` | 是 | 人类阅读的详细使用说明 |
| `doc/harness/windows-install.md` | 保留在安装包目录 `doc/harness/windows-install.md` | 建议保留 | Windows 安装文档 |
| `doc/harness/project-layout-example.md` | 保留在安装包目录 `doc/harness/project-layout-example.md` | 建议保留 | 目标项目目录示例 |
| `openspec/changes/cpp-linux-ai-harness/` | `<项目根目录>/openspec/changes/cpp-linux-ai-harness/` | 建议保留 | 这次落地的 proposal / spec / tasks 留痕 |
| `docs/superpowers/plans/2026-04-13-cpp-linux-ai-harness.md` | `<项目根目录>/docs/superpowers/plans/2026-04-13-cpp-linux-ai-harness.md` | 建议保留 | 本次实施计划留痕 |

## 5. Windows 下怎么安装

### 5.1 一键安装

最简单方式：

1. 把整个安装包目录放到 Windows 本地
2. 双击 `install.bat`
3. 在提示里输入目标项目根目录

例如：

```text
C:\your-cpp-project
```

详细步骤看：

- [Windows 安装说明](./windows-install.md)

### 5.2 PowerShell 手动执行

如果你不想双击，也可以手动执行：

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -TargetDir "C:\your-cpp-project"
```

### 5.3 备份目录

安装脚本遇到同名旧文件时，会把旧内容移到目标项目里的备份目录：

```text
<项目根目录>\.harness-install-backup\时间戳\
```

### 5.4 现有 guide 和错误日志的默认策略

- `.harness/error-journal.md`：如果目标项目里已存在，默认保留
- `.harness/guides/*.md`：如果目标项目里已存在，默认保留
- 想强制用安装包内 guide 覆盖现有 guide 时，显式加 `-ForceGuides`

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -TargetDir "C:\your-cpp-project" -ForceGuides
```

## 6. 安装完成后先看什么

推荐阅读顺序：

1. `<项目根目录>/AGENTS.md`
2. `<项目根目录>/.harness/error-journal.md`
3. `<项目根目录>/.harness/guides/architecture.md`
4. `<项目根目录>/.harness/guides/cpp-coding.md`
5. `<项目根目录>/.harness/guides/linux-systems.md`
6. `<项目根目录>/.harness/guides/ai-engineering.md`
7. `<项目根目录>/.harness/guides/build-and-toolchain.md`
8. `<项目根目录>/.harness/guides/testing-and-validation.md`
9. `<项目根目录>/.harness/guides/review-checklist.md`

## 7. 安装完成后怎么使用

### 7.1 人怎么用

人类使用时，重点看：

1. `AGENTS.md`
2. `.harness/guides/`
3. `.harness/checklists/`
4. `.harness/validation/`
5. `.harness/reviews/`
6. `.harness/error-journal.md`

### 7.2 AI 怎么用

后续给 AI 下任务时，最小使用方式：

```text
使用 $cpp-linux-ai-harness 处理这个 C++ Linux AI 任务。
先读取 AGENTS.md 和 .harness/error-journal.md，再按 Logic 四步输出。
```

如果你不显式写 Skill 名，也至少要求：

```text
先读取 AGENTS.md、.harness/error-journal.md 和相关 guide，再开始处理。
```

### 7.3 常见任务示例

架构审查：

```text
使用 $cpp-linux-ai-harness 审查这个 C++ 推理服务的模块边界、关闭路径、资源控制和验证缺口。
输出顺序必须是 Findings、Open Questions、风险摘要、历史错误对照检查、合规检查摘要。
```

Bug 修复：

```text
使用 $cpp-linux-ai-harness 处理这个 Linux 守护进程的关闭悬挂问题。
先读取 .harness/error-journal.md，命中同类问题时引用历史条目。
修复后按 .harness/validation/test-matrix.md 给出验证结果。
```

模板生成：

```text
使用 $cpp-linux-ai-harness 为这个本地模型推理项目生成 AGENTS.md、.harness/guides、验证矩阵和错误日志模板。
只输出我要求的结构，不要扩展。
```

## 8. `.harness/` 里的目录分别怎么用

### 8.1 `.harness/guides/`

这里放规则正文，AI 和人都应该先看。

当前包括：

- `architecture.md`
- `cpp-coding.md`
- `linux-systems.md`
- `ai-engineering.md`
- `build-and-toolchain.md`
- `testing-and-validation.md`
- `review-checklist.md`

### 8.2 `.harness/checklists/`

这里放流程门槛：

- `pre-commit.md`
- `pre-merge.md`
- `pre-release.md`

### 8.3 `.harness/validation/`

这里放验证规则：

- `test-matrix.md`
- `cross-validation.md`
- `regression-policy.md`

### 8.4 `.harness/reviews/`

这里放风险与隐患检查：

- `risk-register.md`
- `hidden-risk-checklist.md`

### 8.5 `.harness/templates/`

这里放统一输出模板：

- `task-output-template.md`
- `review-report-template.md`
- `test-report-template.md`

### 8.6 `.harness/skills/cpp-linux-ai-harness/`

这是仓库内 Skill，本体结构如下：

```text
.harness/skills/cpp-linux-ai-harness/
├── SKILL.md
├── agents/openai.yaml
├── references/
└── scripts/
```

## 9. 错误记忆机制怎么用

核心文件是：

```text
<项目根目录>/.harness/error-journal.md
```

使用规则：

1. 每次任务开始前先读
2. 命令失败要记
3. 测试失败要记
4. 用户纠正要记
5. 审查发现缺陷要记
6. 回归问题要记
7. 输出前做历史错误对照

这一步不能省略。

## 10. 什么时候改哪个文件

| 你要改什么 | 去改哪个文件 |
| --- | --- |
| AI 总行为纪律 | `AGENTS.md` |
| 架构边界 | `.harness/guides/architecture.md` |
| C++ 编码规则 | `.harness/guides/cpp-coding.md` |
| Linux 系统规则 | `.harness/guides/linux-systems.md` |
| AI 推理与模型规则 | `.harness/guides/ai-engineering.md` |
| 构建与工具链规则 | `.harness/guides/build-and-toolchain.md` |
| 测试与验证规则 | `.harness/guides/testing-and-validation.md` |
| 审查清单 | `.harness/guides/review-checklist.md` |
| 错误记忆 | `.harness/error-journal.md` |
| pre-commit / pre-merge / pre-release 门槛 | `.harness/checklists/*` |
| 测试矩阵与回归策略 | `.harness/validation/*` |
| 风险清单 | `.harness/reviews/*` |
| AI 输出结构 | `.harness/templates/*` |
| Skill 触发与工作流 | `.harness/skills/cpp-linux-ai-harness/SKILL.md` |
| Skill 引用说明 | `.harness/skills/cpp-linux-ai-harness/references/*` |

## 11. 生产使用前必须补充的内容

以下内容当前仍然是通用骨架，必须按你的真实项目补齐：

1. GCC / Clang 最低版本
2. 具体 AI Runtime
3. 模型格式
4. 测试框架
5. benchmark 框架
6. 部署形态
7. 日志 / 指标 / Trace 技术栈
8. CPU / 内存 / 显存 / 延迟 / 吞吐预算
9. 安全与合规要求

如果这些不补，当前内容只能作为企业级通用模板，不能直接替代项目真实标准。

## 12. 当前这份包里最重要的文件

- `AGENTS.md`
- `.harness/error-journal.md`
- `.harness/guides/architecture.md`
- `.harness/guides/cpp-coding.md`
- `.harness/guides/linux-systems.md`
- `.harness/guides/ai-engineering.md`
- `.harness/guides/build-and-toolchain.md`
- `.harness/guides/testing-and-validation.md`
- `.harness/guides/review-checklist.md`
- `.harness/skills/cpp-linux-ai-harness/SKILL.md`
- `doc/harness/README.md`

## 13. 结论

如果你要把这套包发给别人，最稳的做法是：

1. 保持安装包根目录结构不变
2. 保留 `install.bat` 和 `install.ps1`
3. 让对方把内容安装到“项目根目录”，不要拆散放
4. 安装后先看 `AGENTS.md` 和 `.harness/error-journal.md`
5. 进入正式开发前，先补齐所有 `需用户补充`
