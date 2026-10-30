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
    $text = '֍N/A'; $color = 'DarkGray'
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
    Write-YafpText -Text '↦[' -ForegroundColor $foreground -BackgroundColor $background -NoNewline
    Write-YafpText -Text $Context.Codex.Text -ForegroundColor $Context.Codex.Foreground `
        -BackgroundColor $null -NoNewline
    Write-YafpText -Text ']' -ForegroundColor $foreground -BackgroundColor $background -NoNewline
}

function global:Show-YafpCodex {
    $quota = Get-YafpCodexContext
    if ($null -eq $quota) {
        Write-Output 'Codex quota disabled. Set $global:YAFP_CODEX_CHECK_INTERVAL=300.'
        return
    }
    Write-Output $quota.Text
    if ($null -eq $quota.Sample) { Write-Output 'State: pending'; return }
    $sample = $quota.Sample
    Write-Output "State: $($sample.State)"
    $age = [Math]::Max(0, [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $sample.CheckedAt)
    $primary = if ($null -eq $sample.Primary) { 'N/A' } else { "$($sample.Primary)%" }
    $secondary = if ($null -eq $sample.Secondary) { 'N/A' } else { "$($sample.Secondary)%" }
    Write-Output "Remaining: primary $primary; secondary $secondary; sample age $($age)s"
}
