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
        if ($lines -contains $Line) {
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

function Invoke-HarnessSetup {
    param(
        [string]$ScriptDir,
        [string]$ModuleName,
        [string]$DisplayName,
        [string]$CodexSkillContent
    )

    $projectDir = (Get-Location).Path
    $forceGuides = if ($env:HARNESS_FORCE_GUIDES) { $env:HARNESS_FORCE_GUIDES } else { "0" }
    $homeDir = Get-HarnessHomeDir
    $codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $homeDir ".codex" }

    $guidesDir = Join-Path $ScriptDir "guides"
    $skillPath = Join-Path $ScriptDir "SKILL.md"
    $claudePath = Join-Path $ScriptDir "CLAUDE.md"
    $agentsPath = Join-Path $ScriptDir "AGENTS.md"
    $errorJournalTemplatePath = Join-Path $guidesDir "error-journal-template.md"

    Assert-HarnessPathExists -Path $guidesDir -Message "Missing guides directory: $guidesDir"
    Assert-HarnessPathExists -Path $skillPath -Message "Missing SKILL.md: $skillPath"
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
    Set-Utf8NoBomContent -Path (Join-Path $codexSkillDir "SKILL.md") -Value $CodexSkillContent
    Write-Host "  OK $codexSkillDir\SKILL.md"
    Write-Host ""

    Write-Host "--------------------------------------------"
    Write-Host "[Step 2] Install project files"
    Write-Host "--------------------------------------------"
    Write-Host ""

    $projectClaudePath = Join-Path $projectDir "CLAUDE.md"
    if (-not (Test-Path -LiteralPath $projectClaudePath)) {
        Copy-Item -LiteralPath $claudePath -Destination $projectClaudePath
        Write-Host "  OK CLAUDE.md"
    }
    else {
        Write-Host "  SKIP CLAUDE.md already exists"
    }

    $projectAgentsPath = Join-Path $projectDir "AGENTS.md"
    if (-not (Test-Path -LiteralPath $projectAgentsPath)) {
        Copy-Item -LiteralPath $agentsPath -Destination $projectAgentsPath
        Write-Host "  OK AGENTS.md"
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
    Write-Host "[Step 3] Update .gitignore"
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

    foreach ($pattern in @(".harness/error-journal.md", ".idea/", ".DS_Store")) {
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

    Write-Host "============================================"
    Write-Host "  Install complete"
    Write-Host "============================================"
    Write-Host ""
}
