[CmdletBinding()]
param(
    [string]$TargetDir,
    [switch]$ForceGuides
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

if ([string]::IsNullOrWhiteSpace($TargetDir)) {
    $TargetDir = Read-Host "请输入目标项目目录"
}

if ([string]::IsNullOrWhiteSpace($TargetDir)) {
    throw "目标项目目录不能为空。"
}

$PackageRoot = [System.IO.Path]::GetFullPath($PackageRoot)
$TargetDir = [System.IO.Path]::GetFullPath($TargetDir)

if ($PackageRoot -eq $TargetDir) {
    throw "目标项目目录不能和安装包目录相同。"
}

if (-not (Test-Path -LiteralPath $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}

$BackupRoot = Join-Path $TargetDir (".harness-install-backup\" + (Get-Date -Format "yyyyMMdd-HHmmss"))

$Entries = @(
    @{ Source = "AGENTS.md"; Destination = "AGENTS.md" },
    @{ Source = ".harness\checklists"; Destination = ".harness\checklists" },
    @{ Source = ".harness\reviews"; Destination = ".harness\reviews" },
    @{ Source = ".harness\templates"; Destination = ".harness\templates" },
    @{ Source = ".harness\validation"; Destination = ".harness\validation" },
    @{ Source = ".harness\skills"; Destination = ".harness\skills" },
    @{ Source = ".harness\error-journal.md"; Destination = ".harness\error-journal.md"; InstallMode = "Preserve" },
    @{ Source = "doc\harness\README.md"; Destination = "doc\harness\README.md" },
    @{ Source = "openspec\changes\cpp-linux-ai-harness"; Destination = "openspec\changes\cpp-linux-ai-harness" },
    @{ Source = "docs\superpowers\plans\2026-04-13-cpp-linux-ai-harness.md"; Destination = "docs\superpowers\plans\2026-04-13-cpp-linux-ai-harness.md" }
)

function Ensure-Directory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Backup-ExistingItem {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $relativePath = $Path.Substring($TargetDir.Length).TrimStart('\', '/')
    $backupPath = Join-Path $BackupRoot $relativePath

    Ensure-Directory -Path (Split-Path -Parent $backupPath)
    Move-Item -LiteralPath $Path -Destination $backupPath -Force
    Write-Host "[backup] $relativePath -> $backupPath"
}

function Install-Entry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceRelativePath,
        [Parameter(Mandatory = $true)]
        [string]$DestinationRelativePath,
        [string]$InstallMode = "Replace"
    )

    $sourcePath = Join-Path $PackageRoot $SourceRelativePath
    $destinationPath = Join-Path $TargetDir $DestinationRelativePath

    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "安装包缺少文件或目录: $SourceRelativePath"
    }

    if ($InstallMode -eq "Preserve" -and (Test-Path -LiteralPath $destinationPath)) {
        Write-Host "[keep] $DestinationRelativePath"
        return
    }

    Backup-ExistingItem -Path $destinationPath
    Ensure-Directory -Path (Split-Path -Parent $destinationPath)

    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Recurse -Force
    Write-Host "[install] $DestinationRelativePath"
}

function Install-GuideFiles {
    $sourceDir = Join-Path $PackageRoot ".harness\guides"
    $destinationDir = Join-Path $TargetDir ".harness\guides"

    if (-not (Test-Path -LiteralPath $sourceDir)) {
        throw "安装包缺少目录: .harness\guides"
    }

    Ensure-Directory -Path $destinationDir

    $installedCount = 0
    $preservedCount = 0

    foreach ($guide in Get-ChildItem -LiteralPath $sourceDir -File) {
        $destinationPath = Join-Path $destinationDir $guide.Name

        if ((-not $ForceGuides) -and (Test-Path -LiteralPath $destinationPath)) {
            $preservedCount++
            Write-Host "[keep] .harness\guides\$($guide.Name)"
            continue
        }

        Copy-Item -LiteralPath $guide.FullName -Destination $destinationPath -Force
        $installedCount++
        Write-Host "[install] .harness\guides\$($guide.Name)"
    }

    if ($ForceGuides) {
        Write-Host "[guides] 已强制刷新 $installedCount 个 guide 文件。"
    } else {
        Write-Host "[guides] 新增 $installedCount 个 guide 文件，保留 $preservedCount 个已有 guide。"
    }
}

function Add-GitIgnoreRule {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [string]$Rule
    )

    $existingRules = @()
    if (Test-Path -LiteralPath $FilePath) {
        $existingRules = Get-Content -LiteralPath $FilePath -ErrorAction SilentlyContinue
    }

    if ($existingRules -contains $Rule) {
        return $false
    }

    Add-Content -LiteralPath $FilePath -Value $Rule
    return $true
}

function Ensure-GitIgnoreRules {
    $gitignorePath = Join-Path $TargetDir ".gitignore"

    if (-not (Test-Path -LiteralPath $gitignorePath)) {
        New-Item -ItemType File -Path $gitignorePath -Force | Out-Null
        Write-Host "[install] .gitignore"
    } else {
        Write-Host "[keep] .gitignore"
    }

    $updated = $false
    $header = "# Harness: local agent/runtime artifacts"
    if (Add-GitIgnoreRule -FilePath $gitignorePath -Rule "") {
        $updated = $true
    }
    if (Add-GitIgnoreRule -FilePath $gitignorePath -Rule $header) {
        $updated = $true
    }

    foreach ($rule in @(".harness/error-journal.md", ".idea/", ".DS_Store", "findings.md", "progress.md", "task_plan.md")) {
        if (Add-GitIgnoreRule -FilePath $gitignorePath -Rule $rule) {
            $updated = $true
        }
    }

    if ($updated) {
        Write-Host "[gitignore] 已补齐 Harness 忽略规则。"
    } else {
        Write-Host "[gitignore] 已包含 Harness 忽略规则。"
    }
}

Write-Host ""
Write-Host "C++ Linux AI Harness Windows 安装器"
Write-Host "安装包目录: $PackageRoot"
Write-Host "目标项目目录: $TargetDir"
Write-Host ""

foreach ($entry in $Entries) {
    $installMode = "Replace"
    if ($entry.ContainsKey("InstallMode")) {
        $installMode = $entry.InstallMode
    }
    Install-Entry -SourceRelativePath $entry.Source -DestinationRelativePath $entry.Destination -InstallMode $installMode
}

Install-GuideFiles
Ensure-GitIgnoreRules

Write-Host ""
Write-Host "安装完成。"
Write-Host "如果有被替换的旧文件，已备份到: $BackupRoot"
Write-Host "建议下一步检查:"
Write-Host "1. $TargetDir\AGENTS.md"
Write-Host "2. $TargetDir\.harness\error-journal.md"
Write-Host "3. $TargetDir\doc\harness\README.md"
