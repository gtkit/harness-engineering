# Windows 安装说明

这份文档只说明 Windows 下如何安装这套 Harness 包。

## 1. 安装前准备

你需要准备两样东西：

1. 这套 Harness 安装包目录
2. 你的目标 C++ 项目根目录

安装包目录示例：

```text
D:\packages\C++
```

目标项目目录示例：

```text
C:\your-cpp-project
```

## 2. 推荐安装方式

推荐直接双击：

```text
install.bat
```

然后在提示里输入目标项目根目录，例如：

```text
C:\your-cpp-project
```

## 3. PowerShell 手动安装

如果你不想双击，可以打开 PowerShell 手动执行：

```powershell
cd D:\packages\C++
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -TargetDir "C:\your-cpp-project"
```

## 4. 安装脚本会做什么

脚本会把以下内容复制到目标项目根目录：

1. `AGENTS.md`
2. `.harness/checklists/`
3. `.harness/reviews/`
4. `.harness/templates/`
5. `.harness/validation/`
6. `.harness/skills/`
7. `.harness/guides/`（默认只补缺失文件，已有文件保留）
8. `.harness/error-journal.md`（已有文件保留）
9. `.gitignore`（自动创建或补齐规则）
10. `doc/harness/README.md`
11. `openspec/changes/cpp-linux-ai-harness/`
12. `docs/superpowers/plans/2026-04-13-cpp-linux-ai-harness.md`

说明：

- `install.bat` 和 `install.ps1` 不会复制到目标项目
- 它们只保留在安装包目录里作为安装器
- 目标项目已有 `.harness/error-journal.md` 时会保留现有记录
- 目标项目已有 `.harness/guides/*.md` 时默认保留；只有显式使用 `-ForceGuides` 才覆盖

## 5. 如果目标项目里已有同名文件怎么办

安装脚本不会直接覆盖后丢弃旧文件。

它会先把旧内容备份到：

```text
<项目根目录>\.harness-install-backup\时间戳\
```

然后再复制新内容。

## 6. 安装后应该检查什么

安装后先确认以下路径存在：

```text
<项目根目录>\AGENTS.md
<项目根目录>\.harness\error-journal.md
<项目根目录>\.gitignore
<项目根目录>\doc\harness\README.md
<项目根目录>\.harness\skills\cpp-linux-ai-harness\SKILL.md
```

## 7. 安装后下一步怎么做

推荐顺序：

1. 先看 `<项目根目录>\AGENTS.md`
2. 再看 `<项目根目录>\.harness\error-journal.md`
3. 再看 `<项目根目录>\doc\harness\README.md`
4. 然后补齐所有 `需用户补充`

## 8. 常见用法

安装完成后，给 AI 的最小调用方式：

```text
使用 $cpp-linux-ai-harness 处理这个 C++ Linux AI 任务。
先读取 AGENTS.md 和 .harness/error-journal.md，再按 Logic 四步输出。
```

## 9. 常见问题

### 9.1 PowerShell 被系统策略限制

优先使用：

```text
install.bat
```

因为它内部已经使用：

```text
ExecutionPolicy Bypass
```

### 9.2 目标目录不存在

脚本会自动创建目标目录。

### 9.3 目标目录和安装包目录相同

脚本会直接报错并停止，避免把安装包目录误当成项目目录。

### 9.4 旧文件被覆盖怎么办

去备份目录恢复：

```text
<项目根目录>\.harness-install-backup\时间戳\
```

### 9.5 我想刷新 guide 模板，但不想丢 error-journal

手动执行：

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -TargetDir "C:\your-cpp-project" -ForceGuides
```
