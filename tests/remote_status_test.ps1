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
        @{ State = 'error'; Ahead = 0; Text = '!' }
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

    $context = [pscustomobject]@{
        Git = [pscustomobject]@{ RemoteStatus = $remote }
    }
    $warning = Write-YafpRemoteWarning -Context $context 6>&1 | Out-String
    if ($warning -notmatch 'OUTDATED REPOSITORY' -or
        $warning -notmatch '1 commit is missing from origin/main') {
        throw 'behind warning was not rendered'
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
