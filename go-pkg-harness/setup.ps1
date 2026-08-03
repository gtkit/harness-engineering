Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$helperPath = Join-Path (Split-Path -Parent $scriptDir) "scripts\install-harness.ps1"
. $helperPath

$codexSkillPath = Join-Path $scriptDir "SKILL.codex.md"

# Returns the package name declared by existing .go files in the directory
# (version.go itself and test files excluded); empty string when there is none.
function Get-GoPkgExistingPackageName {
    param([string]$ProjectDir)

    $goFiles = @(Get-ChildItem -LiteralPath $ProjectDir -Filter "*.go" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne "version.go" -and $_.Name -notlike "*_test.go" } |
        Sort-Object -Property Name)
    foreach ($goFile in $goFiles) {
        foreach ($line in (Get-Content -LiteralPath $goFile.FullName)) {
            if ($line -match '^package\s+([A-Za-z_][A-Za-z0-9_]*)') {
                return $Matches[1]
            }
        }
    }
    return ""
}

function Install-GoPkgProjectFiles {
    param([string]$TemplateDir)

    Assert-HarnessPathExists -Path $TemplateDir -Message "Missing project templates directory: $TemplateDir"

    $makefileTemplatePath = Join-Path $TemplateDir "Makefile"
    $versionTemplatePath = Join-Path $TemplateDir "version.go.tmpl"
    Assert-HarnessPathExists -Path $makefileTemplatePath -Message "Missing Makefile template: $makefileTemplatePath"
    Assert-HarnessPathExists -Path $versionTemplatePath -Message "Missing version.go template: $versionTemplatePath"

    $projectDir = (Get-Location).Path
    $forceProjectFiles = if ($env:HARNESS_FORCE_PROJECT_FILES) { $env:HARNESS_FORCE_PROJECT_FILES } else { "0" }

    Write-Host "--------------------------------------------"
    Write-Host "[go-pkg] Generate package project files"
    Write-Host "--------------------------------------------"
    Write-Host ""

    $makefilePath = Join-Path $projectDir "Makefile"
    $makefileExists = Test-Path -LiteralPath $makefilePath -PathType Leaf
    $makefileEmpty = $makefileExists -and ((Get-Item -LiteralPath $makefilePath).Length -eq 0)
    if ($forceProjectFiles -eq "1" -or -not $makefileExists -or $makefileEmpty) {
        Copy-Item -LiteralPath $makefileTemplatePath -Destination $makefilePath -Force
        if ($forceProjectFiles -eq "1") {
            Write-Host "  OK Makefile (refreshed)"
        }
        elseif ($makefileEmpty) {
            Write-Host "  OK Makefile (wrote template content)"
        }
        else {
            Write-Host "  OK Makefile"
        }
    }
    else {
        Write-Host "  SKIP Makefile already exists"
    }

    $dirName = Split-Path -Leaf $projectDir
    # Reuse the package name declared by existing .go files (all files in one directory must
    # agree, otherwise the package does not compile); fall back to the directory name with
    # dashes removed (lenovo-pay -> lenovopay).
    $existingPackage = Get-GoPkgExistingPackageName -ProjectDir $projectDir
    if ($existingPackage) {
        $packageName = $existingPackage
        $packageNote = ", reused from existing Go files"
    }
    else {
        $packageName = $dirName.Replace("-", "")
        $packageNote = if ($packageName -ne $dirName) { ", dashes removed from directory name" } else { "" }
        $goKeywords = @(
            "break", "default", "func", "interface", "select",
            "case", "defer", "go", "map", "struct",
            "chan", "else", "goto", "package", "switch",
            "const", "fallthrough", "if", "range", "type",
            "continue", "for", "import", "return", "var"
        )
        if ($packageName -notmatch '^[A-Za-z_][A-Za-z0-9_]*$' -or $goKeywords -contains $packageName) {
            Write-Host "  WARN version.go skipped: directory name '$dirName' cannot map to a valid Go package name"
            Write-Host ""
            return
        }
    }

    $versionPath = Join-Path $projectDir "version.go"
    $versionExists = Test-Path -LiteralPath $versionPath -PathType Leaf
    $versionEmpty = $versionExists -and ((Get-Item -LiteralPath $versionPath).Length -eq 0)
    if ($forceProjectFiles -eq "1" -or -not $versionExists -or $versionEmpty) {
        $content = (Get-Content -LiteralPath $versionTemplatePath -Raw).Replace("{{PACKAGE_NAME}}", $packageName)
        Set-Utf8NoBomContent -Path $versionPath -Value $content
        if ($forceProjectFiles -eq "1") {
            Write-Host "  OK version.go (package $packageName$packageNote, refreshed)"
        }
        elseif ($versionEmpty) {
            Write-Host "  OK version.go (package $packageName$packageNote, wrote template content)"
        }
        else {
            Write-Host "  OK version.go (package $packageName$packageNote)"
        }
    }
    else {
        Write-Host "  SKIP version.go already exists"
    }
    Write-Host ""
}

Invoke-HarnessSetup `
    -ScriptDir $scriptDir `
    -ModuleName "go-pkg-harness" `
    -DisplayName "go-pkg-harness" `
    -CodexSkillPath $codexSkillPath

Install-GoPkgProjectFiles -TemplateDir (Join-Path $scriptDir "project-templates")
