foreach ($name in @('YafpUpdateSample', 'YafpUpdateRoot', 'YafpUpdateSessionId')) {
    if (-not (Get-Variable $name -Scope Script -ErrorAction Ignore)) {
        Set-Variable -Name $name -Scope Script -Value $null
    }
}
function global:Start-YafpUpdateCheck {
    param([bool]$Interactive)
    if (-not $Interactive -or $env:YAFP_UPDATE_CHECK -eq '0' -or $env:YAFP_NO_INSTALL_HOOKS -eq '1') { return }
    if ($null -ne $script:YafpUpdateSample) { return }
    $script:YafpUpdateRoot = $script:YafpRoot
    $script:YafpUpdateSample = & (Join-Path $script:YafpRoot 'scripts/windows/update/collect.ps1') -Root $script:YafpRoot
}
function global:Complete-YafpUpdateCheck {
    param()
    if ($null -eq $script:YafpUpdateSample) { return }
    $root = $script:YafpUpdateRoot
    $sample = $script:YafpUpdateSample
    $script:YafpUpdateSample = $null
    if ($null -eq $sample -or $sample.State -eq 'error') {
        Write-YafpUpdateMessage -Severity error -Text '☒🌐 REMOTE CHECK FAILED'
        return
    }
    $messages = @{
        'missing-git' = '⚠ GIT NOT AVAILABLE: YAFP startup check skipped'
        'not-git' = '⚠ NOT A GIT REPOSITORY: YAFP installation'
        'unborn' = '⚠ NO COMMITS: YAFP installation'
        'detached' = '⚠ DETACHED HEAD: YAFP startup update unavailable'
        'no-upstream' = '⚠ NO UPSTREAM: YAFP startup update unavailable'
        'no-remote' = '⚠ NO REMOTE: YAFP startup update unavailable'
    }
    if ($messages.ContainsKey($sample.State)) { Write-YafpUpdateMessage -Severity warning -Text $messages[$sample.State]; return }
    if ($sample.State -ne 'ok') { return }
    $head = & git -C $root rev-parse --verify HEAD 2>$null
    $branch = & git -C $root symbolic-ref --quiet HEAD 2>$null
    $upstream = & git -C $root rev-parse --symbolic-full-name '@{upstream}' 2>$null
    if ("$head" -ne $sample.Head -or "$branch" -ne $sample.Branch -or "$upstream" -ne $sample.Upstream) { return }
    if ($sample.Dirty) { Write-YafpUpdateMessage -Severity warning -Text '⚠ UNCOMMITTED CHANGES: YAFP has local modifications' }
    $target = $sample.Upstream -replace '^refs/remotes/', ''
    if ($sample.Ahead -gt 0 -and $sample.Behind -gt 0) {
        Write-YafpUpdateMessage -Severity error -Text "☒ DIVERGED REPOSITORY: $($sample.Ahead) local commit(s), $($sample.Behind) remote commit(s) from $target"
        return
    }
    if ($sample.Ahead -gt 0) {
        $unit = if ($sample.Ahead -eq 1) { 'commit' } else { 'commits' }
        $verb = if ($sample.Ahead -eq 1) { 'has' } else { 'have' }
        Write-YafpUpdateMessage -Severity warning -Text "⚠ REMOTE NOT UPDATED: $($sample.Ahead) local $unit $verb not been pushed to $target"
        return
    }
    if ($sample.Behind -eq 0) { Write-YafpUpdateMessage -Severity success -Text '✓ REPOSITORY UP TO DATE: YAFP'; return }
    Write-YafpUpdateMessage -Severity error -Text "☒ OUTDATED REPOSITORY: YAFP is $($sample.Behind) commit(s) behind its upstream."
    $answer = Read-Host 'Update YAFP now? [y/N]'
    if ($answer -cnotin @('y', 'Y')) { return }
    $result = & (Join-Path $root 'scripts/windows/update/collect.ps1') -Root $root -Pull $true
    if ($result.State -eq 'updated') {
        try { Invoke-YafpReload }
        catch { Write-YafpUpdateMessage -Severity error -Text '☒ RELOAD FAILED: restart YAFP after fixing its configuration.' }
    }
    else { Write-YafpUpdateMessage -Severity error -Text '☒ UPDATE FAILED: YAFP was not reloaded.' }
}

function global:Invoke-YafpStartupUpdate {
    param([bool]$Interactive)
    if (-not $Interactive -or $env:YAFP_UPDATE_CHECK -eq '0' -or $env:YAFP_NO_INSTALL_HOOKS -eq '1') { return }
    if ($script:YafpUpdateSessionId -eq $PID) { return }
    $script:YafpUpdateSessionId = $PID
    Write-YafpUpdateMessage -Severity info -Text "YAFP startup check: $script:YafpRoot"
    Start-YafpUpdateCheck -Interactive $true
    Complete-YafpUpdateCheck
}

function global:Write-YafpUpdateMessage {
    param(
        [ValidateSet('info', 'warning', 'error', 'success')][string]$Severity,
        [string]$Text
    )
    $foreground = 'White'
    $background = $null
    if ($Severity -in @('warning', 'error')) {
        if (Get-Command Get-YafpSeverityStyle -ErrorAction Ignore) {
            $style = Get-YafpSeverityStyle -Severity $Severity
            $foreground = $style.Foreground
            $background = $style.Background
        }
        elseif ($Severity -eq 'warning') { $foreground = 'Black'; $background = 'Yellow' }
        else {
            $dark = Get-Variable YAFP_DARKC -Scope Global -ValueOnly -ErrorAction Ignore
            $background = if ($dark -eq 0) { 'Red' } else { 'DarkRed' }
        }
    }
    elseif ($Severity -eq 'success') { $background = 'DarkGreen' }
    if (Get-Command Write-YafpText -ErrorAction Ignore) {
        Write-YafpText -Text $Text -ForegroundColor $foreground -BackgroundColor $background
    }
    elseif ($null -ne $background) {
        Write-Host $Text -ForegroundColor $foreground -BackgroundColor $background
    }
    else { Write-Host $Text -ForegroundColor $foreground }
}
