$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $PSScriptRoot

function Fail {
    param([string]$Message)

    throw $Message
}

function Assert-PathExists {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        Fail "Expected path to exist: $Path"
    }
}

function Assert-FileContains {
    param(
        [string]$Path,
        [string]$Expected
    )

    $content = Get-Content -LiteralPath $Path -Raw
    if (-not $content.Contains($Expected)) {
        Fail "Expected file $Path to contain: $Expected"
    }
}

function Assert-FileNotContains {
    param(
        [string]$Path,
        [string]$Unexpected
    )

    $content = Get-Content -LiteralPath $Path -Raw
    if ($content.Contains($Unexpected)) {
        Fail "Expected file $Path to not contain: $Unexpected"
    }
}

function Assert-LineExists {
    param(
        [string]$Path,
        [string]$Expected
    )

    $lines = Get-Content -LiteralPath $Path
    if (-not ($lines -contains $Expected)) {
        Fail "Expected file $Path to contain line: $Expected"
    }
}

function Assert-HarnessCommands {
    param([string]$ProjectDir)

    $commandsDir = Join-Path $ProjectDir ".claude\commands\harness"

    Assert-PathExists (Join-Path $commandsDir "doctor.md")
    Assert-PathExists (Join-Path $commandsDir "init-openspec.md")
    Assert-PathExists (Join-Path $commandsDir "research.md")
    Assert-PathExists (Join-Path $commandsDir "plan.md")
    Assert-PathExists (Join-Path $commandsDir "implement.md")
    Assert-PathExists (Join-Path $commandsDir "review.md")
    Assert-FileContains (Join-Path $commandsDir "doctor.md") "Harness Doctor"
    Assert-FileContains (Join-Path $commandsDir "research.md") "constraint set"
    Assert-FileContains (Join-Path $commandsDir "plan.md") "zero-decision"
    Assert-FileContains (Join-Path $commandsDir "implement.md") "approved plan"
    Assert-FileContains (Join-Path $commandsDir "review.md") "质量"
}

function Assert-GuideFileExists {
    param(
        [string]$ProjectDir,
        [string]$FileName
    )

    Assert-PathExists (Join-Path $ProjectDir ".harness\guides\$FileName")
}

function Assert-AllGuidesAreReferenced {
    param([string]$HarnessDir)

    $agentsPath = Join-Path (Join-Path $RootDir $HarnessDir) "AGENTS.md"
    $guidesDir = Join-Path (Join-Path $RootDir $HarnessDir) "guides"

    Get-ChildItem -LiteralPath $guidesDir -File -Filter *.md | ForEach-Object {
        if ($_.Name -eq "error-journal-template.md") {
            return
        }

        Assert-FileContains $agentsPath $_.Name
    }
}

function Assert-InstalledGuidesMatchSource {
    param(
        [string]$HarnessDir,
        [string]$ProjectDir
    )

    $guidesDir = Join-Path (Join-Path $RootDir $HarnessDir) "guides"
    $agentsPath = Join-Path $ProjectDir "AGENTS.md"

    Get-ChildItem -LiteralPath $guidesDir -File -Filter *.md | ForEach-Object {
        if ($_.Name -eq "error-journal-template.md") {
            return
        }

        Assert-GuideFileExists $ProjectDir $_.Name
        Assert-FileContains $agentsPath $_.Name
    }
}

function Assert-CodexWorkflowAliases {
    param([string]$ProjectDir)

    $agentsPath = Join-Path $ProjectDir "AGENTS.md"
    Assert-FileContains $agentsPath "Codex 命令化工作流兼容入口"
    Assert-FileContains $agentsPath "harness research: <需求>"
    Assert-FileContains $agentsPath "不把 `harness ...` 当作 shell 命令执行"
}

function Invoke-SetupPs1 {
    param(
        [string]$HarnessDir,
        [string]$ProjectDir,
        [string]$SandboxHome,
        [switch]$ForceProjectFiles
    )

    Push-Location $ProjectDir
    try {
        $env:HOME = $SandboxHome
        $env:USERPROFILE = $SandboxHome
        $env:CODEX_HOME = Join-Path $SandboxHome ".codex"
        $env:HARNESS_FORCE_PROJECT_FILES = if ($ForceProjectFiles) { "1" } else { "0" }
        $scriptPath = Join-Path (Join-Path $RootDir $HarnessDir) "setup.ps1"
        & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Fail "setup.ps1 failed for $HarnessDir"
        }
    }
    finally {
        Pop-Location
    }
}

function Invoke-SetupBat {
    param(
        [string]$HarnessDir,
        [string]$ProjectDir,
        [string]$SandboxHome
    )

    Push-Location $ProjectDir
    try {
        $env:HOME = $SandboxHome
        $env:USERPROFILE = $SandboxHome
        $env:CODEX_HOME = Join-Path $SandboxHome ".codex"
        $scriptPath = Join-Path (Join-Path $RootDir $HarnessDir) "setup.bat"
        & cmd.exe /c $scriptPath | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Fail "setup.bat failed for $HarnessDir"
        }
    }
    finally {
        Pop-Location
    }
}

$modules = @(
    "go-harness",
    "fullstack-harness",
    "go-pkg-harness",
    "laravel-harness",
    "laravel-fullstack-harness"
)

foreach ($module in $modules) {
    Assert-PathExists (Join-Path (Join-Path $RootDir $module) "setup.ps1")
    Assert-PathExists (Join-Path (Join-Path $RootDir $module) "setup.bat")
    Assert-AllGuidesAreReferenced $module
}

$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("harness-windows-smoke-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmpDir | Out-Null

try {
    foreach ($module in $modules) {
        $homeDir = Join-Path $tmpDir ($module + "-home")
        $projectDir = Join-Path $tmpDir ($module + "-project")
        New-Item -ItemType Directory -Path $homeDir | Out-Null
        New-Item -ItemType Directory -Path $projectDir | Out-Null

        Invoke-SetupPs1 -HarnessDir $module -ProjectDir $projectDir -SandboxHome $homeDir

        Assert-PathExists (Join-Path $projectDir "CLAUDE.md")
        Assert-PathExists (Join-Path $projectDir "AGENTS.md")
        Assert-PathExists (Join-Path $projectDir ".harness\error-journal.md")
        Assert-PathExists (Join-Path $projectDir ".harness\scripts\read-error-journal.ps1")
        Assert-PathExists (Join-Path $projectDir ".harness\scripts\append-error-journal.ps1")
        Assert-HarnessCommands $projectDir
        Assert-CodexWorkflowAliases $projectDir
        Assert-InstalledGuidesMatchSource -HarnessDir $module -ProjectDir $projectDir
        if ($module -eq "go-harness" -or $module -eq "fullstack-harness") {
            Assert-GuideFileExists $projectDir "testing-and-validation.md"
            Assert-GuideFileExists $projectDir "workers-and-scheduling.md"
            Assert-FileContains (Join-Path $projectDir "AGENTS.md") ".harness/guides/testing-and-validation.md"
            Assert-FileContains (Join-Path $projectDir "AGENTS.md") ".harness/guides/workers-and-scheduling.md"
        }
        Assert-PathExists (Join-Path $homeDir ".claude\skills\$module\SKILL.md")
        Assert-PathExists (Join-Path $homeDir ".codex\skills\$module\SKILL.md")
        Assert-FileContains (Join-Path $homeDir ".claude\skills\$module\SKILL.md") "CLAUDE.md"
        Assert-FileContains (Join-Path $homeDir ".claude\skills\$module\SKILL.md") "AGENTS.md"
        Assert-FileContains (Join-Path $homeDir ".codex\skills\$module\SKILL.md") "AGENTS.md"
        Assert-FileNotContains (Join-Path $homeDir ".codex\skills\$module\SKILL.md") "CLAUDE.md"
        $gitignoreBaseline = @(
            "# Harness: 本地工具与 Agent 运行产物",
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
            ".harness/",
            ".claude/",
            ".codex/",
            ".agents/",
            "openspec/",
            "AGENTS.md",
            "CLAUDE.md",
            "tools/"
        )
        foreach ($line in $gitignoreBaseline) {
            Assert-LineExists (Join-Path $projectDir ".gitignore") $line
        }
        Assert-FileNotContains (Join-Path $projectDir ".gitignore") ".harness/error-journal.md"
        Assert-FileNotContains (Join-Path $projectDir ".gitignore") ".harness/VERSION"

        Assert-FileNotContains (Join-Path $projectDir "AGENTS.md") "清理杂物"
        Assert-FileNotContains (Join-Path $projectDir "AGENTS.md") "必须删除并保持工作区干净"
        Assert-FileNotContains (Join-Path $projectDir "CLAUDE.md") "清理杂物"
        Assert-FileNotContains (Join-Path $projectDir "CLAUDE.md") "必须删除并保持工作区干净"

        $versionPath = Join-Path $projectDir ".harness/VERSION"
        Assert-PathExists $versionPath
        Assert-FileContains $versionPath "harness: $module"
        Assert-FileContains $versionPath "source-commit:"
        Assert-FileContains $versionPath "installed-at:"
        Assert-FileContains $versionPath "installer: setup.ps1"
    }

    $preserveHomeDir = Join-Path $tmpDir "preserve-home"
    $preserveProjectDir = Join-Path $tmpDir "preserve-project"
    New-Item -ItemType Directory -Path $preserveHomeDir | Out-Null
    New-Item -ItemType Directory -Path $preserveProjectDir | Out-Null

    Invoke-SetupPs1 -HarnessDir "go-harness" -ProjectDir $preserveProjectDir -SandboxHome $preserveHomeDir

    $architecturePath = Join-Path $preserveProjectDir ".harness\guides\architecture.md"
    Set-Content -LiteralPath $architecturePath -Value "LOCAL CHANGE"
    Invoke-SetupPs1 -HarnessDir "go-harness" -ProjectDir $preserveProjectDir -SandboxHome $preserveHomeDir
    Assert-FileContains $architecturePath "LOCAL CHANGE"

    $doctorCommandPath = Join-Path $preserveProjectDir ".claude\commands\harness\doctor.md"
    Set-Content -LiteralPath $doctorCommandPath -Value "LOCAL COMMAND"
    Invoke-SetupPs1 -HarnessDir "go-harness" -ProjectDir $preserveProjectDir -SandboxHome $preserveHomeDir
    Assert-FileContains $doctorCommandPath "LOCAL COMMAND"

    Set-Content -LiteralPath (Join-Path $preserveProjectDir "CLAUDE.md") -Value "LOCAL CLAUDE"
    Set-Content -LiteralPath (Join-Path $preserveProjectDir "AGENTS.md") -Value "LOCAL AGENTS"
    Invoke-SetupPs1 -HarnessDir "go-harness" -ProjectDir $preserveProjectDir -SandboxHome $preserveHomeDir -ForceProjectFiles
    Assert-FileContains (Join-Path $preserveProjectDir "CLAUDE.md") "## 分层架构（不可逾越）"
    Assert-FileContains (Join-Path $preserveProjectDir "AGENTS.md") "## 分层架构（不可逾越）"
    Assert-FileNotContains (Join-Path $preserveProjectDir "CLAUDE.md") "LOCAL CLAUDE"
    Assert-FileNotContains (Join-Path $preserveProjectDir "AGENTS.md") "LOCAL AGENTS"
    Assert-FileContains $doctorCommandPath "Harness Doctor"
    Assert-FileNotContains $doctorCommandPath "LOCAL COMMAND"

    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $preserveProjectDir ".harness\scripts\append-error-journal.ps1") `
        -RepoRoot $preserveProjectDir `
        -EventType "user-correction" `
        -Area "windows-smoke" `
        -Summary "windows smoke summary" | Out-Null
    Assert-FileContains (Join-Path $preserveProjectDir ".harness\error-journal.md") "windows smoke summary"

    foreach ($module in $modules) {
        $batchProjectDir = Join-Path $tmpDir ($module + "-batch-project")
        $batchHomeDir = Join-Path $tmpDir ($module + "-batch-home")
        New-Item -ItemType Directory -Path $batchProjectDir | Out-Null
        New-Item -ItemType Directory -Path $batchHomeDir | Out-Null

        Invoke-SetupBat -HarnessDir $module -ProjectDir $batchProjectDir -SandboxHome $batchHomeDir
        Assert-PathExists (Join-Path $batchProjectDir "CLAUDE.md")
        Assert-PathExists (Join-Path $batchProjectDir "AGENTS.md")
        Assert-HarnessCommands $batchProjectDir
        Assert-CodexWorkflowAliases $batchProjectDir
        Assert-InstalledGuidesMatchSource -HarnessDir $module -ProjectDir $batchProjectDir
        if ($module -eq "go-harness" -or $module -eq "fullstack-harness") {
            Assert-GuideFileExists $batchProjectDir "testing-and-validation.md"
            Assert-GuideFileExists $batchProjectDir "workers-and-scheduling.md"
        }
    }
}
finally {
    Remove-Item -LiteralPath $tmpDir -Recurse -Force
}

Write-Host "windows setup smoke test passed"
