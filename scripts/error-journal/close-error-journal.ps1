Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# 关闭一条错误记录：Status 从 open 改为 closed 并记下时间。SessionStart hook 只注入 open 的条目。
param(
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [Parameter(Mandatory = $true)][string]$Id,
    [string]$Resolution = ""
)

$file = Join-Path $RepoRoot ".harness/error-journal.md"
if (-not (Test-Path -LiteralPath $file)) {
    Write-Error "missing: $file"
    exit 1
}
$lines = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8) -split "\r?\n"
$heading = "## [$Id]"
if (-not ($lines | Where-Object { $_.StartsWith($heading) })) {
    Write-Error "not found: $Id"
    exit 1
}
$stamp = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
$out = New-Object System.Collections.Generic.List[string]
$inside = $false
foreach ($line in $lines) {
    if ($line.StartsWith($heading)) { $inside = $true; $out.Add($line); continue }
    if ($line -match '^## \[ERR-') { $inside = $false }
    if ($inside -and $line -match '^\*\*Status\*\*: open') {
        $out.Add("**Status**: closed")
        $out.Add("**Closed**: $stamp")
        if ($Resolution) { $out.Add("**Resolution**: $Resolution") }
        $inside = $false
        continue
    }
    $out.Add($line)
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($file, (($out -join "`n")), $utf8NoBom)
Write-Output "$Id closed"
