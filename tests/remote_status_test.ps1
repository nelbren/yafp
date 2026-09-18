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
    $global:YAFP_DARKC = 1
    $warningStyle = Get-YafpSeverityStyle -Severity warning
    Assert-Equal Black $warningStyle.Foreground `
        'warning foreground color'
    Assert-Equal Yellow $warningStyle.Background `
        'warning background color'
    $errorStyle = Get-YafpSeverityStyle -Severity error
    Assert-Equal White $errorStyle.Foreground `
        'error foreground color'
    Assert-Equal DarkRed $errorStyle.Background `
        'error background color'
    $global:YAFP_DARKC = 0
    $brightWarningStyle = Get-YafpSeverityStyle -Severity warning
    Assert-Equal Yellow $brightWarningStyle.Background `
        'bright warning background color'
    $brightErrorStyle = Get-YafpSeverityStyle -Severity error
    Assert-Equal Red $brightErrorStyle.Background `
        'bright error background color'
    $global:YAFP_DARKC = 1

    $stagedContext = [pscustomobject]@{
        Git = [pscustomobject]@{
            StagedCount = 4
            RemoteStatus = $null
        }
    }
    $stagedExpansion = Write-YafpStagedExpansion `
        -Git $stagedContext.Git 6>&1 | Out-String
    if ($stagedExpansion -notmatch
        '⎝ COMMIT PENDING: 4 staged files are ready to commit ⎠') {
        throw 'staged Git expansion was not rendered'
    }
    $stagedContext.Git.StagedCount = 1
    $stagedExpansion = Write-YafpStagedExpansion `
        -Git $stagedContext.Git 6>&1 | Out-String
    if ($stagedExpansion -notmatch
        '⎝ COMMIT PENDING: 1 staged file is ready to commit ⎠') {
        throw 'singular staged Git expansion was not rendered'
    }
    $stagedContext.Git.RemoteStatus = [pscustomobject]@{
        State = 'ahead'
        ConnectionAnnouncement = $false
    }
    $stagedExpansion = Write-YafpStagedExpansion `
        -Git $stagedContext.Git 6>&1 | Out-String
    $twoRowsUp = "$([char]27)[2A"
    if (-not $stagedExpansion.Contains($twoRowsUp)) {
        throw 'staged Git expansion did not preserve the remote expansion row'
    }
    Assert-Equal 'COMMIT PENDING: 1' (
        Get-YafpExpansionMessage `
            -LongMessage 'COMMIT PENDING: 1 staged file is ready to commit' `
            -ShortMessage 'COMMIT PENDING: 1' -TerminalWidth 21
    ) 'compact staged Git expansion message'
    Assert-Equal '' (
        Get-YafpExpansionMessage `
            -LongMessage 'COMMIT PENDING: 12 staged files are ready to commit' `
            -ShortMessage 'COMMIT PENDING: 12' -TerminalWidth 72 `
            -IndicatorColumn 65 -IndicatorWidth 4
    ) 'hide staged expansion when the short banner crosses the right edge'
    Assert-Equal '' (
        Get-YafpExpansionMessage `
            -LongMessage 'COMMIT PENDING: 12 staged files are ready to commit' `
            -ShortMessage 'COMMIT PENDING: 12' -TerminalWidth 15
    ) 'hide staged expansion when the terminal is narrower than the short banner'
    Assert-Equal 'COMMIT PENDING: 12' (
        Get-YafpExpansionMessage `
            -LongMessage 'COMMIT PENDING: 12 staged files are ready to commit' `
            -ShortMessage 'COMMIT PENDING: 12' -TerminalWidth 72 `
            -IndicatorColumn 50 -IndicatorWidth 4
    ) 'staged expansion accounts for its indicator column'
    Assert-Equal 'COMMIT PENDING: 12 staged files are ready to commit' (
        Get-YafpExpansionMessage `
            -LongMessage 'COMMIT PENDING: 12 staged files are ready to commit' `
            -ShortMessage 'COMMIT PENDING: 12' -TerminalWidth 72 `
            -IndicatorColumn 30 -IndicatorWidth 4
    ) 'staged expansion keeps the long message when centered text fits'

    $statusReport = @(Format-YafpRemoteStatusReport -State current `
        -Remaining 175 -Interval 300 -Now 0)
    Assert-Equal '🌐︎       Remote: ✓ Up to date' $statusReport[0] `
        'detailed remote state'
    Assert-Equal (
        '🟡        Timer: ████░░░░░░ 42% · 125/300s elapsed · 175s remaining'
    ) $statusReport[1] 'detailed timer progress'
    if ($statusReport[2] -notmatch '^🕘 Current time: \d{2}:\d{2}:\d{2}$') {
        throw 'detailed status omitted the current time'
    }
    Assert-Equal Green (Get-YafpRemoteStateColor -State current) `
        'current state intense green color'
    Assert-Equal Yellow (Get-YafpRemoteStateColor -State ahead) `
        'ahead state intense yellow color'
    Assert-Equal Yellow (Get-YafpRemoteStateColor -State checking) `
        'checking state intense yellow color'
    Assert-Equal Yellow (Get-YafpRemoteStateColor -State current `
        -Refreshing $true) 'refreshing state intense yellow color'
    Assert-Equal Red (Get-YafpRemoteStateColor -State behind) `
        'behind state intense red color'
    Assert-Equal Red (Get-YafpRemoteStateColor -State diverged) `
        'diverged state intense red color'
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
    Assert-Equal Confirm-YafpRemoteAlert (Get-Alias yafp-ack).Definition `
        'yafp-ack command'
    Assert-Equal Show-YafpDemo (Get-Alias yafp-demo).Definition `
        'yafp-demo command'
    Assert-Equal Show-YafpHelp (Get-Alias yafp-help).Definition `
        'yafp-help command'
    Assert-Equal Show-YafpStats (Get-Alias yafp-stats).Definition `
        'yafp-stats command'
    $originalGetYafpRemoteContext = `
        (Get-Command Get-YafpRemoteContext).ScriptBlock
    function Get-YafpRemoteContext {
        param(
            [string]$RepoRoot,
            [string]$Branch,
            [switch]$ForceRefresh
        )
        return [pscustomobject]@{ State = 'error' }
    }
    $script:YafpRemoteOfflineAcknowledged = $false
    $ackOutput = Confirm-YafpRemoteAlert 6>&1 | Out-String
    Assert-Equal $true $script:YafpRemoteOfflineAcknowledged `
        'yafp-ack acknowledges the current offline alert'
    if ($ackOutput -notmatch 'Offline alert acknowledged\.') {
        throw 'yafp-ack confirmation was not rendered'
    }
    Set-Item -LiteralPath Function:Get-YafpRemoteContext `
        -Value $originalGetYafpRemoteContext
    $script:YafpRemoteOfflineAcknowledged = $false
    $originalWriteYafpText = (Get-Command Write-YafpText).ScriptBlock
    $script:helpWrites = [Collections.Generic.List[object]]::new()
    function Write-YafpText {
        param(
            [string]$Text,
            [string]$ForegroundColor,
            [AllowNull()][object]$BackgroundColor,
            [switch]$NoNewline
        )
        $script:helpWrites.Add([pscustomobject]@{
            Text = $Text
            Color = $ForegroundColor
            NoNewline = [bool]$NoNewline
        })
    }
    yafp-help
    $expectedHelpWrites = @(
        [pscustomobject]@{ Text = 'yafp-status'; Color = 'Yellow'; NoNewline = $true }
        [pscustomobject]@{ Text = ' • '; Color = 'Gray'; NoNewline = $true }
        [pscustomobject]@{ Text = 'Show remote status and refresh timer.'; Color = 'White'; NoNewline = $false }
        [pscustomobject]@{ Text = 'yafp-refresh'; Color = 'Yellow'; NoNewline = $true }
        [pscustomobject]@{ Text = ' • '; Color = 'Gray'; NoNewline = $true }
        [pscustomobject]@{ Text = 'Request an immediate remote refresh.'; Color = 'White'; NoNewline = $false }
        [pscustomobject]@{ Text = 'yafp-ack'; Color = 'Yellow'; NoNewline = $true }
        [pscustomobject]@{ Text = ' • '; Color = 'Gray'; NoNewline = $true }
        [pscustomobject]@{ Text = 'Acknowledge the current offline alert.'; Color = 'White'; NoNewline = $false }
        [pscustomobject]@{ Text = 'yafp-reload'; Color = 'Yellow'; NoNewline = $true }
        [pscustomobject]@{ Text = ' • '; Color = 'Gray'; NoNewline = $true }
        [pscustomobject]@{ Text = 'Reload YAFP in the current shell.'; Color = 'White'; NoNewline = $false }
        [pscustomobject]@{ Text = 'yafp-stats'; Color = 'Yellow'; NoNewline = $true }
        [pscustomobject]@{ Text = ' • '; Color = 'Gray'; NoNewline = $true }
        [pscustomobject]@{ Text = 'Show command execution statistics.'; Color = 'White'; NoNewline = $false }
        [pscustomobject]@{ Text = 'yafp-help'; Color = 'Yellow'; NoNewline = $true }
        [pscustomobject]@{ Text = ' • '; Color = 'Gray'; NoNewline = $true }
        [pscustomobject]@{ Text = 'Show available YAFP commands.'; Color = 'White'; NoNewline = $false }
    )
    Assert-Equal $expectedHelpWrites.Count $script:helpWrites.Count `
        'yafp-help colored write count'
    for ($index = 0; $index -lt $expectedHelpWrites.Count; $index++) {
        Assert-Equal $expectedHelpWrites[$index].Text `
            $script:helpWrites[$index].Text "yafp-help text $index"
        Assert-Equal $expectedHelpWrites[$index].Color `
            $script:helpWrites[$index].Color "yafp-help color $index"
        Assert-Equal $expectedHelpWrites[$index].NoNewline `
            $script:helpWrites[$index].NoNewline "yafp-help newline $index"
    }
    Set-Item -LiteralPath Function:Write-YafpText `
        -Value $originalWriteYafpText

    $savedCommandsTotal = $script:YafpCommandsTotal
    $savedCommandsSucceeded = $script:YafpCommandsSucceeded
    $savedCommandsFailed = $script:YafpCommandsFailed
    $savedStatsHistoryId = $script:YafpCommandStatsLastHistoryId
    $script:YafpCommandsTotal = 0
    $script:YafpCommandsSucceeded = 0
    $script:YafpCommandsFailed = 0
    $script:YafpCommandStatsLastHistoryId = 100
    Assert-Equal $true (Update-YafpCommandStats -HistoryId 101 `
        -WasEmpty $false -HadError $false) 'successful command counted'
    Assert-Equal $false (Update-YafpCommandStats -HistoryId 101 `
        -WasEmpty $false -HadError $false) 'duplicate command ignored'
    Assert-Equal $true (Update-YafpCommandStats -HistoryId 102 `
        -WasEmpty $false -HadError $true) 'failed command counted'
    Assert-Equal $false (Update-YafpCommandStats -HistoryId 103 `
        -WasEmpty $true -HadError $false) 'empty input ignored'
    Assert-Equal 2 $script:YafpCommandsTotal 'command total count'
    Assert-Equal 1 $script:YafpCommandsSucceeded 'successful command count'
    Assert-Equal 1 $script:YafpCommandsFailed 'failed command count'

    $script:statsWrites = [Collections.Generic.List[object]]::new()
    function Write-YafpText {
        param(
            [string]$Text,
            [string]$ForegroundColor,
            [AllowNull()][object]$BackgroundColor,
            [switch]$NoNewline
        )
        $script:statsWrites.Add([pscustomobject]@{
            Text = $Text
            Color = $ForegroundColor
        })
    }
    yafp-stats
    $expectedStatsWrites = @(
        [pscustomobject]@{ Text = '✓ Succeeded: 1 (050%)'; Color = 'Green' }
        [pscustomobject]@{ Text = '☒ Failed:    1 (050%)'; Color = 'Red' }
        [pscustomobject]@{ Text = ('━' * 21); Color = 'Gray' }
        [pscustomobject]@{ Text = '∑ Total:     2 (100%)'; Color = 'White' }
    )
    Assert-Equal $expectedStatsWrites.Count $script:statsWrites.Count `
        'yafp-stats colored write count'
    for ($index = 0; $index -lt $expectedStatsWrites.Count; $index++) {
        Assert-Equal $expectedStatsWrites[$index].Text `
            $script:statsWrites[$index].Text "yafp-stats text $index"
        Assert-Equal $expectedStatsWrites[$index].Color `
            $script:statsWrites[$index].Color "yafp-stats color $index"
    }
    $script:YafpCommandsTotal = 0
    $script:YafpCommandsSucceeded = 0
    $script:YafpCommandsFailed = 0
    $script:statsWrites.Clear()
    yafp-stats
    Assert-Equal '✓ Succeeded: 0 (000%)' $script:statsWrites[0].Text `
        'empty succeeded percentage'
    Assert-Equal '☒ Failed:    0 (000%)' $script:statsWrites[1].Text `
        'empty failed percentage'
    Assert-Equal '∑ Total:     0 (100%)' $script:statsWrites[3].Text `
        'empty total percentage'
    $script:YafpCommandsTotal = 13
    $script:YafpCommandsSucceeded = 11
    $script:YafpCommandsFailed = 2
    $script:statsWrites.Clear()
    yafp-stats
    Assert-Equal '✓ Succeeded: 11 (085%)' $script:statsWrites[0].Text `
        'aligned succeeded count'
    Assert-Equal '☒ Failed:     2 (015%)' $script:statsWrites[1].Text `
        'aligned failed count'
    Assert-Equal ('━' * 22) $script:statsWrites[2].Text `
        'expanded statistics separator'
    Assert-Equal '∑ Total:     13 (100%)' $script:statsWrites[3].Text `
        'aligned total count'
    Set-Item -LiteralPath Function:Write-YafpText `
        -Value $originalWriteYafpText
    $script:YafpCommandsTotal = $savedCommandsTotal
    $script:YafpCommandsSucceeded = $savedCommandsSucceeded
    $script:YafpCommandsFailed = $savedCommandsFailed
    $script:YafpCommandStatsLastHistoryId = $savedStatsHistoryId
    $helpDefinition = (Get-Command Show-YafpHelp).Definition
    foreach ($color in @('Yellow', 'Gray', 'White')) {
        if ($helpDefinition -notmatch "ForegroundColor $color") {
            throw "yafp-help does not use $color"
        }
    }
    $exitEventDefinition = (Get-Command Install-YafpExitEvent).Definition
    if ($exitEventDefinition -notmatch 'PowerShell\.Exiting' -or
        $exitEventDefinition -notmatch 'Show-YafpStats -DirectConsole') {
        throw 'PowerShell exit event does not render yafp-stats'
    }
    if ((Get-Command Show-YafpDemo).Definition -notmatch
        [regex]::Escape('Control+C to break this ♾️  loop 🔁 ($($sleepSecs)s)')) {
        throw 'yafp-demo interruption hint is unavailable'
    }
    if ((Get-Command Show-YafpDemo).Definition -notmatch
        'Start-Sleep -Seconds \$sleepSecs') {
        throw 'yafp-demo does not reuse its configured sleep interval'
    }
    if ((Get-Command Show-YafpDemo).Definition -notmatch
        'Show-YafpPromptPreview') {
        throw 'yafp-demo does not render a prompt preview'
    }
    $savedRepos = $global:YAFP_REPOS
    $savedVenv = $global:YAFP_PVENV
    $savedError = $global:YAFP_ERROR
    $savedClock = $global:YAFP_CLOCK
    try {
        $global:YAFP_REPOS = 0
        $global:YAFP_PVENV = 0
        $global:YAFP_ERROR = 0
        $global:YAFP_CLOCK = 0
        $previewOutput = Show-YafpPromptPreview 6>&1 | Out-String
    }
    finally {
        $global:YAFP_REPOS = $savedRepos
        $global:YAFP_PVENV = $savedVenv
        $global:YAFP_ERROR = $savedError
        $global:YAFP_CLOCK = $savedClock
    }
    if ($previewOutput -match [regex]::Escape("$([char]27)]133;")) {
        throw 'PowerShell prompt preview emits OSC 133 lifecycle markers'
    }
    if ($previewOutput -notmatch [regex]::Escape($env:USERNAME) -or
        $previewOutput -notmatch [regex]::Escape($env:COMPUTERNAME)) {
        throw 'PowerShell prompt preview omitted the current user or host'
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
    $cacheFields = ([IO.File]::ReadAllText($cacheFile).TrimEnd()) -split "`t"
    Assert-Equal 8 $cacheFields.Count 'remote cache field count'
    Assert-Equal "$(& git -C $local rev-parse HEAD)" $cacheFields[6] `
        'cached local object ID'
    Assert-Equal "$(& git -C $local rev-parse origin/main)" $cacheFields[7] `
        'cached upstream object ID'

    $gitContext = [pscustomobject]@{ RemoteStatus = $remote.PSObject.Copy() }
    foreach ($announceConnection in @($true, $false)) {
        $gitContext.RemoteStatus.ConnectionAnnouncement = $announceConnection
        $indicator = Write-YafpGitRemoteStatus -Git $gitContext 6>&1 |
            Out-String
        # Banner text and cursor movement are emitted between these fields.
        # Their visual adjacency is not adjacency in the information stream.
        $countdownPattern = [regex]::Escape("($($remote.RefreshIn))")
        if ($indicator -notmatch "^\s*$countdownPattern\s") {
            throw 'behind countdown was not rendered'
        }
        if ($indicator -notmatch '⇣1\s*$') {
            throw 'behind indicator was not rendered'
        }
    }

    $lockDir = "$cacheFile.lock"
    $null = New-Item -ItemType Directory -Path $lockDir
    $refreshingRemote = Get-YafpRemoteContext -RepoRoot $local -Branch main
    Assert-Equal $true $refreshingRemote.Refreshing `
        'active remote worker remains visible across renders'
    Assert-Equal 0 $refreshingRemote.RefreshIn `
        'active remote worker hides the cached countdown'
    Remove-Item -LiteralPath $lockDir -Force

    & git -C $local update-ref refs/remotes/origin/main HEAD
    $invalidatedRemote = Get-YafpRemoteContext `
        -RepoRoot $local -Branch main
    Assert-Equal checking $invalidatedRemote.State `
        'upstream object ID change invalidated the cached state'
    $job = $script:YafpRemoteJobs[$cacheFile]
    $null = Wait-Job -Job $job -Timeout 30
    Assert-Equal Completed $job.State 'upstream-change background job state'
    $remote = Get-YafpRemoteContext -RepoRoot $local -Branch main
    Assert-Equal behind $remote.State `
        'upstream-change refresh restored the remote state'

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
    Assert-Equal $true `
        (Test-YafpGitPullCommand -CommandLine 'git pull --ff-only') `
        'git pull command'
    Assert-Equal $false `
        (Test-YafpGitPullCommand -CommandLine 'git fetch origin') `
        'git fetch is not pull'
    Assert-Equal Invoke-YafpReload (Get-Alias yafp-reload).Definition `
        'yafp-reload command'

    $script:YafpCommandsTotal = 7
    $script:YafpCommandsSucceeded = 5
    $script:YafpCommandsFailed = 2
    Invoke-YafpReload
    Assert-Equal Invoke-YafpReload (Get-Alias yafp-reload).Definition `
        'yafp-reload command after reload'
    Assert-Equal Show-YafpHelp (Get-Alias yafp-help).Definition `
        'yafp-help command after reload'
    Assert-Equal Confirm-YafpRemoteAlert (Get-Alias yafp-ack).Definition `
        'yafp-ack command after reload'
    Assert-Equal Show-YafpStats (Get-Alias yafp-stats).Definition `
        'yafp-stats command after reload'
    Assert-Equal 7 $script:YafpCommandsTotal 'total preserved after reload'
    Assert-Equal 5 $script:YafpCommandsSucceeded `
        'succeeded preserved after reload'
    Assert-Equal 2 $script:YafpCommandsFailed 'failed preserved after reload'
    if (-not (Get-Command prompt -CommandType Function -ErrorAction Ignore)) {
        throw 'prompt function was not retained after reload'
    }

    $global:YAFP_AUTO_RELOAD = 1
    $script:YafpLoadedCommit = 'old-commit'
    $script:YafpReloadCalled = $false
    function Get-YafpCurrentCommit { return 'new-commit' }
    function Invoke-YafpReload {
        $script:YafpReloadCalled = $true
        $script:YafpLoadedCommit = 'new-commit'
    }
    Assert-Equal $true (
        Invoke-YafpAutoReload -CommandLine 'git pull --ff-only' `
            -CommandSucceeded $true
    ) 'changed commit automatic reload'
    Assert-Equal $true $script:YafpReloadCalled `
        'automatic reload invocation'
    Assert-Equal $false (
        Invoke-YafpAutoReload -CommandLine 'git pull --ff-only' `
            -CommandSucceeded $true
    ) 'unchanged commit automatic reload'
    $global:YAFP_AUTO_RELOAD = 0
    $script:YafpLoadedCommit = 'old-commit'
    Assert-Equal $false (
        Invoke-YafpAutoReload -CommandLine 'git pull' `
            -CommandSucceeded $true
    ) 'disabled automatic reload'

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
    $script:YafpRemoteConnectivityState = 'offline'
    $script:YafpSessionStartedAt = 0L
    $remote = Get-YafpRemoteContext -RepoRoot $local -Branch main
    Assert-Equal $true $remote.ConnectionAnnouncement `
        'first recovered remote check announces internet connection'
    $remoteAgain = Get-YafpRemoteContext -RepoRoot $local -Branch main
    Assert-Equal $false $remoteAgain.ConnectionAnnouncement `
        'internet connection is announced only once per transition'
    $script:YafpRemoteConnectivityState = 'offline'
    $recoveredAgain = Get-YafpRemoteContext -RepoRoot $local -Branch main
    Assert-Equal $true $recoveredAgain.ConnectionAnnouncement `
        'a later offline-to-online transition is announced again'
    $remote = Get-YafpRemoteContext -RepoRoot $local -Branch main

    $connectedStatus = [pscustomobject]@{
        State = 'current'
        Ahead = 0
        Behind = 0
        Upstream = 'origin/main'
        CheckedAt = 0L
        Refreshing = $false
        RefreshIn = 300L
        ConnectionAnnouncement = $true
    }
    $connectedContext = [pscustomobject]@{
        Git = [pscustomobject]@{ RemoteStatus = $connectedStatus }
    }
    $row = Write-YafpRemoteExpansionRow -Context $connectedContext 6>&1 |
        Out-String
    if (-not $row) {
        throw 'connection announcement row was not reserved'
    }
    $expansion = Write-YafpRemoteExpansion -Remote $connectedStatus `
        -IndicatorText '✓🌐︎' 6>&1 | Out-String
    if ($expansion -notmatch '⎝ INTERNET CONNECTION ⎠') {
        throw 'connection announcement was not rendered'
    }
    $originalWriteYafpText = (Get-Command Write-YafpText).ScriptBlock
    $script:connectionWrites = [Collections.Generic.List[object]]::new()
    function Write-YafpText {
        param(
            [string]$Text,
            [string]$ForegroundColor,
            [AllowNull()][object]$BackgroundColor,
            [switch]$NoNewline
        )
        $script:connectionWrites.Add([pscustomobject]@{
            Text = $Text
            Foreground = $ForegroundColor
            Background = $BackgroundColor
        })
    }
    $connectedStatus.RefreshIn = $null
    $null = Write-YafpGitRemoteStatus `
        -Git $connectedContext.Git 6>&1 | Out-String
    $transitionIndicator = $script:connectionWrites |
        Where-Object Text -EQ '✓🌐︎' | Select-Object -Last 1
    $transitionBanner = $script:connectionWrites |
        Where-Object Text -EQ '⎝ INTERNET CONNECTION ⎠' |
        Select-Object -Last 1
    Assert-Equal White $transitionBanner.Foreground `
        'connection banner foreground'
    Assert-Equal DarkGreen $transitionBanner.Background `
        'connection banner background'
    Assert-Equal White $transitionIndicator.Foreground `
        'connection indicator foreground'
    Assert-Equal DarkGreen $transitionIndicator.Background `
        'connection indicator background'

    $script:connectionWrites.Clear()
    $connectedStatus.ConnectionAnnouncement = $false
    $null = Write-YafpGitRemoteStatus `
        -Git $connectedContext.Git 6>&1 | Out-String
    $steadyIndicator = $script:connectionWrites |
        Where-Object Text -EQ '✓🌐︎' | Select-Object -Last 1
    Assert-Equal Green $steadyIndicator.Foreground `
        'steady connection indicator foreground'
    Assert-Equal $null $steadyIndicator.Background `
        'steady connection indicator background'
    Set-Item -LiteralPath Function:Write-YafpText `
        -Value $originalWriteYafpText

    foreach ($indicatorCase in @(
        @{ State = 'current'; Ahead = 0; Text = '✓🌐︎' }
        @{ State = 'ahead'; Ahead = 2; Text = '⇡2' }
        @{ State = 'checking'; Ahead = 0; Text = '…' }
        @{ State = 'error'; Ahead = 0; Text = '☒🌐︎' }
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
    $warning = Write-YafpRemoteExpansionRow -Context $offlineContext 6>&1 |
        Out-String
    if (-not $warning) {
        throw 'offline warning row was not reserved'
    }
    $expansion = Write-YafpRemoteExpansion -Remote $offlineStatus `
        -IndicatorText '☒🌐︎' 6>&1 | Out-String
    if ($expansion -notmatch '⎝ NO INTERNET CONNECTION ⎠') {
        throw 'offline expansion was not rendered'
    }
    if ($expansion -notmatch ([regex]::Escape("$([char]27)[s$([char]27)[1A"))) {
        throw 'offline expansion was not positioned above its indicator'
    }

    $script:YafpRemoteOfflineAcknowledged = $true
    $row = Write-YafpRemoteExpansionRow -Context $offlineContext 6>&1 |
        Out-String
    Assert-Equal '' $row 'acknowledged offline state reserves no banner row'
    $expansion = Write-YafpRemoteExpansion -Remote $offlineStatus `
        -IndicatorText '☒🌐︎' 6>&1 | Out-String
    Assert-Equal '' $expansion 'acknowledged offline banner is hidden'

    $originalWriteYafpText = (Get-Command Write-YafpText).ScriptBlock
    $script:ackWrites = [Collections.Generic.List[object]]::new()
    function Write-YafpText {
        param(
            [string]$Text,
            [string]$ForegroundColor,
            [AllowNull()][object]$BackgroundColor,
            [switch]$NoNewline
        )
        $script:ackWrites.Add([pscustomobject]@{
            Text = $Text
            Foreground = $ForegroundColor
            Background = $BackgroundColor
        })
    }
    $offlineStatus.RefreshIn = $null
    $null = Write-YafpGitRemoteStatus -Git $offlineContext.Git 6>&1 |
        Out-String
    $ackIndicator = $script:ackWrites |
        Where-Object Text -EQ '☒🌐︎' | Select-Object -Last 1
    Assert-Equal Red $ackIndicator.Foreground `
        'acknowledged offline indicator foreground'
    Assert-Equal $null $ackIndicator.Background `
        'acknowledged offline indicator background'
    Set-Item -LiteralPath Function:Write-YafpText `
        -Value $originalWriteYafpText
    $script:YafpRemoteOfflineAcknowledged = $false

    $context = [pscustomobject]@{
        Git = [pscustomobject]@{ RemoteStatus = $remote }
    }
    $warning = Write-YafpRemoteExpansionRow -Context $context 6>&1 |
        Out-String
    if (-not $warning) {
        throw 'behind warning row was not reserved'
    }
    $expansion = Write-YafpRemoteExpansion -Remote $remote `
        -IndicatorText '⇣1' 6>&1 | Out-String
    if ($expansion -notmatch '⎝ OUTDATED REPOSITORY' -or
        $expansion -notmatch '1 commit is missing from origin/main ⎠') {
        throw 'behind expansion was not rendered'
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
    $warning = Write-YafpRemoteExpansionRow -Context $aheadContext 6>&1 |
        Out-String
    if (-not $warning) {
        throw 'ahead warning row was not reserved'
    }
    $expansion = Write-YafpRemoteExpansion -Remote $aheadStatus `
        -IndicatorText '⇡2' 6>&1 | Out-String
    if ($expansion -notmatch (
        '⎝ REMOTE NOT UPDATED: 2 local commits have not been pushed ' +
        'to origin/main ⎠'
    )) {
        throw 'ahead expansion was not rendered'
    }

    $divergedStatus = [pscustomobject]@{
        State = 'diverged'
        Ahead = 2
        Behind = 3
        Upstream = 'origin/main'
        CheckedAt = 0L
        Refreshing = $false
        RefreshIn = 300L
    }
    $expansion = Write-YafpRemoteExpansion -Remote $divergedStatus `
        -IndicatorText '⇡2⇣3' 6>&1 | Out-String
    if ($expansion -notmatch (
        '⎝ DIVERGED REPOSITORY: local \+2 / remote \+3 relative to ' +
        'origin/main ⎠'
    )) {
        throw 'diverged expansion was not rendered'
    }
    Assert-Equal 'PUSH PENDING: 2' (
        Get-YafpExpansionMessage `
            -LongMessage 'REMOTE NOT UPDATED: 2 local commits have not been pushed to origin/main' `
            -ShortMessage 'PUSH PENDING: 2' -TerminalWidth 20
    ) 'compact ahead expansion message'
    Assert-Equal 'PULL PENDING: 1' (
        Get-YafpExpansionMessage `
            -LongMessage 'OUTDATED REPOSITORY: 1 commit is missing from origin/main' `
            -ShortMessage 'PULL PENDING: 1' -TerminalWidth 20
    ) 'compact behind expansion message'
    Assert-Equal 'DIVERGED: ⇡2 ⇣3' (
        Get-YafpExpansionMessage `
            -LongMessage 'DIVERGED REPOSITORY: local +2 / remote +3 relative to origin/main' `
            -ShortMessage 'DIVERGED: ⇡2 ⇣3' -TerminalWidth 20
    ) 'compact diverged expansion message'

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
