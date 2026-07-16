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

function Initialize-GitRepo {
    param([string]$ProjectDir)

    # setup 会把本地工具规则写进 .git/info/exclude，夹具需先是 git 仓库
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        return
    }
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    try {
        & git init -q $ProjectDir 2>$null | Out-Null
    }
    finally {
        $ErrorActionPreference = $prevEAP
    }
}

# .git/info/exclude 中文标题 "# 本地工具与运行产物（仅本地忽略，不进版本库）"（码点构造，规避编码问题）
function Get-ExcludeHeader {
    $codePoints = @(
        0x0023, 0x0020, 0x672C, 0x5730, 0x5DE5, 0x5177, 0x4E0E, 0x8FD0,
        0x884C, 0x4EA7, 0x7269, 0xFF08, 0x4EC5, 0x672C, 0x5730, 0x5FFD,
        0x7565, 0xFF0C, 0x4E0D, 0x8FDB, 0x7248, 0x672C, 0x5E93, 0xFF09
    )
    return (($codePoints | ForEach-Object { [char]$_ }) -join '')
}

# 旧标题 "# Harness: 本地工具与 Agent 运行产物"（码点构造）
function Get-LegacyGitignoreHeader {
    $codePoints = @(
        0x0023, 0x0020, 0x0048, 0x0061, 0x0072, 0x006E, 0x0065, 0x0073, 0x0073,
        0x003A, 0x0020,
        0x672C, 0x5730, 0x5DE5, 0x5177, 0x4E0E, 0x0020,
        0x0041, 0x0067, 0x0065, 0x006E, 0x0074, 0x0020,
        0x8FD0, 0x884C, 0x4EA7, 0x7269
    )
    return (($codePoints | ForEach-Object { [char]$_ }) -join '')
}

# .gitignore 只保留通用产物；本地工具规则必须落在 .git/info/exclude
function Assert-GitignoreSplit {
    param([string]$ProjectDir)

    $gitignorePath = Join-Path $ProjectDir ".gitignore"
    $excludePath = Join-Path $ProjectDir ".git\info\exclude"

    $generic = @(".idea/", ".vscode/", ".Ds_Store", ".DS_Store", "*.log")
    foreach ($line in $generic) {
        Assert-LineExists $gitignorePath $line
    }

    $localToolRules = @(
        ".openspec-auto-backup/",
        ".openspec-auto/",
        ".harness/",
        ".claude/",
        ".codex/",
        ".agents/",
        "openspec/",
        "AGENTS.md",
        "CLAUDE.md",
        "tools/",
        "findings.md",
        "progress.md",
        "task_plan.md"
    )
    $legacyHeader = Get-LegacyGitignoreHeader
    Assert-FileNotContains $gitignorePath $legacyHeader
    foreach ($rule in $localToolRules) {
        Assert-FileNotContains $gitignorePath $rule
    }

    Assert-PathExists $excludePath
    Assert-LineExists $excludePath (Get-ExcludeHeader)
    foreach ($rule in $localToolRules) {
        Assert-LineExists $excludePath $rule
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

function Assert-GoPkgProjectFiles {
    param([string]$ProjectDir)

    $packageName = Split-Path -Leaf $ProjectDir
    $makefilePath = Join-Path $ProjectDir "Makefile"
    $versionPath = Join-Path $ProjectDir "version.go"

    Assert-PathExists $makefilePath
    Assert-PathExists $versionPath
    Assert-FileContains $makefilePath "golangci-lint run"
    Assert-FileContains $makefilePath "govulncheck ./..."
    Assert-FileContains $makefilePath "git tag -a"
    Assert-FileContains $makefilePath "delcommit:"
    Assert-FileContains $makefilePath "git reset --soft HEAD~1"
    Assert-FileContains $versionPath "package $packageName"
    Assert-FileContains $versionPath 'const Version = "v0.1.0"'
}

function Invoke-SetupPs1 {
    param(
        [string]$HarnessDir,
        [string]$ProjectDir,
        [string]$SandboxHome,
        [switch]$ForceProjectFiles
    )

    Initialize-GitRepo $ProjectDir
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

    Initialize-GitRepo $ProjectDir
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
        if ($module -eq "go-pkg-harness") {
            $projectDir = Join-Path $tmpDir "pkgdemo"
        }
        else {
            $projectDir = Join-Path $tmpDir ($module + "-project")
        }
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
        Assert-GitignoreSplit $projectDir

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

        if ($module -eq "go-pkg-harness") {
            Assert-GoPkgProjectFiles $projectDir
        }
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

    # --- 迁移：旧版本把本地工具规则误写进 .gitignore，重跑 setup 应清理并迁移到 .git/info/exclude ---
    $migrateHomeDir = Join-Path $tmpDir "migrate-home"
    $migrateProjectDir = Join-Path $tmpDir "migrate-project"
    New-Item -ItemType Directory -Path $migrateHomeDir | Out-Null
    New-Item -ItemType Directory -Path $migrateProjectDir | Out-Null
    $legacyGitignore = @(
        "# custom",
        "/build/",
        ".idea/",
        ".DS_Store",
        "*.log",
        ".harness/",
        ".claude/",
        ".codex/",
        ".agents/",
        "openspec/",
        "CLAUDE.md",
        "AGENTS.md",
        "tools/",
        "findings.md",
        "progress.md",
        "task_plan.md",
        ".openspec-auto/",
        ".openspec-auto-backup/"
    ) -join "`n"
    Set-Content -LiteralPath (Join-Path $migrateProjectDir ".gitignore") -Value $legacyGitignore
    Invoke-SetupPs1 -HarnessDir "go-harness" -ProjectDir $migrateProjectDir -SandboxHome $migrateHomeDir
    Assert-LineExists (Join-Path $migrateProjectDir ".gitignore") "/build/"
    Assert-GitignoreSplit $migrateProjectDir

    foreach ($module in $modules) {
        if ($module -eq "go-pkg-harness") {
            $batchProjectDir = Join-Path $tmpDir "pkgdemobatch"
        }
        else {
            $batchProjectDir = Join-Path $tmpDir ($module + "-batch-project")
        }
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
        if ($module -eq "go-pkg-harness") {
            Assert-GoPkgProjectFiles $batchProjectDir
        }
    }

    $emptyPkgProjectDir = Join-Path $tmpDir "emptypkg"
    $emptyPkgHomeDir = Join-Path $tmpDir "emptypkg-home"
    New-Item -ItemType Directory -Path $emptyPkgProjectDir | Out-Null
    New-Item -ItemType Directory -Path $emptyPkgHomeDir | Out-Null
    New-Item -ItemType File -Path (Join-Path $emptyPkgProjectDir "Makefile") | Out-Null
    New-Item -ItemType File -Path (Join-Path $emptyPkgProjectDir "version.go") | Out-Null
    Invoke-SetupPs1 -HarnessDir "go-pkg-harness" -ProjectDir $emptyPkgProjectDir -SandboxHome $emptyPkgHomeDir
    Assert-GoPkgProjectFiles $emptyPkgProjectDir
}
finally {
    Remove-Item -LiteralPath $tmpDir -Recurse -Force
}

Write-Host "windows setup smoke test passed"
