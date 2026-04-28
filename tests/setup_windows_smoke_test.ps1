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
        Assert-PathExists (Join-Path $homeDir ".claude\skills\$module\SKILL.md")
        Assert-PathExists (Join-Path $homeDir ".codex\skills\$module\SKILL.md")
        Assert-FileContains (Join-Path $homeDir ".claude\skills\$module\SKILL.md") "CLAUDE.md"
        Assert-FileContains (Join-Path $homeDir ".claude\skills\$module\SKILL.md") "AGENTS.md"
        Assert-FileContains (Join-Path $homeDir ".codex\skills\$module\SKILL.md") "AGENTS.md"
        Assert-FileNotContains (Join-Path $homeDir ".codex\skills\$module\SKILL.md") "CLAUDE.md"
        Assert-LineExists (Join-Path $projectDir ".gitignore") ".harness/error-journal.md"
        Assert-LineExists (Join-Path $projectDir ".gitignore") ".idea/"
        Assert-LineExists (Join-Path $projectDir ".gitignore") ".DS_Store"
        Assert-LineExists (Join-Path $projectDir ".gitignore") "findings.md"
        Assert-LineExists (Join-Path $projectDir ".gitignore") "progress.md"
        Assert-LineExists (Join-Path $projectDir ".gitignore") "task_plan.md"
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

    Set-Content -LiteralPath (Join-Path $preserveProjectDir "CLAUDE.md") -Value "LOCAL CLAUDE"
    Set-Content -LiteralPath (Join-Path $preserveProjectDir "AGENTS.md") -Value "LOCAL AGENTS"
    Invoke-SetupPs1 -HarnessDir "go-harness" -ProjectDir $preserveProjectDir -SandboxHome $preserveHomeDir -ForceProjectFiles
    Assert-FileContains (Join-Path $preserveProjectDir "CLAUDE.md") "## 分层架构（不可逾越）"
    Assert-FileContains (Join-Path $preserveProjectDir "AGENTS.md") "## 分层架构（不可逾越）"
    Assert-FileNotContains (Join-Path $preserveProjectDir "CLAUDE.md") "LOCAL CLAUDE"
    Assert-FileNotContains (Join-Path $preserveProjectDir "AGENTS.md") "LOCAL AGENTS"

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
    }
}
finally {
    Remove-Item -LiteralPath $tmpDir -Recurse -Force
}

Write-Host "windows setup smoke test passed"
