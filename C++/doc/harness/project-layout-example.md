# 安装后项目目录示例

这份文档说明把 Harness 安装进目标项目后，目录应该长什么样。

## 1. 最小推荐结构

```text
your-cpp-project/
├── AGENTS.md
├── .harness/
│   ├── error-journal.md
│   ├── guides/
│   │   ├── architecture.md
│   │   ├── cpp-coding.md
│   │   ├── linux-systems.md
│   │   ├── ai-engineering.md
│   │   ├── build-and-toolchain.md
│   │   ├── testing-and-validation.md
│   │   └── review-checklist.md
│   ├── checklists/
│   │   ├── pre-commit.md
│   │   ├── pre-merge.md
│   │   └── pre-release.md
│   ├── validation/
│   │   ├── test-matrix.md
│   │   ├── cross-validation.md
│   │   └── regression-policy.md
│   ├── reviews/
│   │   ├── risk-register.md
│   │   └── hidden-risk-checklist.md
│   ├── templates/
│   │   ├── task-output-template.md
│   │   ├── review-report-template.md
│   │   └── test-report-template.md
│   └── skills/
│       └── cpp-linux-ai-harness/
│           ├── SKILL.md
│           ├── agents/
│           │   └── openai.yaml
│           ├── references/
│           │   ├── project-scope.md
│           │   ├── workflow.md
│           │   ├── error-memory.md
│           │   ├── review-standard.md
│           │   ├── validation-standard.md
│           │   └── output-contract.md
│           └── scripts/
│               ├── read_error_journal.sh
│               └── append_error_journal.sh
├── doc/
│   └── harness/
│       └── README.md
├── openspec/
│   └── changes/
│       └── cpp-linux-ai-harness/
│           ├── proposal.md
│           ├── spec.md
│           └── tasks.md
└── docs/
    └── superpowers/
        └── plans/
            └── 2026-04-13-cpp-linux-ai-harness.md
```

## 2. 哪些是核心必须项

以下内容建议视为必须项：

1. `AGENTS.md`
2. `.harness/error-journal.md`
3. `.harness/guides/`
4. `.harness/checklists/`
5. `.harness/validation/`
6. `.harness/reviews/`
7. `.harness/templates/`
8. `.harness/skills/cpp-linux-ai-harness/`
9. `doc/harness/README.md`

## 3. 哪些是建议保留项

以下内容建议保留，方便后续留痕和审计：

1. `openspec/changes/cpp-linux-ai-harness/`
2. `docs/superpowers/plans/2026-04-13-cpp-linux-ai-harness.md`

## 4. 目录放错会有什么问题

### `AGENTS.md` 不在项目根目录

问题：

- AI 不容易把它当成项目入口约束

### `.harness/` 不在项目根目录

问题：

- 错误日志、guides、checklists、validation 无法按约定路径读取

### `doc/harness/README.md` 不在 `doc/harness/`

问题：

- 人类查阅位置不统一

### Skill 不在 `.harness/skills/cpp-linux-ai-harness/`

问题：

- README 中的路径说明失效
- 仓库内 Skill 的固定引用路径失效

## 5. 推荐做法

最稳的做法：

1. 不要手工拆散目录
2. 直接使用安装脚本
3. 安装完成后按本页目录树核对
