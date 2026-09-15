Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-HarnessHomeDir {
    if ($env:HOME) {
        return $env:HOME
    }

    if ($env:USERPROFILE) {
        return $env:USERPROFILE
    }

    return [Environment]::GetFolderPath("UserProfile")
}

function Assert-HarnessPathExists {
    param(
        [string]$Path,
        [string]$Message
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw $Message
    }
}

function Add-UniqueLine {
    param(
        [string]$Path,
        [string]$Line
    )

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    if (Test-Path -LiteralPath $Path) {
        $content = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
        $lines = $content -split "\r?\n"
        if ($lines -ccontains $Line) {
            return $false
        }

        if ($content.Length -gt 0 -and -not $content.EndsWith("`n")) {
            [System.IO.File]::AppendAllText($Path, [Environment]::NewLine, $utf8NoBom)
        }
    }

    [System.IO.File]::AppendAllText($Path, $Line + [Environment]::NewLine, $utf8NoBom)
    return $true
}

function Set-Utf8NoBomContent {
    param(
        [string]$Path,
        [string]$Value
    )

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Value, $utf8NoBom)
}

# 判断已存在的目标文件是否与本版本模板内容一致；用于把"跳过"细分为
# "已是本版本" 与 "内容落后"，后者在安装结束时汇总提示。
function Test-HarnessSameContent {
    param(
        [string]$PathA,
        [string]$PathB
    )

    if (-not (Test-Path -LiteralPath $PathA) -or -not (Test-Path -LiteralPath $PathB)) {
        return $false
    }

    $hashA = (Get-FileHash -LiteralPath $PathA -Algorithm SHA256).Hash
    $hashB = (Get-FileHash -LiteralPath $PathB -Algorithm SHA256).Hash
    return $hashA -eq $hashB
}

# 旧版本(1.x)误写进 .gitignore 的标题 "# Harness: 本地工具与 Agent 运行产物"，
# 迁移时用它作为精确剔除的匹配行。CJK 用码点构造，规避 Windows PowerShell 5.1
# 读取无 BOM 脚本时的编码问题。
function Get-HarnessLegacyGitignoreHeader {
    $codePoints = @(
        0x672C, 0x5730, 0x5DE5, 0x5177, 0x4E0E, 0x0020,
        0x0041, 0x0067, 0x0065, 0x006E, 0x0074, 0x0020,
        0x8FD0, 0x884C, 0x4EA7, 0x7269
    )
    return "# Harness: " + (($codePoints | ForEach-Object { [char]$_ }) -join '')
}

# .git/info/exclude 的中文标题 "# 本地工具与运行产物（仅本地忽略，不进版本库）"。
function Get-HarnessExcludeHeader {
    $codePoints = @(
        0x0023, 0x0020, 0x672C, 0x5730, 0x5DE5, 0x5177, 0x4E0E, 0x8FD0,
        0x884C, 0x4EA7, 0x7269, 0xFF08, 0x4EC5, 0x672C, 0x5730, 0x5FFD,
        0x7565, 0xFF0C, 0x4E0D, 0x8FDB, 0x7248, 0x672C, 0x5E93, 0xFF09
    )
    return (($codePoints | ForEach-Object { [char]$_ }) -join '')
}

# 从文件中精确剔除指定行（大小写敏感）；有剔除返回 $true，否则 $false。
function Remove-LinesFromFile {
    param(
        [string]$Path,
        [string[]]$Lines
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $content = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $existing = $content -split "\r?\n"
    $kept = @()
    $removed = $false
    foreach ($line in $existing) {
        if ($Lines -ccontains $line) {
            $removed = $true
            continue
        }
        $kept += $line
    }

    if (-not $removed) {
        return $false
    }

    [System.IO.File]::WriteAllText($Path, ($kept -join "`n"), $utf8NoBom)
    return $true
}

# openspec-auto 往 CLAUDE.md / AGENTS.md 注入的托管块起止标记。harness 比对与刷新时绕开它：
# 比对忽略该块(否则装过 openspec-auto 的项目每次重跑都被判为"与模板不同")，
# 强制刷新先写模板再把块原样追加回去。与 scripts/install-harness.sh 行为一致。
$script:HarnessOpenSpecBlockStart = "<!-- OPENSPEC-AUTO:START -->"
$script:HarnessOpenSpecBlockEnd = "<!-- OPENSPEC-AUTO:END -->"

# 返回文件中的托管块文本(含起止标记行, 以 "`n" 连接)；没有块返回空串。
function Get-HarnessManagedBlock {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return ""
    }
    $lines = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) -split "\r?\n"
    $block = @()
    $inside = $false
    foreach ($line in $lines) {
        if ($line -ceq $script:HarnessOpenSpecBlockStart) { $inside = $true }
        if ($inside) { $block += $line }
        if ($line -ceq $script:HarnessOpenSpecBlockEnd) { $inside = $false }
    }
    return ($block -join "`n")
}

# 返回去掉托管块后的文件文本(去掉尾部空行)，用于与模板比对。
function Get-HarnessContentWithoutManagedBlock {
    param([string]$Path)

    $lines = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) -split "\r?\n"
    $kept = @()
    $inside = $false
    foreach ($line in $lines) {
        if ($line -ceq $script:HarnessOpenSpecBlockStart) { $inside = $true; continue }
        if ($line -ceq $script:HarnessOpenSpecBlockEnd) { $inside = $false; continue }
        if (-not $inside) { $kept += $line }
    }
    return (($kept -join "`n").TrimEnd("`r", "`n"))
}

# 安装 CLAUDE.md / AGENTS.md：不存在则复制；强制刷新时保留托管块；否则比对(忽略托管块)并提示。
function Install-HarnessEntryFile {
    param(
        [string]$Source,
        [string]$Destination,
        [string]$Label,
        [string]$Force
    )

    if (-not (Test-Path -LiteralPath $Destination)) {
        Copy-Item -LiteralPath $Source -Destination $Destination
        Write-Host "  OK $Label"
        return
    }

    $block = Get-HarnessManagedBlock -Path $Destination
    if ($Force -eq "1") {
        Copy-Item -LiteralPath $Source -Destination $Destination -Force
        if ($block) {
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::AppendAllText($Destination, "`n" + $block + "`n", $utf8NoBom)
            Write-Host "  OK $Label (refreshed, openspec-auto managed block preserved)"
        }
        else {
            Write-Host "  OK $Label (refreshed)"
        }
        return
    }

    if ($block) {
        $template = ([System.IO.File]::ReadAllText($Source, [System.Text.Encoding]::UTF8)).TrimEnd("`r", "`n")
        if ((Get-HarnessContentWithoutManagedBlock -Path $Destination) -ceq $template) {
            Write-Host "  SKIP $Label already exists and matches this version (with openspec-auto managed block)"
            return
        }
    }
    elseif (Test-HarnessSameContent -PathA $Source -PathB $Destination) {
        Write-Host "  SKIP $Label already exists and matches this version"
        return
    }

    Write-Host "  WARN $Label already exists and differs from this version template; left untouched"
    $script:harnessStaleProjectFiles += $Label
}

# 把 SourceDir 下的 .md 文件（含子目录里的 SKILL.md）复制到 TargetDir；已存在默认保留，Force=1 覆盖。
function Copy-HarnessTree {
    param(
        [string]$SourceDir,
        [string]$TargetDir,
        [string]$Force,
        [string]$Label
    )

    $copied = 0
    $preserved = 0
    $files = Get-ChildItem -LiteralPath $SourceDir -File -Recurse -Filter *.md
    if ($files.Count -eq 0) {
        throw "No markdown templates found in $SourceDir"
    }
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($SourceDir.Length).TrimStart('\', '/')
        $destination = Join-Path $TargetDir $relative
        $destinationDir = Split-Path -Parent $destination
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
        if ($Force -eq "1" -or -not (Test-Path -LiteralPath $destination)) {
            Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
            $copied++
        }
        else {
            $preserved++
        }
    }
    if ($Force -eq "1") {
        Write-Host "  OK $Label - refreshed $copied"
    }
    else {
        Write-Host "  OK $Label - added $copied, preserved $preserved"
    }
}

# guide 来源分两层：shared-guides.txt 列出的公共 guide（shared/guides/ 下），叠加本 harness 自己的
# guides/*.md（同名以自己的为准）。先拼到暂存目录，后面的复制逻辑只看这一个目录。
function Stage-HarnessGuides {
    param(
        [string]$HarnessRoot,
        [string]$ScriptDir,
        [string]$StagedDir
    )

    New-Item -ItemType Directory -Path $StagedDir -Force | Out-Null
    $manifest = Join-Path $ScriptDir "shared-guides.txt"
    if (Test-Path -LiteralPath $manifest) {
        foreach ($raw in Get-Content -LiteralPath $manifest) {
            $rel = ($raw -split '#')[0].Trim()
            if (-not $rel) { continue }
            $source = Join-Path (Join-Path $HarnessRoot "shared\guides") ($rel -replace '/', '\')
            if (-not (Test-Path -LiteralPath $source)) {
                throw "shared-guides.txt references missing file: shared/guides/$rel"
            }
            Copy-Item -LiteralPath $source -Destination (Join-Path $StagedDir (Split-Path -Leaf $source)) -Force
        }
    }
    $ownGuides = Join-Path $ScriptDir "guides"
    if (Test-Path -LiteralPath $ownGuides) {
        foreach ($file in Get-ChildItem -LiteralPath $ownGuides -File -Filter *.md) {
            Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $StagedDir $file.Name) -Force
        }
    }
}

# SessionStart hook 命令：同一份注册进 Claude Code 的 .claude/settings.json 与 Codex 的 .codex/hooks.json。
# 与 scripts/install-harness.sh 的 _HARNESS_HOOK_COMMAND 保持一致；注册用 python 改 JSON，没有 python 就跳过。
$script:HarnessHookCommand = 'ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; PY="$(command -v python3 || command -v python)"; "$PY" "$ROOT/.harness/hooks/session_start.py"'

function Get-HarnessPython {
    foreach ($name in @("python3", "python")) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    return $null
}

function Register-HarnessHook {
    param(
        [string]$ConfigPath,
        [string]$Python
    )

    $script = @'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
command = sys.argv[2]
data = json.loads(path.read_text()) if path.is_file() and path.read_text().strip() else {}
hooks = data.setdefault("hooks", {})
entries = hooks.setdefault("SessionStart", [])
kept = []
for entry in entries:
    remaining = [h for h in entry.get("hooks", []) if "/.harness/hooks/" not in h.get("command", "")]
    if remaining:
        entry["hooks"] = remaining
        kept.append(entry)
kept.append({"matcher": ".*", "hooks": [{"type": "command", "command": command, "timeout": 15}]})
hooks["SessionStart"] = kept
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
'@
    $scriptPath = Join-Path ([System.IO.Path]::GetTempPath()) ("harness-hook-" + [System.Guid]::NewGuid().ToString("N") + ".py")
    Set-Utf8NoBomContent -Path $scriptPath -Value $script
    try {
        & $Python $scriptPath $ConfigPath $script:HarnessHookCommand
        if ($LASTEXITCODE -ne 0) { throw "hook registration failed for $ConfigPath" }
    }
    finally {
        Remove-Item -LiteralPath $scriptPath -Force -ErrorAction SilentlyContinue
    }
}

# 解析项目的 .git/info/exclude 路径(兼容 worktree/submodule); 非 git 仓库返回 $null。
function Resolve-HarnessExcludeFile {
    param([string]$ProjectDir)

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        return $null
    }

    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    try {
        & git -C $ProjectDir rev-parse --git-dir 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            return $null
        }
        Push-Location $ProjectDir
        try {
            $relative = & git rev-parse --git-path info/exclude 2>$null
        }
        finally {
            Pop-Location
        }
        if ([string]::IsNullOrWhiteSpace($relative)) {
            return $null
        }
        $relative = $relative.Trim()
        if ([System.IO.Path]::IsPathRooted($relative)) {
            return $relative
        }
        return (Join-Path $ProjectDir $relative)
    }
    finally {
        $ErrorActionPreference = $prevEAP
    }
}

function Write-HarnessVersion {
    param(
        [string]$ProjectDir,
        [string]$ModuleName,
        [string]$ScriptDir
    )

    $versionPath = Join-Path $ProjectDir ".harness/VERSION"
    $repoRoot = Split-Path -Parent $ScriptDir
    $sourceCommit = "unknown"
    $sourceTag = $null
    if (Get-Command git -ErrorAction SilentlyContinue) {
        # PS 7.3+ 在 $PSNativeCommandUseErrorActionPreference=true + ErrorActionPreference=Stop 下,
        # native command (如 git) 非零 exit 会触发 ErrorRecord 中断脚本.shallow clone 上
        # `git describe --tags` 无 tag 时 fatal/exit 128, 不应让 setup 挂.临时降级 EAP, 用 LASTEXITCODE 判定.
        $prevEAP = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        try {
            $commitOutput = & git -C $repoRoot rev-parse --short=12 HEAD 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($commitOutput)) {
                $sourceCommit = $commitOutput.Trim()
            }
            $tagOutput = & git -C $repoRoot describe --tags --abbrev=0 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($tagOutput)) {
                $sourceTag = $tagOutput.Trim()
            }
        } finally {
            $ErrorActionPreference = $prevEAP
        }
    }
    $installedAt = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"

    $lines = @(
        "harness: $ModuleName",
        "source-path: $repoRoot",
        "source-commit: $sourceCommit"
    )
    if (-not [string]::IsNullOrEmpty($sourceTag)) {
        $lines += "source-tag: $sourceTag"
    }
    $lines += "installed-at: $installedAt"
    $lines += "installer: setup.ps1"

    Set-Utf8NoBomContent -Path $versionPath -Value (($lines -join "`n") + "`n")
    Write-Host "  OK wrote .harness/VERSION (commit: $sourceCommit)"
}

function Invoke-HarnessSetup {
    param(
        [string]$ScriptDir,
        [string]$ModuleName,
        [string]$DisplayName,
        [string]$CodexSkillPath
    )

    $projectDir = (Get-Location).Path
    $script:harnessStaleProjectFiles = @()
    $script:harnessStaleGuides = @()
    $forceGuides = if ($env:HARNESS_FORCE_GUIDES) { $env:HARNESS_FORCE_GUIDES } else { "0" }
    $forceProjectFiles = if ($env:HARNESS_FORCE_PROJECT_FILES) { $env:HARNESS_FORCE_PROJECT_FILES } else { "0" }
    $homeDir = Get-HarnessHomeDir
    $codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $homeDir ".codex" }

    $harnessRoot = Split-Path -Parent $ScriptDir
    $ownGuidesDir = Join-Path $ScriptDir "guides"
    $guidesDir = Join-Path ([System.IO.Path]::GetTempPath()) ("harness-guides-" + [System.Guid]::NewGuid().ToString("N"))
    Stage-HarnessGuides -HarnessRoot $harnessRoot -ScriptDir $ScriptDir -StagedDir $guidesDir
    $hookScriptPath = Join-Path $harnessRoot "scripts\hooks\session_start.py"
    $runtimeScriptsDir = Join-Path (Split-Path -Parent $ScriptDir) "scripts\error-journal"
    $skillsDir = Join-Path (Split-Path -Parent $ScriptDir) "skills"
    $rulesDir = Join-Path $ScriptDir "rules"
    $skillPath = Join-Path $ScriptDir "SKILL.md"
    $claudePath = Join-Path $ScriptDir "CLAUDE.md"
    $agentsPath = Join-Path $ScriptDir "AGENTS.md"
    $errorJournalTemplatePath = Join-Path $guidesDir "error-journal-template.md"

    if (-not (Test-Path -LiteralPath $ownGuidesDir) -and -not (Test-Path -LiteralPath (Join-Path $ScriptDir "shared-guides.txt"))) {
        throw "Missing guides directory and shared-guides.txt under $ScriptDir"
    }
    Assert-HarnessPathExists -Path $hookScriptPath -Message "Missing hook script: $hookScriptPath"
    Assert-HarnessPathExists -Path $runtimeScriptsDir -Message "Missing runtime scripts directory: $runtimeScriptsDir"
    Assert-HarnessPathExists -Path $skillsDir -Message "Missing harness skills directory: $skillsDir"
    Assert-HarnessPathExists -Path $skillPath -Message "Missing SKILL.md: $skillPath"
    Assert-HarnessPathExists -Path $CodexSkillPath -Message "Missing Codex skill template: $CodexSkillPath"
    Assert-HarnessPathExists -Path $claudePath -Message "Missing CLAUDE.md: $claudePath"
    Assert-HarnessPathExists -Path $agentsPath -Message "Missing AGENTS.md: $agentsPath"
    Assert-HarnessPathExists -Path $errorJournalTemplatePath -Message "Missing error-journal-template.md (own guides/ or shared manifest): $errorJournalTemplatePath"

    Write-Host ""
    Write-Host "============================================"
    Write-Host "  $DisplayName install"
    Write-Host "============================================"
    Write-Host ""
    Write-Host "  Script dir:   $ScriptDir"
    Write-Host "  Project dir:  $projectDir"
    Write-Host ""

    Write-Host "--------------------------------------------"
    Write-Host "[Step 1] Install global skill files"
    Write-Host "--------------------------------------------"
    Write-Host ""

    $claudeSkillDir = Join-Path $homeDir ".claude\skills\$ModuleName"
    New-Item -ItemType Directory -Path $claudeSkillDir -Force | Out-Null
    Copy-Item -LiteralPath $skillPath -Destination (Join-Path $claudeSkillDir "SKILL.md") -Force
    Write-Host "  OK $claudeSkillDir\SKILL.md"

    # Codex 官方的用户级 skill 目录是 ~/.agents/skills；1.10.0 及更早版本装在 $CODEX_HOME/skills（旧位置），
    # 两处同名会重复触发，迁移时把旧的删掉。
    $codexSkillDir = Join-Path $homeDir ".agents\skills\$ModuleName"
    New-Item -ItemType Directory -Path $codexSkillDir -Force | Out-Null
    Set-Utf8NoBomContent -Path (Join-Path $codexSkillDir "SKILL.md") -Value (Get-Content -LiteralPath $CodexSkillPath -Raw)
    Write-Host "  OK $codexSkillDir\SKILL.md"
    $legacyCodexSkillDir = Join-Path $codexHome "skills\$ModuleName"
    if (Test-Path -LiteralPath (Join-Path $legacyCodexSkillDir "SKILL.md")) {
        Remove-Item -LiteralPath $legacyCodexSkillDir -Recurse -Force
        Write-Host "  OK removed legacy $legacyCodexSkillDir (Codex now reads ~/.agents/skills)"
    }
    Write-Host ""

    Write-Host "--------------------------------------------"
    Write-Host "[Step 2] Install project files"
    Write-Host "--------------------------------------------"
    Write-Host ""

    Install-HarnessEntryFile -Source $claudePath -Destination (Join-Path $projectDir "CLAUDE.md") -Label "CLAUDE.md" -Force $forceProjectFiles
    Install-HarnessEntryFile -Source $agentsPath -Destination (Join-Path $projectDir "AGENTS.md") -Label "AGENTS.md" -Force $forceProjectFiles

    $projectHarnessDir = Join-Path $projectDir ".harness"
    $projectGuidesDir = Join-Path $projectHarnessDir "guides"
    New-Item -ItemType Directory -Path $projectGuidesDir -Force | Out-Null

    $guideCopied = 0
    $guidePreserved = 0
    $guideStale = 0
    $guideFiles = Get-ChildItem -LiteralPath $guidesDir -File -Filter *.md
    foreach ($guideFile in $guideFiles) {
        if ($guideFile.Name -eq "error-journal-template.md") {
            continue
        }

        $destination = Join-Path $projectGuidesDir $guideFile.Name
        if ($forceGuides -eq "1" -or -not (Test-Path -LiteralPath $destination)) {
            Copy-Item -LiteralPath $guideFile.FullName -Destination $destination -Force
            $guideCopied++
        }
        else {
            $guidePreserved++
            if (-not (Test-HarnessSameContent -PathA $guideFile.FullName -PathB $destination)) {
                $guideStale++
                $script:harnessStaleGuides += $guideFile.Name
            }
        }
    }

    $guideCount = (Get-ChildItem -LiteralPath $projectGuidesDir -File -Filter *.md).Count
    if ($forceGuides -eq "1") {
        Write-Host "  OK .harness/guides/ - $guideCount guides (refreshed $guideCopied)"
    }
    else {
        Write-Host "  OK .harness/guides/ - $guideCount guides (added $guideCopied, preserved $guidePreserved)"
        if ($guideStale -gt 0) {
            Write-Host "  WARN $guideStale of them differ from this version template (not overwritten)"
        }
    }

    $projectScriptsDir = Join-Path $projectHarnessDir "scripts"
    New-Item -ItemType Directory -Path $projectScriptsDir -Force | Out-Null
    $runtimeCopied = 0
    $runtimePreserved = 0
    $runtimeFiles = Get-ChildItem -LiteralPath $runtimeScriptsDir -File
    foreach ($runtimeFile in $runtimeFiles) {
        $destination = Join-Path $projectScriptsDir $runtimeFile.Name
        if ($forceProjectFiles -eq "1" -or -not (Test-Path -LiteralPath $destination)) {
            Copy-Item -LiteralPath $runtimeFile.FullName -Destination $destination -Force
            $runtimeCopied++
        }
        else {
            $runtimePreserved++
        }
    }
    if ($forceProjectFiles -eq "1") {
        Write-Host "  OK .harness/scripts/ - refreshed $runtimeCopied runtime scripts"
    }
    else {
        Write-Host "  OK .harness/scripts/ - added $runtimeCopied, preserved $runtimePreserved"
    }

    $projectHooksDir = Join-Path $projectHarnessDir "hooks"
    New-Item -ItemType Directory -Path $projectHooksDir -Force | Out-Null
    Copy-Item -LiteralPath $hookScriptPath -Destination (Join-Path $projectHooksDir "session_start.py") -Force
    $hookPython = Get-HarnessPython
    if ($hookPython) {
        Register-HarnessHook -ConfigPath (Join-Path $projectDir ".claude\settings.json") -Python $hookPython
        Register-HarnessHook -ConfigPath (Join-Path $projectDir ".codex\hooks.json") -Python $hookPython
        Write-Host "  OK .harness/hooks/session_start.py registered in .claude/settings.json and .codex/hooks.json"
    }
    else {
        Write-Host "  WARN no python3 / python found; SessionStart hook not registered (script placed in .harness/hooks/, re-run setup after installing Python)"
    }

    $projectErrorJournalPath = Join-Path $projectHarnessDir "error-journal.md"
    if (-not (Test-Path -LiteralPath $projectErrorJournalPath)) {
        Copy-Item -LiteralPath $errorJournalTemplatePath -Destination $projectErrorJournalPath
        Write-Host "  OK .harness/error-journal.md"
    }
    else {
        Write-Host "  SKIP .harness/error-journal.md already exists"
    }
    Write-Host ""

    Write-Host "--------------------------------------------"
    Write-Host "[Step 3] Install project skills and rules"
    Write-Host "--------------------------------------------"
    Write-Host ""

    # 1.10.0 及更早版本装的是 .claude/commands/harness/，Claude Code 已把 commands 标为旧格式
    $legacyCommandsDir = Join-Path $projectDir ".claude\commands\harness"
    if (Test-Path -LiteralPath $legacyCommandsDir) {
        Remove-Item -LiteralPath $legacyCommandsDir -Recurse -Force
        $legacyCommandsParent = Join-Path $projectDir ".claude\commands"
        if ((Test-Path -LiteralPath $legacyCommandsParent) -and -not (Get-ChildItem -LiteralPath $legacyCommandsParent -Force)) {
            Remove-Item -LiteralPath $legacyCommandsParent -Force
        }
        Write-Host "  OK removed legacy .claude/commands/harness/ (replaced by skills)"
    }

    # 同一份 SKILL.md 双端各装一份：Claude Code 读 .claude/skills，Codex 读 .agents/skills
    Copy-HarnessTree -SourceDir $skillsDir -TargetDir (Join-Path $projectDir ".claude\skills") -Force $forceProjectFiles -Label ".claude/skills/harness-*/"
    Copy-HarnessTree -SourceDir $skillsDir -TargetDir (Join-Path $projectDir ".agents\skills") -Force $forceProjectFiles -Label ".agents/skills/harness-*/"
    # Claude Code 的路径限定规则：只在读到匹配文件时把对应 guide 拉进上下文
    if (Test-Path -LiteralPath $rulesDir) {
        Copy-HarnessTree -SourceDir $rulesDir -TargetDir (Join-Path $projectDir ".claude\rules") -Force $forceProjectFiles -Label ".claude/rules/harness-*.md"
    }
    Write-Host ""

    Write-Host "--------------------------------------------"
    Write-Host "[Step 4] Update .gitignore and .git/info/exclude"
    Write-Host "--------------------------------------------"
    Write-Host ""

    # 忽略规则单一源头：与 scripts/install-harness.sh 保持一致。
    #   - .gitignore(可入库): 只放通用构建/编辑器/OS 产物。
    #   - .git/info/exclude(仅本地): 本地工具与 Agent 运行产物，避免忽略规则本身泄露 AI 工具链。
    #   go-pkg-harness 是纯扩展包，不产生 .env 运行配置；其余 harness 面向应用/服务，一律忽略 .env。
    #   1.7.0 ~ 1.10.0 写过整目录 tools/（会挡住业务自己的 tools/），之后短暂写过 tools/openspec/；
    #   openspec-auto 现在全部落在 .openspec-auto/ 下，两条旧规则都要剔除。
    $legacyToolsPatterns = @("tools/", "tools/openspec/")
    $gitignorePatterns = @(
        ".idea/",
        ".vscode/",
        ".Ds_Store",
        ".DS_Store",
        "*.log",
        "*.out"
    )
    if ($ModuleName -ne "go-pkg-harness") {
        $gitignorePatterns += ".env"
    }
    $excludePatterns = @(
        ".openspec-auto-backup/",
        ".openspec-auto/",
        ".harness/",
        ".claude/",
        ".codex/",
        ".agents/",
        "openspec/",
        "AGENTS.md",
        "CLAUDE.md",
        ".learnings/",
        "findings.md",
        "progress.md",
        "task_plan.md"
    )

    # -- 4a. .gitignore: generic build / editor / OS artifacts only --
    $gitignorePath = Join-Path $projectDir ".gitignore"
    if (-not (Test-Path -LiteralPath $gitignorePath)) {
        New-Item -ItemType File -Path $gitignorePath | Out-Null
        Write-Host "  OK created .gitignore"
    }
    else {
        Write-Host "  SKIP .gitignore already exists, appending missing rules"
    }

    # 迁移: 剔除旧版本误写进 .gitignore 的本地工具规则与旧标题(移到 .git/info/exclude)
    $legacyLines = @(Get-HarnessLegacyGitignoreHeader) + $excludePatterns + $legacyToolsPatterns
    if (Remove-LinesFromFile -Path $gitignorePath -Lines $legacyLines) {
        Write-Host "  OK removed legacy local-tool rules from .gitignore (migrated to .git/info/exclude)"
    }

    $gitignoreUpdated = $false
    foreach ($pattern in $gitignorePatterns) {
        if (Add-UniqueLine -Path $gitignorePath -Line $pattern) {
            $gitignoreUpdated = $true
        }
    }
    if ($gitignoreUpdated) {
        Write-Host "  OK .gitignore updated with generic rules"
    }
    else {
        Write-Host "  SKIP .gitignore already contains generic rules"
    }

    # -- 4b. .git/info/exclude: local tool & agent runtime artifacts (never tracked) --
    $excludeFile = Resolve-HarnessExcludeFile -ProjectDir $projectDir
    if ($excludeFile) {
        $excludeDir = Split-Path -Parent $excludeFile
        if ($excludeDir -and -not (Test-Path -LiteralPath $excludeDir)) {
            New-Item -ItemType Directory -Path $excludeDir -Force | Out-Null
        }
        if (-not (Test-Path -LiteralPath $excludeFile)) {
            New-Item -ItemType File -Path $excludeFile | Out-Null
        }

        $excludeUpdated = $false
        $excludeHeader = Get-HarnessExcludeHeader
        if (Remove-LinesFromFile -Path $excludeFile -Lines $legacyToolsPatterns) {
            $excludeUpdated = $true
        }
        if (Add-UniqueLine -Path $excludeFile -Line $excludeHeader) {
            $excludeUpdated = $true
        }
        foreach ($pattern in $excludePatterns) {
            if (Add-UniqueLine -Path $excludeFile -Line $pattern) {
                $excludeUpdated = $true
            }
        }
        if ($excludeUpdated) {
            Write-Host "  OK .git/info/exclude updated with local-tool rules"
        }
        else {
            Write-Host "  SKIP .git/info/exclude already contains rules"
        }
    }
    else {
        Write-Host "  WARN no git repo detected, skipped .git/info/exclude"
        Write-Host "       run 'git init' then re-run setup to locally ignore .harness/, CLAUDE.md, etc."
    }
    Write-Host ""

    Write-Host "--------------------------------------------"
    Write-Host "[Step 5] Write .harness/VERSION"
    Write-Host "--------------------------------------------"
    Write-Host ""
    Write-HarnessVersion -ProjectDir $projectDir -ModuleName $ModuleName -ScriptDir $ScriptDir
    Remove-Item -LiteralPath $guidesDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host ""

    Write-Host "============================================"
    Write-Host "  Install complete"
    Write-Host "============================================"
    Write-Host ""

    if ($script:harnessStaleProjectFiles.Count -gt 0 -or $script:harnessStaleGuides.Count -gt 0) {
        Write-Host "--------------------------------------------"
        Write-Host "  WARN these files exist and differ from this version template; not overwritten"
        Write-Host "--------------------------------------------"
        if ($script:harnessStaleProjectFiles.Count -gt 0) {
            Write-Host ("    project files: " + ($script:harnessStaleProjectFiles -join " "))
        }
        if ($script:harnessStaleGuides.Count -gt 0) {
            Write-Host ("    guides:        " + ($script:harnessStaleGuides -join " "))
        }
        Write-Host ""
        Write-Host "  A difference means either the local copy is behind, or it was customized on purpose."
        Write-Host "  Diff each one to tell which. Once you are sure no local content needs preserving, force refresh with:"
        Write-Host '    $env:HARNESS_FORCE_PROJECT_FILES=1; $env:HARNESS_FORCE_GUIDES=1'
        Write-Host ("    powershell -NoProfile -ExecutionPolicy Bypass -File " + (Join-Path $ScriptDir "setup.ps1"))
        Write-Host ""
        Write-Host "  Note: refreshing CLAUDE.md / AGENTS.md overwrites the whole file; the openspec-auto"
        Write-Host "  managed block (OPENSPEC-AUTO:START/END) is preserved, any other local edits are lost."
        Write-Host ""
    }
}
