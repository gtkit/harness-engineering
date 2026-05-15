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

    if (Test-Path -LiteralPath $Path) {
        $lines = Get-Content -LiteralPath $Path
        if ($lines -ccontains $Line) {
            return $false
        }
    }

    Add-Content -LiteralPath $Path -Value $Line
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
    $forceGuides = if ($env:HARNESS_FORCE_GUIDES) { $env:HARNESS_FORCE_GUIDES } else { "0" }
    $forceProjectFiles = if ($env:HARNESS_FORCE_PROJECT_FILES) { $env:HARNESS_FORCE_PROJECT_FILES } else { "0" }
    $homeDir = Get-HarnessHomeDir
    $codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $homeDir ".codex" }

    $guidesDir = Join-Path $ScriptDir "guides"
    $runtimeScriptsDir = Join-Path (Split-Path -Parent $ScriptDir) "scripts\error-journal"
    $commandsDir = Join-Path (Split-Path -Parent $ScriptDir) "commands\harness"
    $skillPath = Join-Path $ScriptDir "SKILL.md"
    $claudePath = Join-Path $ScriptDir "CLAUDE.md"
    $agentsPath = Join-Path $ScriptDir "AGENTS.md"
    $errorJournalTemplatePath = Join-Path $guidesDir "error-journal-template.md"

    Assert-HarnessPathExists -Path $guidesDir -Message "Missing guides directory: $guidesDir"
    Assert-HarnessPathExists -Path $runtimeScriptsDir -Message "Missing runtime scripts directory: $runtimeScriptsDir"
    Assert-HarnessPathExists -Path $commandsDir -Message "Missing harness commands directory: $commandsDir"
    Assert-HarnessPathExists -Path $skillPath -Message "Missing SKILL.md: $skillPath"
    Assert-HarnessPathExists -Path $CodexSkillPath -Message "Missing Codex skill template: $CodexSkillPath"
    Assert-HarnessPathExists -Path $claudePath -Message "Missing CLAUDE.md: $claudePath"
    Assert-HarnessPathExists -Path $agentsPath -Message "Missing AGENTS.md: $agentsPath"
    Assert-HarnessPathExists -Path $errorJournalTemplatePath -Message "Missing error-journal-template.md: $errorJournalTemplatePath"

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

    $codexSkillDir = Join-Path $codexHome "skills\$ModuleName"
    New-Item -ItemType Directory -Path $codexSkillDir -Force | Out-Null
    Set-Utf8NoBomContent -Path (Join-Path $codexSkillDir "SKILL.md") -Value (Get-Content -LiteralPath $CodexSkillPath -Raw)
    Write-Host "  OK $codexSkillDir\SKILL.md"
    Write-Host ""

    Write-Host "--------------------------------------------"
    Write-Host "[Step 2] Install project files"
    Write-Host "--------------------------------------------"
    Write-Host ""

    $projectClaudePath = Join-Path $projectDir "CLAUDE.md"
    if ($forceProjectFiles -eq "1" -or -not (Test-Path -LiteralPath $projectClaudePath)) {
        Copy-Item -LiteralPath $claudePath -Destination $projectClaudePath
        if ($forceProjectFiles -eq "1") {
            Write-Host "  OK CLAUDE.md (refreshed)"
        }
        else {
            Write-Host "  OK CLAUDE.md"
        }
    }
    else {
        Write-Host "  SKIP CLAUDE.md already exists"
    }

    $projectAgentsPath = Join-Path $projectDir "AGENTS.md"
    if ($forceProjectFiles -eq "1" -or -not (Test-Path -LiteralPath $projectAgentsPath)) {
        Copy-Item -LiteralPath $agentsPath -Destination $projectAgentsPath
        if ($forceProjectFiles -eq "1") {
            Write-Host "  OK AGENTS.md (refreshed)"
        }
        else {
            Write-Host "  OK AGENTS.md"
        }
    }
    else {
        Write-Host "  SKIP AGENTS.md already exists"
    }

    $projectHarnessDir = Join-Path $projectDir ".harness"
    $projectGuidesDir = Join-Path $projectHarnessDir "guides"
    New-Item -ItemType Directory -Path $projectGuidesDir -Force | Out-Null

    $guideCopied = 0
    $guidePreserved = 0
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
        }
    }

    $guideCount = (Get-ChildItem -LiteralPath $projectGuidesDir -File -Filter *.md).Count
    if ($forceGuides -eq "1") {
        Write-Host "  OK .harness/guides/ - $guideCount guides (refreshed $guideCopied)"
    }
    else {
        Write-Host "  OK .harness/guides/ - $guideCount guides (added $guideCopied, preserved $guidePreserved)"
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
    Write-Host "[Step 3] Install Claude Code commands"
    Write-Host "--------------------------------------------"
    Write-Host ""

    $projectCommandsDir = Join-Path $projectDir ".claude\commands\harness"
    New-Item -ItemType Directory -Path $projectCommandsDir -Force | Out-Null
    $commandCopied = 0
    $commandPreserved = 0
    $commandFiles = Get-ChildItem -LiteralPath $commandsDir -File -Filter *.md
    if ($commandFiles.Count -eq 0) {
        throw "No harness command templates found in $commandsDir"
    }
    foreach ($commandFile in $commandFiles) {
        $destination = Join-Path $projectCommandsDir $commandFile.Name
        if ($forceProjectFiles -eq "1" -or -not (Test-Path -LiteralPath $destination)) {
            Copy-Item -LiteralPath $commandFile.FullName -Destination $destination -Force
            $commandCopied++
        }
        else {
            $commandPreserved++
        }
    }
    if ($forceProjectFiles -eq "1") {
        Write-Host "  OK .claude/commands/harness/ - refreshed $commandCopied commands"
    }
    else {
        Write-Host "  OK .claude/commands/harness/ - added $commandCopied, preserved $commandPreserved"
    }
    Write-Host ""

    Write-Host "--------------------------------------------"
    Write-Host "[Step 4] Update .gitignore"
    Write-Host "--------------------------------------------"
    Write-Host ""

    $gitignorePath = Join-Path $projectDir ".gitignore"
    if (-not (Test-Path -LiteralPath $gitignorePath)) {
        New-Item -ItemType File -Path $gitignorePath | Out-Null
        Write-Host "  OK created .gitignore"
    }
    else {
        Write-Host "  SKIP .gitignore already exists, appending missing rules"
    }

    $gitignoreUpdated = $false
    if (Add-UniqueLine -Path $gitignorePath -Line "") {
        $gitignoreUpdated = $true
    }
    if (Add-UniqueLine -Path $gitignorePath -Line "# Harness: local agent runtime artifacts") {
        $gitignoreUpdated = $true
    }

    $patterns = @(
        ".openspec-auto-backup/",
        ".openspec-auto/",
        ".idea/",
        ".vscode/",
        ".Ds_Store",
        ".DS_Store",
        "*.log",
        "findings.md",
        "progress.md",
        "task_plan.md",
        ".harness/error-journal.md",
        ".claude/",
        ".codex/",
        ".agents/",
        "openspec/",
        "AGENTS.md",
        "CLAUDE.md",
        "tools/",
        ".harness/VERSION"
    )
    foreach ($pattern in $patterns) {
        if (Add-UniqueLine -Path $gitignorePath -Line $pattern) {
            $gitignoreUpdated = $true
        }
    }

    if ($gitignoreUpdated) {
        Write-Host "  OK .gitignore updated with harness rules"
    }
    else {
        Write-Host "  SKIP .gitignore already contains harness rules"
    }
    Write-Host ""

    Write-Host "--------------------------------------------"
    Write-Host "[Step 5] Write .harness/VERSION"
    Write-Host "--------------------------------------------"
    Write-Host ""
    Write-HarnessVersion -ProjectDir $projectDir -ModuleName $ModuleName -ScriptDir $ScriptDir
    Write-Host ""

    Write-Host "============================================"
    Write-Host "  Install complete"
    Write-Host "============================================"
    Write-Host ""
}
