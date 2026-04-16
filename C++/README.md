# C++ Linux AI Harness Package

这是这套 `C++20/23 + Linux + AI` Harness 包的总入口。

如果你只想快速安装，请先看：

1. [Windows 安装说明](./doc/harness/windows-install.md)
2. [详细使用说明](./doc/harness/README.md)
3. [安装后项目目录示例](./doc/harness/project-layout-example.md)

## 1. 这套包里有什么

当前包根目录推荐包含：

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
├── docs/
│   └── superpowers/
│       └── plans/
│           └── 2026-04-13-cpp-linux-ai-harness.md
└── 生成的 harness提示词.md
```

其中：

- `install.bat` / `install.ps1` 是安装器
- `AGENTS.md` 和 `.harness/` 是安装到项目根目录后的核心治理文件
- `doc/harness/` 是人类使用说明
- `openspec/` 和 `docs/superpowers/plans/` 是这次模板落地的设计与实施留痕

## 2. 安装到目标项目后应该放哪

目标项目根目录示例：

```text
C:\your-cpp-project
```

安装完成后，核心目录应为：

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

更完整的树请看：

- [安装后项目目录示例](./doc/harness/project-layout-example.md)

## 3. 最快安装方式

### Windows

双击：

```text
install.bat
```

或 PowerShell 手动执行：

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -TargetDir "C:\your-cpp-project"
```

如果你要强制用安装包里的 guide 覆盖目标项目已有 guide：

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -TargetDir "C:\your-cpp-project" -ForceGuides
```

详细步骤看：

- [Windows 安装说明](./doc/harness/windows-install.md)

## 4. 安装完成后先看什么

推荐顺序：

1. `<项目根目录>/AGENTS.md`
2. `<项目根目录>/.harness/error-journal.md`
3. `<项目根目录>/doc/harness/README.md`
4. `<项目根目录>/.harness/guides/architecture.md`
5. `<项目根目录>/.harness/guides/cpp-coding.md`
6. `<项目根目录>/.harness/guides/linux-systems.md`
7. `<项目根目录>/.harness/guides/ai-engineering.md`
8. `<项目根目录>/.harness/guides/build-and-toolchain.md`
9. `<项目根目录>/.harness/guides/testing-and-validation.md`
10. `<项目根目录>/.harness/guides/review-checklist.md`

## 5. 这套包怎么用

### 人工使用

重点看：

- `AGENTS.md`
- `.harness/guides/`
- `.harness/checklists/`
- `.harness/validation/`
- `.harness/reviews/`
- `.harness/error-journal.md`

### 给 AI 用

最小调用方式：

```text
使用 $cpp-linux-ai-harness 处理这个 C++ Linux AI 任务。
先读取 AGENTS.md 和 .harness/error-journal.md，再按 Logic 四步输出。
```

如果你不显式写 Skill 名，至少要求：

```text
先读取 AGENTS.md、.harness/error-journal.md 和相关 guide，再开始处理。
```

## 6. 你接下来该看哪份文档

- 需要完整文件说明和目录落位：看 [详细使用说明](./doc/harness/README.md)
- 需要 Windows 安装步骤：看 [Windows 安装说明](./doc/harness/windows-install.md)
- 需要目标项目目录树：看 [安装后项目目录示例](./doc/harness/project-layout-example.md)
