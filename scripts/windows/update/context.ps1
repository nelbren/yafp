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
        Write-YafpUpdateReport -Severity error -Text '🌐 REMOTE CHECK FAILED' -InstallRoot $root
        return
    }
    $messages = @{
        'missing-git' = ' GIT NOT AVAILABLE: YAFP startup check skipped'
        'not-git' = ' NOT A GIT REPOSITORY: YAFP installation'
        'unborn' = ' NO COMMITS: YAFP installation'
        'detached' = ' DETACHED HEAD: YAFP startup update unavailable'
        'no-upstream' = ' NO UPSTREAM: YAFP startup update unavailable'
        'no-remote' = ' NO REMOTE: YAFP startup update unavailable'
    }
    if ($messages.ContainsKey($sample.State)) {
        Write-YafpUpdateReport -Severity warning -Text $messages[$sample.State] -InstallRoot $root
        return
    }
    if ($sample.State -ne 'ok') { return }
    $head = & git -C $root rev-parse --verify HEAD 2>$null
    $branch = & git -C $root symbolic-ref --quiet HEAD 2>$null
    $upstream = & git -C $root rev-parse --symbolic-full-name '@{upstream}' 2>$null
    if ("$head" -ne $sample.Head -or "$branch" -ne $sample.Branch -or "$upstream" -ne $sample.Upstream) { return }
    if ($sample.Ahead -eq 0 -and $sample.Behind -eq 0) { return }
    $target = $sample.Upstream -replace '^refs/remotes/', ''
    if ($sample.Ahead -gt 0 -and $sample.Behind -gt 0) {
        Write-YafpUpdateReport -Severity error -InstallRoot $root `
            -Text " DIVERGED REPOSITORY: $($sample.Ahead) local commit(s), $($sample.Behind) remote commit(s) from $target"
        return
    }
    if ($sample.Ahead -gt 0) {
        $unit = if ($sample.Ahead -eq 1) { 'commit' } else { 'commits' }
        $verb = if ($sample.Ahead -eq 1) { 'has' } else { 'have' }
        Write-YafpUpdateReport -Severity warning -InstallRoot $root `
            -Text " REMOTE NOT UPDATED: $($sample.Ahead) local $unit $verb not been pushed to $target"
        return
    }
    Write-YafpUpdateReport -Severity error -InstallRoot $root `
        -Text " OUTDATED REPOSITORY: YAFP is $($sample.Behind) commit(s) behind its upstream."
    $answer = Read-Host 'Update YAFP now? [y/N]'
    if ($answer -cnotin @('y', 'Y')) { return }
    $result = & (Join-Path $root 'scripts/windows/update/collect.ps1') -Root $root -Pull $true
    if ($result.State -eq 'updated') {
        try { Invoke-YafpReload -Quiet }
        catch { Write-YafpUpdateReport -Severity error -Text ' RELOAD FAILED: restart YAFP after fixing its configuration.' }
    }
    else { Write-YafpUpdateReport -Severity error -Text ' UPDATE FAILED: YAFP was not reloaded.' }
}

function global:Invoke-YafpStartupUpdate {
    param([bool]$Interactive)
    if (-not $Interactive -or $env:YAFP_UPDATE_CHECK -eq '0' -or $env:YAFP_NO_INSTALL_HOOKS -eq '1') { return }
    if ($script:YafpUpdateSessionId -eq $PID) { return }
    $script:YafpUpdateSessionId = $PID
    Start-YafpUpdateCheck -Interactive $true
    Complete-YafpUpdateCheck
}

function global:Write-YafpUpdateReport {
    param([string]$Severity, [string]$Text, [string]$InstallRoot)

    . (Join-Path $script:YafpRoot 'scripts/windows/preview/lib/frame.ps1')
    $records = @(
        if ($InstallRoot) {
            Write-YafpUpdateMessage -Severity info -Text "YAFP startup check: $InstallRoot" 6>&1
        }
        Write-YafpUpdateMessage -Severity $Severity -Text $Text 6>&1
    )
    Write-YafpPreviewFrame -Text (ConvertTo-YafpPreviewText -Records $records) -FitContent -Title ' YAFP startup update'
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
