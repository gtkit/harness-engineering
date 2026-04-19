Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$helperPath = Join-Path (Split-Path -Parent $scriptDir) "scripts\install-harness.ps1"
. $helperPath

$codexSkillContent = @'
---
name: laravel-harness
description: Laravel harness engineering skill for API and web projects.
---

# Laravel Harness Skill

The complete project rules live in the project's AGENTS.md file.
Detailed project guides live in .harness/guides/.
'@

Invoke-HarnessSetup `
    -ScriptDir $scriptDir `
    -ModuleName "laravel-harness" `
    -DisplayName "laravel-harness" `
    -CodexSkillContent $codexSkillContent
