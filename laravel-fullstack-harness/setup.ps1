Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$helperPath = Join-Path (Split-Path -Parent $scriptDir) "scripts\install-harness.ps1"
. $helperPath

$codexSkillContent = @'
---
name: laravel-fullstack-harness
description: Fullstack harness engineering skill for Laravel backend and Vue frontend projects.
---

# Laravel Fullstack Harness Skill

The complete project rules live in the project's AGENTS.md file.
Detailed project guides live in .harness/guides/.
'@

Invoke-HarnessSetup `
    -ScriptDir $scriptDir `
    -ModuleName "laravel-fullstack-harness" `
    -DisplayName "laravel-fullstack-harness" `
    -CodexSkillContent $codexSkillContent
