# Preserve the single worker and its cache when the prompt is reloaded.
foreach ($option in @{
    YAFP_CODEX_CHECK_INTERVAL = 0
    YAFP_CODEX_VALUE_STYLE = 'percent'
}.GetEnumerator()) {
    if (-not (Get-Variable $option.Key -Scope Global -ErrorAction Ignore)) {
        Set-Variable -Name $option.Key -Value $option.Value -Scope Global
    }
}
foreach ($name in @('YafpCodexJob', 'YafpCodexSample', 'YafpCodexAttempt')) {
    if (-not (Get-Variable $name -Scope Script -ErrorAction Ignore)) {
        Set-Variable -Name $name -Scope Script -Value $null
    }
}
if (-not (Get-Variable YafpCodexControl -Scope Script -ErrorAction Ignore)) {
    $script:YafpCodexControl = [hashtable]::Synchronized(@{ Process = $null; Cancelled = $false })
}

function global:Stop-YafpCodexWorker {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingEmptyCatchBlock', '',
        Justification = 'Exit cleanup tolerates an app-server that already terminated.'
    )]
    param()
    $script:YafpCodexControl.Cancelled = $true
    $process = $script:YafpCodexControl.Process
    if ($null -ne $process) {
        try { if (-not $process.HasExited) { $process.Kill($true) } }
        catch { }
    }
}

function global:Format-YafpCodexReset {
    param([long]$Seconds)
    $remaining = [Math]::Max(0, $Seconds)
    if ($remaining -ge 86400) {
        return "$([Math]::Floor($remaining / 86400))d$([Math]::Floor($remaining % 86400 / 3600))h"
    }
    if ($remaining -ge 3600) {
        return "$([Math]::Floor($remaining / 3600))h$([Math]::Floor($remaining % 3600 / 60))m"
    }
    if ($remaining -ge 60) {
        return "$([Math]::Floor($remaining / 60))m$($remaining % 60)s"
    }
    return "$($remaining)s"
}

function global:Format-YafpCodexSegment {
    param([AllowNull()][Nullable[int]]$Value)
    $text = '֍dh'; $color = 'Red'
    if ($null -ne $Value -and $Value -ge 0 -and $Value -le 100) {
        $color = if ($Value -ge 50) { 'Green' } elseif ($Value -ge 25) { 'Yellow' } else { 'Red' }
        $text = "֍$Value%"
        if ($global:YAFP_CODEX_VALUE_STYLE -eq 'symbols') {
            $cells = @('⡀', '⣀', '⣄', '⣤', '⣦', '⣶', '⣷', '⣿')
            $text = '֍' + $cells[[Math]::Min(7, [int][Math]::Floor($Value * 8 / 100))]
        }
    }
    [pscustomobject]@{ Text = $text; Foreground = $color }
}

function global:Get-YafpCodexContext {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingEmptyCatchBlock', '',
        Justification = 'Optional quota checks fail silently and retry at the next interval.'
    )]
    param()
    if ($null -ne $script:YafpCodexJob -and
        $script:YafpCodexJob.State -in @('Completed', 'Failed', 'Stopped')) {
        $script:YafpCodexSample = $null
        try {
            $result = @(Receive-Job -Job $script:YafpCodexJob -ErrorAction Stop)
            if ($result.Count -gt 0) { $script:YafpCodexSample = $result[-1] }
        }
        catch { }
        Remove-Job -Job $script:YafpCodexJob -Force -ErrorAction Ignore
        $script:YafpCodexJob = $null
    }
    $interval = 0
    if ("$global:YAFP_CODEX_CHECK_INTERVAL" -notmatch '^[1-9][0-9]{0,4}$' -or
        -not [int]::TryParse("$global:YAFP_CODEX_CHECK_INTERVAL", [ref]$interval) -or
        $interval -lt 1 -or $interval -gt 86400) { return $null }
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if ($null -eq $script:YafpCodexJob -and
        ($null -eq $script:YafpCodexAttempt -or $now - $script:YafpCodexAttempt -ge $interval)) {
        $script:YafpCodexAttempt = $now
        try {
            $script:YafpCodexControl.Cancelled = $false
            $script:YafpCodexJob = Start-ThreadJob -FilePath `
                (Join-Path $script:YafpRoot 'scripts/windows/codex/collect.ps1') `
                -ArgumentList 10000, $script:YafpCodexControl -ErrorAction Stop
        }
        catch { }
    }
    $value = $null
    if ($null -ne $script:YafpCodexSample -and $script:YafpCodexSample.State -eq 'ok') {
        $value = $script:YafpCodexSample.Remaining
    }
    $segment = Format-YafpCodexSegment -Value $value
    if ($null -eq $script:YafpCodexSample -and $null -ne $script:YafpCodexJob) {
        $segment.Text = '֍⟳d⟳h'
        $segment.Foreground = 'DarkGray'
    }
    if ($null -ne $value -and $script:YafpCodexSample.PSObject.Properties['ResetsAt'] -and
        $null -ne $script:YafpCodexSample.ResetsAt) {
        $segment.Text += (Format-YafpCodexReset -Seconds ($script:YafpCodexSample.ResetsAt - $now))
    }
    [pscustomobject]@{
        Text = $segment.Text; Foreground = $segment.Foreground; Sample = $script:YafpCodexSample
    }
}

function global:Write-YafpCodex {
    param([Parameter(Mandatory)][object]$Context)
    if (-not $Context.PSObject.Properties['Codex'] -or $null -eq $Context.Codex) { return }
    $foreground = 'White'; $background = $null
    if ($script:YafpThemeName -eq 'default') {
        $foreground = $script:grayColorForeground
        $background = $script:grayColorBackground
    }
    Write-YafpText -Text '↤[' -ForegroundColor $foreground -BackgroundColor $background -NoNewline
    Write-YafpText -Text $Context.Codex.Text -ForegroundColor $Context.Codex.Foreground `
        -BackgroundColor $null -NoNewline
    Write-YafpText -Text ']' -ForegroundColor $foreground -BackgroundColor $background -NoNewline
}

function global:Show-YafpCodex {
    $quota = Get-YafpCodexContext
    $state = 'disabled'; $resetText = ''; $remainingText = ''
    $resetColor = 90; $remainingColor = 90
    if ($null -ne $quota) {
        $state = if ($null -ne $quota.Sample) { $quota.Sample.State }
        elseif ($null -ne $script:YafpCodexJob) { 'pending' } else { 'unavailable' }
        if ($state -eq 'ok' -and $null -ne $quota.Sample.Remaining -and
            $quota.Sample.Remaining -ge 0 -and $quota.Sample.Remaining -le 100) {
            $remainingText = "$($quota.Sample.Remaining)%"
            $remainingColor = switch ($quota.Foreground) { Green { 92 }; Yellow { 93 }; Red { 91 }; default { 90 } }
            if ($quota.Sample.PSObject.Properties['ResetsAt'] -and $null -ne $quota.Sample.ResetsAt) {
                $seconds = [Math]::Max(0, $quota.Sample.ResetsAt - [DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
                $resetText = "$([Math]::Floor($seconds / 86400))d$([Math]::Floor($seconds % 86400 / 3600))h"
                $resetColor = 93
            }
        }
    }
    $stateIcon = ''; $stateColor = 91
    switch ($state) {
        ok { $stateIcon = ''; $stateColor = 92 }
        pending { $stateIcon = ''; $stateColor = 93 }
        disabled { $stateIcon = ''; $stateColor = 90 }
        'logged-out' { $stateIcon = ''; $stateColor = 91 }
        'unsupported-auth' { $stateIcon = ''; $stateColor = 93 }
        { $_ -in @('missing-cli', 'missing-python') } { $stateIcon = ''; $stateColor = 93 }
        timeout { $stateIcon = ''; $stateColor = 91 }
    }
    $escape = [char]27
    $report = "        Reset: $escape[$($resetColor)m$resetText$escape[0m`n" +
        "        State: $escape[$($stateColor)m$stateIcon $state$escape[0m`n" +
        "    Remaining: $escape[$($remainingColor)m$remainingText$escape[0m"
    . (Join-Path $script:YafpRoot 'scripts/windows/preview/lib/frame.ps1')
    Write-YafpPreviewFrame -Text $report
    if ($state -eq 'disabled') {
        Write-Output 'Codex quota disabled. Set $global:YAFP_CODEX_CHECK_INTERVAL=300.'
    }
}
