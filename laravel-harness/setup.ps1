Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$helperPath = Join-Path (Split-Path -Parent $scriptDir) "scripts\install-harness.ps1"
. $helperPath

Invoke-HarnessSetup `
    -ScriptDir $scriptDir `
    -ModuleName "laravel-harness" `
    -DisplayName "laravel-harness"
