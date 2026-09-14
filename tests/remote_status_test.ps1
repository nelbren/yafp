$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$rootDir = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path ([IO.Path]::GetTempPath()) `
    "yafp-remote-test-$([guid]::NewGuid().ToString('N'))"

function Assert-Equal {
    param($Expected, $Actual, [string]$Label)

    if ($Expected -ne $Actual) {
        throw "$Label`: expected [$Expected], got [$Actual]"
    }
}

try {
    $null = New-Item -ItemType Directory -Path $testRoot
    $origin = Join-Path $testRoot 'origin.git'
    $writer = Join-Path $testRoot 'writer'
    $local = Join-Path $testRoot 'local'

    & git init --quiet --bare --initial-branch=main $origin
    & git -C $origin config maintenance.auto false
    & git init --quiet --initial-branch=main $writer
    & git -C $writer config user.name 'YAFP Test'
    & git -C $writer config user.email 'yafp@example.invalid'
    & git -C $writer config maintenance.auto false
    & git -C $writer remote add origin $origin
    Set-Content -LiteralPath (Join-Path $writer 'file.txt') -Value 'initial'
    & git -C $writer add file.txt
    & git -C $writer commit --quiet -m initial
    & git -C $writer push --quiet --set-upstream origin main

    & git clone --quiet $origin $local
    & git -C $local config maintenance.auto false
    Add-Content -LiteralPath (Join-Path $writer 'file.txt') `
        -Value 'remote change'
    & git -C $writer commit --quiet -am remote-change
    & git -C $writer push --quiet origin main

    . (Join-Path $rootDir 'yafp-ps.ps1')

    $localRef = 'refs/heads/main'
    $upstream = 'origin/main'
    $cacheFile = Join-Path $local '.git/yafp-remote-status'
    $global:YAFP_REMOTE_CHECK_INTERVAL = 300
    $global:YAFP_REMOTE_COUNTDOWN_STYLE = 'numeric'
    $global:YAFP_STATUS_PROGRESS_STYLE = 'blocks'

    $gitCounts = Get-YafpGitStatusCounts -Lines @(
        'M  staged modification'
        'A  staged addition'
        'R  old -> new'
        ' D deleted'
        ' M modified'
        'MM both'
        '?? untracked'
        'UU conflict'
    )
    Assert-Equal 4 $gitCounts.Staged 'staged Git count'
    Assert-Equal 2 $gitCounts.Change 'unstaged Git change count'
    Assert-Equal 1 $gitCounts.Delete 'unstaged Git deletion count'
    Assert-Equal 1 $gitCounts.New 'untracked Git count'
    Assert-Equal Yellow (Get-YafpStagedWarningColor) `
        'staged Git warning color'

    $stagedContext = [pscustomobject]@{
        Git = [pscustomobject]@{ StagedCount = 4 }
    }
    $stagedWarning = Write-YafpStagedWarning `
        -Context $stagedContext 6>&1 | Out-String
    if ($stagedWarning -notmatch
        '⚠️ COMMIT PENDING: 4 staged files are ready to commit ⚠️') {
        throw 'staged Git warning was not rendered'
    }
    $stagedContext.Git.StagedCount = 1
    $stagedWarning = Write-YafpStagedWarning `
        -Context $stagedContext 6>&1 | Out-String
    if ($stagedWarning -notmatch
        '⚠️ COMMIT PENDING: 1 staged file is ready to commit ⚠️') {
        throw 'singular staged Git warning was not rendered'
    }

    $statusReport = @(Format-YafpRemoteStatusReport -State current `
        -Remaining 175 -Interval 300 -Now 0)
    Assert-Equal '🌐       Remote: ✓ Up to date' $statusReport[0] `
        'detailed remote state'
    Assert-Equal (
        '🟡        Timer: ████░░░░░░ 42% · 125/300s elapsed · 175s remaining'
    ) $statusReport[1] 'detailed timer progress'
    if ($statusReport[2] -notmatch '^🕘 Current time: \d{2}:\d{2}:\d{2}$') {
        throw 'detailed status omitted the current time'
    }
    Assert-Equal Green (Get-YafpRemoteStateColor -State current) `
        'current state intense green color'
    Assert-Equal Red (Get-YafpRemoteStateColor -State error) `
        'offline state intense red color'
    Assert-Equal White (Get-YafpCurrentTimeColor) `
        'current time intense white color'
    Assert-Equal Yellow (Get-YafpNextCheckColor) `
        'next check intense yellow color'
    $timerStyle = Get-YafpRemoteTimerStyle -Remaining 198 -Interval 300
    Assert-Equal '🟢|Green' "$($timerStyle.Emoji)|$($timerStyle.Color)" `
        'timer green threshold'
    $timerStyle = Get-YafpRemoteTimerStyle -Remaining 99 -Interval 300
    Assert-Equal '🟡|Yellow' "$($timerStyle.Emoji)|$($timerStyle.Color)" `
        'timer yellow threshold'
    $timerStyle = Get-YafpRemoteTimerStyle -Remaining 98 -Interval 300
    Assert-Equal '🔴|Red' "$($timerStyle.Emoji)|$($timerStyle.Color)" `
        'timer red threshold'
    $global:YAFP_STATUS_PROGRESS_STYLE = 'symbols'
    $statusReport = @(Format-YafpRemoteStatusReport -State current `
        -Remaining 175 -Interval 300 -Now 0)
    Assert-Equal (
        '🟡        Timer: ⣿⣿⣿⣿⣀      42% · 125/300s elapsed · 175s remaining'
    ) $statusReport[1] 'Braille status progress'
    $global:YAFP_STATUS_PROGRESS_STYLE = 'blocks'
    Assert-Equal Show-YafpStatus (Get-Alias yafp-status).Definition `
        'yafp-status command'
    Assert-Equal Invoke-YafpRefresh (Get-Alias yafp-refresh).Definition `
        'yafp-refresh command'
    Assert-Equal Show-YafpDemo (Get-Alias yafp-demo).Definition `
        'yafp-demo command'
    if ((Get-Command Show-YafpDemo).Definition -notmatch
        [regex]::Escape('Control+C to break this ♾️  loop 🔁 ($($sleepSecs)s)')) {
        throw 'yafp-demo interruption hint is unavailable'
    }
    if ((Get-Command Show-YafpDemo).Definition -notmatch
        'Start-Sleep -Seconds \$sleepSecs') {
        throw 'yafp-demo does not reuse its configured sleep interval'
    }

    Assert-Equal '(300)' (Get-YafpRemoteCountdownIndicator -Remaining 300) `
        'numeric countdown indicator'
    $global:YAFP_REMOTE_COUNTDOWN_STYLE = 'symbols'
    $script:YafpRemoteCountdownColorIndex = 0
    Assert-Equal '⣿' (Get-YafpRemoteCountdownIndicator -Remaining 300) `
        'full symbolic countdown indicator'
    Assert-Equal White $script:YafpRemoteCountdownColor `
        'initial symbolic countdown color'
    Assert-Equal '⣿' (Get-YafpRemoteCountdownIndicator -Remaining 280) `
        'stable symbolic countdown indicator during color change'
    Assert-Equal Gray $script:YafpRemoteCountdownColor `
        'middle symbolic countdown color'
    Assert-Equal '⣿' (Get-YafpRemoteCountdownIndicator -Remaining 270) `
        'stable symbolic countdown indicator before next level'
    Assert-Equal DarkGray $script:YafpRemoteCountdownColor `
        'last symbolic countdown color'
    Assert-Equal '⣷' (Get-YafpRemoteCountdownIndicator -Remaining 250) `
        'decreasing symbolic countdown indicator'
    Assert-Equal '⡀' (Get-YafpRemoteCountdownIndicator -Remaining 1) `
        'last symbolic countdown indicator'
    Assert-Equal '' (Get-YafpRemoteCountdownIndicator -Remaining 0) `
        'expired symbolic countdown indicator'
    $global:YAFP_REMOTE_COUNTDOWN_STYLE = 'invalid'
    Assert-Equal '(250)' (Get-YafpRemoteCountdownIndicator -Remaining 250) `
        'invalid countdown style fallback'
    $global:YAFP_REMOTE_COUNTDOWN_STYLE = 'numeric'

    $initialRemote = Get-YafpRemoteContext -RepoRoot $local -Branch main
    Assert-Equal checking $initialRemote.State 'initial asynchronous state'

    $job = $script:YafpRemoteJobs[$cacheFile]
    $null = Wait-Job -Job $job -Timeout 30
    Assert-Equal Completed $job.State 'background job state'

    $remote = Get-YafpRemoteContext -RepoRoot $local -Branch main
    Assert-Equal behind $remote.State 'remote state'
    Assert-Equal 1 $remote.Behind 'behind count'
    Assert-Equal origin/main $remote.Upstream 'upstream name'
    if ($remote.RefreshIn -lt 0 -or $remote.RefreshIn -gt 300) {
        throw 'refresh countdown is outside the configured interval'
    }

    $gitContext = [pscustomobject]@{ RemoteStatus = $remote }
    $indicator = Write-YafpGitRemoteStatus -Git $gitContext 6>&1 |
        Out-String
    if ($indicator -notmatch '\(\d+\)\s+⇣1') {
        throw 'behind indicator was not rendered'
    }

    $script:YafpInitialRemoteCheckPending = $true
    Push-Location $testRoot
    try {
        $outsideContext = Get-YafpGitContext
    }
    finally {
        Pop-Location
    }
    Assert-Equal $null $outsideContext `
        'non-repository prompt context'
    Assert-Equal $true $script:YafpInitialRemoteCheckPending `
        'non-repository prompt preserved initial refresh'

    Push-Location $local
    try {
        $startupContext = Get-YafpGitContext
    }
    finally {
        Pop-Location
    }
    Assert-Equal $false $script:YafpInitialRemoteCheckPending `
        'repository prompt consumed initial refresh'
    Assert-Equal $true $startupContext.RemoteStatus.Refreshing `
        'repository startup forced a remote refresh'
    Assert-Equal 0 $startupContext.RemoteStatus.RefreshIn `
        'repository startup bypassed the cached countdown'
    $job = $script:YafpRemoteJobs[$cacheFile]
    $null = Wait-Job -Job $job -Timeout 30
    Assert-Equal Completed $job.State `
        'repository startup refresh background job state'

    foreach ($commandCase in @(
        @{ Command = 'git push'; Expected = $true }
        @{ Command = 'git fetch origin'; Expected = $true }
        @{ Command = 'git pull --ff-only'; Expected = $true }
        @{ Command = 'git -C other-repo push'; Expected = $true }
        @{ Command = 'git status'; Expected = $false }
        @{ Command = 'Write-Output "git push"'; Expected = $false }
    )) {
        $detected = Test-YafpGitSyncCommand -CommandLine $commandCase.Command
        Assert-Equal $commandCase.Expected $detected `
            "sync command: $($commandCase.Command)"
    }

    $forced = Get-YafpRemoteContext -RepoRoot $local -Branch main `
        -ForceRefresh
    Assert-Equal $true $forced.Refreshing 'forced refresh state'
    Assert-Equal 0 $forced.RefreshIn 'forced refresh countdown'
    $job = $script:YafpRemoteJobs[$cacheFile]
    $null = Wait-Job -Job $job -Timeout 30
    Assert-Equal Completed $job.State 'forced refresh background job state'
    $remote = Get-YafpRemoteContext -RepoRoot $local -Branch main
    if ($remote.RefreshIn -le 0) {
        throw 'forced refresh did not reset the countdown'
    }

    foreach ($indicatorCase in @(
        @{ State = 'current'; Ahead = 0; Text = '✓' }
        @{ State = 'ahead'; Ahead = 2; Text = '⇡2' }
        @{ State = 'checking'; Ahead = 0; Text = '…' }
        @{ State = 'error'; Ahead = 0; Text = '❕' }
    )) {
        $status = [pscustomobject]@{
            State = $indicatorCase.State
            Ahead = $indicatorCase.Ahead
            Behind = 0
            Upstream = 'origin/main'
            CheckedAt = 0L
            Refreshing = $false
            RefreshIn = 300L
        }
        $gitContext = [pscustomobject]@{ RemoteStatus = $status }
        $indicator = Write-YafpGitRemoteStatus -Git $gitContext 6>&1 |
            Out-String
        if ($indicator -notmatch [regex]::Escape($indicatorCase.Text)) {
            throw "$($indicatorCase.State) indicator was not rendered"
        }
    }

    $offlineStatus = [pscustomobject]@{
        State = 'error'
        Ahead = 0
        Behind = 0
        Upstream = 'origin/main'
        CheckedAt = 0L
        Refreshing = $false
        RefreshIn = 300L
    }
    $offlineContext = [pscustomobject]@{
        Git = [pscustomobject]@{ RemoteStatus = $offlineStatus }
    }
    $warning = Write-YafpRemoteWarning -Context $offlineContext 6>&1 |
        Out-String
    if ($warning -notmatch '⚡️ No internet connection\.') {
        throw 'offline warning was not rendered'
    }

    $context = [pscustomobject]@{
        Git = [pscustomobject]@{ RemoteStatus = $remote }
    }
    $warning = Write-YafpRemoteWarning -Context $context 6>&1 | Out-String
    if ($warning -notmatch 'OUTDATED REPOSITORY' -or
        $warning -notmatch '1 commit is missing from origin/main') {
        throw 'behind warning was not rendered'
    }

    $aheadStatus = [pscustomobject]@{
        State = 'ahead'
        Ahead = 2
        Behind = 0
        Upstream = 'origin/main'
        CheckedAt = 0L
        Refreshing = $false
        RefreshIn = 300L
    }
    $aheadContext = [pscustomobject]@{
        Git = [pscustomobject]@{ RemoteStatus = $aheadStatus }
    }
    $warning = Write-YafpRemoteWarning -Context $aheadContext 6>&1 |
        Out-String
    if ($warning -notmatch (
        '⚠️ REMOTE NOT UPDATED: 2 local commits have not been pushed ' +
        'to origin/main ⚠️'
    )) {
        throw 'ahead warning was not rendered'
    }

    & git -C $local config user.name 'YAFP Test'
    & git -C $local config user.email 'yafp@example.invalid'
    Set-Content -LiteralPath (Join-Path $local 'local.txt') `
        -Value 'local change'
    & git -C $local add local.txt
    & git -C $local commit --quiet -m local-change

    Start-YafpRemoteCheck -RepoRoot $local -LocalRef $localRef `
        -Upstream $upstream -RemoteName origin -CacheFile $cacheFile
    $job = $script:YafpRemoteJobs[$cacheFile]
    $null = Wait-Job -Job $job -Timeout 30
    Assert-Equal Completed $job.State 'diverged background job state'

    $remote = Get-YafpRemoteContext -RepoRoot $local -Branch main
    Assert-Equal diverged $remote.State 'diverged state'
    Assert-Equal 1 $remote.Ahead 'ahead count'
    Assert-Equal 1 $remote.Behind 'diverged behind count'

    $gitContext = [pscustomobject]@{ RemoteStatus = $remote }
    $indicator = Write-YafpGitRemoteStatus -Git $gitContext 6>&1 |
        Out-String
    if ($indicator -notmatch '⇡1⇣1') {
        throw 'diverged indicator was not rendered'
    }

    $global:YAFP_REMOTE_CHECK_INTERVAL = 0
    $disabled = Get-YafpRemoteContext -RepoRoot $local -Branch main
    Assert-Equal $null $disabled 'disabled state'

    Write-Output 'ok - asynchronous remote status and disabled interval'
}
finally {
    if (Get-Variable YafpRemoteJobs -Scope Script -ErrorAction Ignore) {
        @($script:YafpRemoteJobs.Values) |
            Remove-Job -Force -ErrorAction Ignore
    }
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
