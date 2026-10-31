$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$env:YAFP_METRICS_DISABLED = '1'
$env:COMPUTERNAME = 'quota-host'
$env:USERNAME = 'quota-user'
. (Join-Path $PSScriptRoot '../yafp-ps.ps1')
function Test-YafpAdministrator { return $false }
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('yafp quota ' + [guid]::NewGuid())
$null = New-Item -ItemType Directory $temporary
$originalPath = $env:PATH
try {
    $peer = Join-Path $PSScriptRoot 'fixtures/codex_app_server.ps1'
    $pwsh = (Get-Process -Id $PID).Path
    if ($IsWindows) {
        Set-Content (Join-Path $temporary 'codex.cmd') "@echo off`r`n`"$pwsh`" -NoProfile -File `"$peer`""
    }
    else {
        $launcher = Join-Path $temporary 'codex'
        Set-Content $launcher "#!/bin/sh`nexec '$pwsh' -NoProfile -File '$peer'"
        & chmod 700 $launcher
    }
    $env:PATH = $temporary + [IO.Path]::PathSeparator + $originalPath
    $env:YAFP_CODEX_TEST_FIXTURE = Join-Path $temporary 'fixture.json'
    $env:YAFP_CODEX_TEST_LOG = Join-Path $temporary 'requests.jsonl'
    $collector = Join-Path $PSScriptRoot '../scripts/windows/codex/collect.ps1'
    $resetAt = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() + 464460
    $fixture = @{
        account = @{ type = 'chatgpt'; email = 'PRIVATE' }
        result = @{ rateLimits = @{ primary = @{ usedPercent = 99 } }; rateLimitsByLimitId = @{
            codex = @{ primary = @{ usedPercent = 25; resetsAt = $resetAt + 3600 }; secondary = @{ usedPercent = 40.1; resetsAt = $resetAt } }
            other = @{ primary = @{ usedPercent = 100 } }
        } }
    }
    $fixture | ConvertTo-Json -Depth 10 | Set-Content $env:YAFP_CODEX_TEST_FIXTURE
    $sample = & $collector
    if ($sample.State -ne 'ok' -or $sample.Primary -ne 75 -or $sample.Secondary -ne 59 -or
        $sample.Remaining -ne 59 -or $sample.ResetsAt -ne $resetAt) { throw "Wrong quota sample: $($sample | ConvertTo-Json)" }
    $requests = @(Get-Content $env:YAFP_CODEX_TEST_LOG | ConvertFrom-Json)
    if (($requests.method -join ',') -ne 'initialize,initialized,account/read,account/rateLimits/read' -or
        $requests[2].params.refreshToken -ne $false) { throw 'Unexpected RPC or interactive auth request' }
    foreach ($case in @(
        @{ Account = $null; State = 'logged-out' }
        @{ Account = @{ type = 'apiKey' }; State = 'unsupported-auth' }
    )) {
        $fixture.account = $case.Account
        $fixture | ConvertTo-Json -Depth 10 | Set-Content $env:YAFP_CODEX_TEST_FIXTURE
        Remove-Item $env:YAFP_CODEX_TEST_LOG
        $sample = & $collector
        if ($sample.State -ne $case.State -or $null -ne $sample.Remaining) { throw 'Invalid auth state' }
        if ((Get-Content -Raw $env:YAFP_CODEX_TEST_LOG).Contains('account/rateLimits/read')) {
            throw 'Quota read before checking ChatGPT authentication'
        }
    }
    $fixture.account = @{ type = 'chatgpt' }
    $fixture.delay = 3000
    $fixture | ConvertTo-Json -Depth 10 | Set-Content $env:YAFP_CODEX_TEST_FIXTURE
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $sample = & $collector -TimeoutMilliseconds 800
    if ($sample.State -ne 'timeout' -or $timer.ElapsedMilliseconds -gt 2500) { throw 'Unbounded quota request' }
    $fixture.Remove('delay')
    $fixture | ConvertTo-Json -Depth 10 | Set-Content $env:YAFP_CODEX_TEST_FIXTURE
    $originalResult = $fixture.result
    foreach ($case in @(
        @{ Limits = @{ primary = @{ usedPercent = 50; resetsAt = 2000000000 }; secondary = @{ usedPercent = 25; resetsAt = 2100000000 } }; Remaining = 50; Reset = 2000000000 }
        @{ Limits = @{ primary = @{ usedPercent = 50; resetsAt = 2000000000 }; secondary = @{ usedPercent = 50; resetsAt = 2100000000 } }; Remaining = 50; Reset = 2000000000 }
        @{ Limits = @{ secondary = @{ usedPercent = 25; resetsAt = 2100000000 } }; Remaining = 75; Reset = 2100000000 }
        @{ Limits = @{ primary = @{ usedPercent = 50 }; secondary = @{ usedPercent = 50; resetsAt = 2100000000 } }; Remaining = 50 }
        @{ Limits = @{ primary = @{ usedPercent = 100 } }; Remaining = 0 }
        @{ Limits = @{ secondary = @{ usedPercent = 0 } }; Remaining = 100 }
        @{ Limits = @{ primary = @{ usedPercent = $null } }; Remaining = $null }
        @{ Limits = @{ primary = @{ usedPercent = $true } }; Remaining = $null }
        @{ Limits = @{ primary = @{ usedPercent = '15' } }; Remaining = $null }
        @{ Limits = @{ primary = @{ usedPercent = -1 } }; Remaining = $null }
        @{ Limits = @{ primary = @{ usedPercent = 101 } }; Remaining = $null }
        @{ Limits = @{ limitId = 'other'; primary = @{ usedPercent = 0 } }; Remaining = $null }
    )) {
        $fixture.result = @{ rateLimits = $case.Limits }
        $fixture | ConvertTo-Json -Depth 10 | Set-Content $env:YAFP_CODEX_TEST_FIXTURE
        $sample = & $collector
        if ($sample.Remaining -ne $case.Remaining) { throw 'Malformed, zero, or legacy quota handled incorrectly' }
        $expectedReset = if ($case.ContainsKey('Reset')) { $case.Reset } else { $null }
        if ($sample.ResetsAt -ne $expectedReset) { throw 'Reset must follow the selected quota window' }

    }
    foreach ($reset in @($null, $true, '2000000000', -1, 0, 2000000000.5, 10000000000)) {
        $fixture.result = @{ rateLimits = @{ primary = @{ usedPercent = 25; resetsAt = $reset } } }
        $fixture | ConvertTo-Json -Depth 10 | Set-Content $env:YAFP_CODEX_TEST_FIXTURE
        $sample = & $collector
        if ($sample.Remaining -ne 75 -or $null -ne $sample.ResetsAt) { throw 'Invalid reset timestamp discarded valid quota' }
    }
    $fixture.result = $originalResult
    $fixture.error = 'account/rateLimits/read'
    $fixture | ConvertTo-Json -Depth 10 | Set-Content $env:YAFP_CODEX_TEST_FIXTURE
    $sample = & $collector
    if ($sample.State -ne 'unavailable' -or $null -ne $sample.Remaining) { throw 'RPC error invented a quota' }
    $fixture.Remove('error')
    $fixture | ConvertTo-Json -Depth 10 | Set-Content $env:YAFP_CODEX_TEST_FIXTURE
    $env:PATH = Join-Path $temporary 'missing'
    $sample = & $collector
    $env:PATH = $temporary + [IO.Path]::PathSeparator + $originalPath
    if ($sample.State -ne 'missing-cli') { throw 'Missing Codex CLI not detected' }
    Write-Output 'ok - native PowerShell Codex protocol, quota bucket, authentication, and timeout'

    foreach ($line in Get-Content (Join-Path $PSScriptRoot 'codex_reset_cases.txt')) {
        $seconds, $expected = $line.Split('|')
        if ((Format-YafpCodexReset -Seconds ([long]$seconds)) -ne $expected) { throw "Wrong reset duration: $line" }
    }

    foreach ($line in Get-Content (Join-Path $PSScriptRoot 'codex_display_cases.txt')) {
        $value, $color, $cell = $line.Split('|')
        $number = if ($value -eq '-') { $null } else { [int]$value }
        foreach ($style in @('percent', 'symbols')) {
            $global:YAFP_CODEX_VALUE_STYLE = $style
            $segment = Format-YafpCodexSegment $number
            $expected = if ($style -eq 'percent' -and $null -ne $number) { "֍$value%" } else { "֍$cell" }
            if ($segment.Text -ne $expected -or $segment.Foreground -ne $color) { throw "Wrong display: $line/$style" }
        }
    }
    $global:YAFP_CODEX_VALUE_STYLE = 'bad'
    if ((Format-YafpCodexSegment 74).Text -ne '֍74%') { throw 'Invalid style fallback' }
    foreach ($interval in @('0', '-1', 'bad', '0008', '999999999999999')) {
        $global:YAFP_CODEX_CHECK_INTERVAL = $interval
        if ($null -ne (Get-YafpCodexContext) -or $null -ne $script:YafpCodexJob) { throw 'Disabled worker started' }
    }
    $global:YAFP_CODEX_CHECK_INTERVAL = 300
    $timer.Restart()
    $null = Get-YafpCodexContext
    if ($timer.ElapsedMilliseconds -gt 500) { throw 'Context blocked on quota request' }
    $job = $script:YafpCodexJob
    $null = Get-YafpCodexContext
    . (Join-Path $PSScriptRoot '../scripts/windows/codex/context.ps1')
    $null = Get-YafpCodexContext
    if ($script:YafpCodexJob.Id -ne $job.Id) { throw 'Duplicate worker after reload' }
    $null = Wait-Job $job -Timeout 15
    $context = Get-YafpCodexContext
    if ($null -ne $script:YafpCodexJob -or $context.Sample.Remaining -ne 59) { throw 'Worker not collected' }

    $global:YAFP_REPOS = 0; $global:YAFP_CLOCK = 0; $global:YAFP_RESOURCE_CHECK_INTERVAL = 0
    $global:YAFP_OSC133 = 0; $global:YAFP_ERROR = 0; $global:YAFP_TITLE = 0
    $writer = (Get-Command Write-YafpText).ScriptBlock
    $script:codexWrites = [Collections.Generic.List[object]]::new()
    foreach ($theme in @('default', 'minimal', 'light')) {
        $global:YAFP_THEME = $theme
        Import-YafpTheme
        foreach ($style in @('percent', 'symbols')) {
            $global:YAFP_CODEX_VALUE_STYLE = $style
            $global:LASTEXITCODE = 7
            $output = (@(prompt 6>&1) | ForEach-Object { "$_" }) -join ''
            $expected = if ($style -eq 'percent') { '֍59%5d9h' } else { '֍⣦5d9h' }
            if (-not $output.Contains("quota-user↤[$expected]")) { throw "User quota missing: $theme/$style" }
            if ([regex]::Matches($output, '↤\[').Count -ne 1) { throw 'Quota duplicated' }
            if ($global:LASTEXITCODE -ne 7) { throw 'Previous exit code changed' }
        }
        function Write-YafpText {
            param([string]$Text, [string]$ForegroundColor, [object]$BackgroundColor, [switch]$NoNewline)
            $script:codexWrites.Add([pscustomobject]@{
                Text = $Text; Color = $ForegroundColor; Background = $BackgroundColor; NoNewline = $NoNewline
            })
        }
        try {
            $script:codexWrites.Clear()
            Write-YafpCodex -Context ([pscustomobject]@{ Codex = (Get-YafpCodexContext) })
            $foreground = if ($theme -eq 'default') { $script:grayColorForeground } else { 'White' }
            $background = if ($theme -eq 'default') { $script:grayColorBackground } else { $null }
            foreach ($index in @(0, 2)) {
                $write = $script:codexWrites[$index]
                if ($write.Color -ne $foreground -or $write.Background -ne $background -or -not $write.NoNewline) {
                    throw 'Frame must match Git colors'
                }
            }
            if ($script:codexWrites[1].Color -ne 'Green' -or $null -ne $script:codexWrites[1].Background) {
                throw 'Quota foreground color incorrect'
            }
        }
        finally { Set-Item Function:Write-YafpText -Value $writer }
    }
    $savedReset = $script:YafpCodexSample.ResetsAt
    $global:YAFP_CODEX_VALUE_STYLE = 'percent'
    $script:YafpCodexSample.ResetsAt = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - 1
    if ((Get-YafpCodexContext).Text -ne '֍59%0s') { throw 'Expired reset did not stop at zero' }
    $script:YafpCodexSample.ResetsAt = $null
    if ((Get-YafpCodexContext).Text -ne '֍59%') { throw 'Missing reset must omit countdown' }
    $script:YafpCodexSample.ResetsAt = $savedReset
    $global:YAFP_CODEX_CHECK_INTERVAL = 0
    if ($null -ne (Get-YafpCodexContext)) { throw 'Disabled quota retained context' }
    # Exit cleanup must cancel a private CLI even if its quota request is blocked.
    $fixture.delay = 20000
    $fixture | ConvertTo-Json -Depth 10 | Set-Content $env:YAFP_CODEX_TEST_FIXTURE
    $global:YAFP_CODEX_CHECK_INTERVAL = 300
    $script:YafpCodexAttempt = $null
    $null = Get-YafpCodexContext
    $deadline = [Environment]::TickCount64 + 5000
    while ($null -eq $script:YafpCodexControl.Process -and [Environment]::TickCount64 -lt $deadline) {
        Start-Sleep -Milliseconds 20
    }
    $child = $script:YafpCodexControl.Process
    if ($null -eq $child) { throw 'Cleanup fixture did not start' }
    $childId = $child.Id
    Stop-YafpCodexWorker
    $null = Wait-Job $script:YafpCodexJob -Timeout 3
    if ($script:YafpCodexJob.State -ne 'Completed' -or (Get-Process -Id $childId -ErrorAction Ignore)) {
        throw 'Exit cleanup left a Codex app-server running'
    }
    $global:YAFP_CODEX_CHECK_INTERVAL = 0
    $null = Get-YafpCodexContext
    Write-Output 'ok - PowerShell quota lifecycle, all themes, Braille, inclusive colors, and exit status'
}
finally {
    $env:PATH = $originalPath
    if ($null -ne $script:YafpCodexJob) { Remove-Job $script:YafpCodexJob -Force -ErrorAction Ignore }
    Remove-Item -Recurse -Force $temporary
    Remove-Item Env:YAFP_CODEX_TEST_FIXTURE, Env:YAFP_CODEX_TEST_LOG -ErrorAction Ignore
}
