Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$helperPath = Join-Path (Split-Path -Parent $scriptDir) "scripts\install-harness.ps1"
. $helperPath

$codexSkillPath = Join-Path $scriptDir "SKILL.codex.md"

Invoke-HarnessSetup `
    -ScriptDir $scriptDir `
    -ModuleName "go-grpc-harness" `
    -DisplayName "go-grpc-harness" `
    -CodexSkillPath $codexSkillPath
