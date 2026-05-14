#Requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ROOT = Split-Path -Parent $PSScriptRoot
$APPEND = Join-Path $ROOT 'scripts/error-journal/append-error-journal.ps1'
$READ = Join-Path $ROOT 'scripts/error-journal/read-error-journal.ps1'
$PSEXE = (Get-Process -Id $PID).Path
if ([string]::IsNullOrEmpty($PSEXE)) {
    $PSEXE = 'powershell'
}

$script:failures = 0
$script:tempDirs = New-Object System.Collections.ArrayList

function Fail([string]$msg) {
    Write-Host "FAIL: $msg" -ForegroundColor Red
    $script:failures++
}

function New-Fixture {
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("ej-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $dir '.harness') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $dir '.harness/error-journal.md') -Value "# Error Journal`r`n" -Encoding UTF8
    [void]$script:tempDirs.Add($dir)
    return $dir
}

function Invoke-Script([string]$ScriptPath, [string[]]$ScriptArgs) {
    $stderrFile = [System.IO.Path]::GetTempFileName()
    try {
        $argList = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $ScriptPath) + $ScriptArgs
        $stdout = & $PSEXE @argList 2>$stderrFile
        $exitCode = $LASTEXITCODE
        if ($null -eq $stdout) {
            $stdoutText = ''
        } elseif ($stdout -is [array]) {
            $stdoutText = ($stdout -join "`n")
        } else {
            $stdoutText = [string]$stdout
        }
        return [pscustomobject]@{
            ExitCode = $exitCode
            Stdout   = $stdoutText
            Stderr   = (Get-Content -LiteralPath $stderrFile -Raw -ErrorAction SilentlyContinue)
        }
    } finally {
        Remove-Item -LiteralPath $stderrFile -ErrorAction SilentlyContinue
    }
}

function Invoke-Append([string[]]$ArgList) {
    return Invoke-Script $APPEND $ArgList
}

function Invoke-Read([string[]]$ArgList) {
    return Invoke-Script $READ $ArgList
}

function Test-AppendRejectsMissingArgs {
    $result = Invoke-Append @()
    if ($result.ExitCode -eq 0) {
        Fail ("append should exit non-zero when args missing; got exitCode=0, stderr={0}" -f $result.Stderr)
        return
    }
    Write-Host 'ok: append rejects missing args'
}

function Test-AppendRejectsMissingJournal {
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("ej-noinit-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    [void]$script:tempDirs.Add($dir)
    $result = Invoke-Append @('-RepoRoot', $dir, '-EventType', 'user-correction', '-Area', 'core', '-Summary', 'something')
    if ($result.ExitCode -eq 0) {
        Fail 'append should exit non-zero when journal file missing'
        return
    }
    Write-Host 'ok: append rejects missing journal'
}

function Test-AppendWritesEntryAndPrintsId {
    $dir = New-Fixture
    $result = Invoke-Append @('-RepoRoot', $dir, '-EventType', 'user-correction', '-Area', 'core', '-Summary', 'first entry')
    if ($result.ExitCode -ne 0) {
        Fail ("append should exit 0; got {0}, stderr={1}" -f $result.ExitCode, $result.Stderr)
        return
    }
    $id = ($result.Stdout -replace '\r?\n', '').Trim()
    if ($id -notmatch '^ERR-\d{8}-001$') {
        Fail "expected ID like ERR-YYYYMMDD-001, got: $id"
        return
    }
    $content = Get-Content -LiteralPath (Join-Path $dir '.harness/error-journal.md') -Raw
    if ($content -notmatch [Regex]::Escape("## [$id] user-correction")) {
        Fail "journal should contain heading for $id"
        return
    }
    if ($content -notmatch 'first entry') {
        Fail 'journal should contain summary text'
        return
    }
    Write-Host 'ok: append writes entry and prints id'
}

function Test-AppendIncrementsSequence {
    $dir = New-Fixture
    $r1 = Invoke-Append @('-RepoRoot', $dir, '-EventType', 'user-correction', '-Area', 'core', '-Summary', 'one')
    $r2 = Invoke-Append @('-RepoRoot', $dir, '-EventType', 'test-failure', '-Area', 'core', '-Summary', 'two')
    $r3 = Invoke-Append @('-RepoRoot', $dir, '-EventType', 'review-finding', '-Area', 'core', '-Summary', 'three')
    foreach ($r in @($r1, $r2, $r3)) {
        if ($r.ExitCode -ne 0) {
            Fail "append should succeed; stderr=$($r.Stderr)"
            return
        }
    }
    $id1 = ($r1.Stdout -replace '\r?\n', '').Trim()
    $id2 = ($r2.Stdout -replace '\r?\n', '').Trim()
    $id3 = ($r3.Stdout -replace '\r?\n', '').Trim()
    if (-not $id1.EndsWith('-001')) { Fail "first id should end with -001, got $id1"; return }
    if (-not $id2.EndsWith('-002')) { Fail "second id should end with -002, got $id2"; return }
    if (-not $id3.EndsWith('-003')) { Fail "third id should end with -003, got $id3"; return }
    Write-Host 'ok: append increments sequence'
}

function Test-AppendJoinsMultiWordSummary {
    $dir = New-Fixture
    $summary = '用户 纠正了 入口文件 边界'
    $result = Invoke-Append @('-RepoRoot', $dir, '-EventType', 'user-correction', '-Area', 'core', '-Summary', $summary)
    if ($result.ExitCode -ne 0) {
        Fail "append should succeed; stderr=$($result.Stderr)"
        return
    }
    $content = Get-Content -LiteralPath (Join-Path $dir '.harness/error-journal.md') -Raw
    if ($content -notmatch [Regex]::Escape($summary)) {
        Fail "journal should contain joined multi-word summary"
        return
    }
    Write-Host 'ok: append joins multi-word summary'
}

function Test-ReadRejectsMissingJournal {
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("ej-noread-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    [void]$script:tempDirs.Add($dir)
    $result = Invoke-Read @('-RepoRoot', $dir)
    if ($result.ExitCode -eq 0) {
        Fail 'read should exit non-zero when journal file missing'
        return
    }
    Write-Host 'ok: read rejects missing journal'
}

function Test-ReadOutputsJournalContent {
    $dir = New-Fixture
    $append = Invoke-Append @('-RepoRoot', $dir, '-EventType', 'user-correction', '-Area', 'core', '-Summary', 'for reading')
    if ($append.ExitCode -ne 0) {
        Fail "append should succeed; stderr=$($append.Stderr)"
        return
    }
    $result = Invoke-Read @('-RepoRoot', $dir)
    if ($result.ExitCode -ne 0) {
        Fail "read should succeed; stderr=$($result.Stderr)"
        return
    }
    if ($result.Stdout -notmatch 'for reading') {
        Fail 'read output should include appended summary'
        return
    }
    if ($result.Stdout -notmatch '# Error Journal') {
        Fail 'read output should include journal header'
        return
    }
    Write-Host 'ok: read outputs journal content'
}

try {
    Test-AppendRejectsMissingArgs
    Test-AppendRejectsMissingJournal
    Test-AppendWritesEntryAndPrintsId
    Test-AppendIncrementsSequence
    Test-AppendJoinsMultiWordSummary
    Test-ReadRejectsMissingJournal
    Test-ReadOutputsJournalContent
} finally {
    foreach ($d in $script:tempDirs) {
        if (Test-Path -LiteralPath $d) {
            Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

if ($script:failures -gt 0) {
    Write-Host ("error-journal PS test FAILED ({0} failures)" -f $script:failures) -ForegroundColor Red
    exit 1
}

Write-Host 'error-journal PS test passed' -ForegroundColor Green
exit 0
