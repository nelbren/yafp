$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$rootDir = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "yafp-tracking-$([guid]::NewGuid())"
function Assert-Equal {
    param($Expected, $Actual, [string]$Label)
    if ($Expected -ne $Actual) { throw "$Label`: expected [$Expected], got [$Actual]" }
}
try {
    $local = Join-Path $testRoot 'local'
    $origin = Join-Path $testRoot 'origin.git'
    & git init --quiet --initial-branch=main $local
    & git init --quiet --bare --initial-branch=main $origin
    . (Join-Path $rootDir 'yafp-ps.ps1')
    $global:YAFP_REMOTE_CHECK_INTERVAL = 300
    $global:YAFP_REPOS = 1
    function Get-YafpCursorColumn { return 1 }
    Push-Location $local
    try {
        $context = Get-YafpGitContext
        Assert-Equal 'no-commits' $context.RemoteStatus.State 'git init context'
        Assert-Equal 'main' $context.Branch 'unborn branch name'
        Assert-Equal $null $context.RemoteStatus.RefreshIn 'no commit countdown'
        foreach ($theme in 'default', 'minimal', 'light') {
            . (Join-Path $rootDir "themes/$theme.ps1")
            $indicator = Write-YafpGitRemoteStatus -Git $context 6>&1 | Out-String
            if ($indicator -notmatch '○0' -or $indicator -notmatch '⚠ NO COMMITS') {
                throw "$theme missing initial commit warning"
            }
        }
        Set-Content file.txt initial
        & git add file.txt
        $context = Get-YafpGitContext
        Assert-Equal 1 $context.StagedCount 'initial staged file'
        Assert-Equal 'no-commits' $context.RemoteStatus.State 'staging retains warning'
    }
    finally { Pop-Location }
    & git -C $local -c user.name=Test -c user.email=test@example.invalid `
        -c commit.gpgsign=false -c core.hooksPath=/dev/null commit --quiet --allow-empty -m initial
    Assert-Equal $null (Get-YafpRemoteContext -RepoRoot $local -Branch main) `
        'first commit clears initial warning'
    $gitDir = & git -C $local rev-parse --absolute-git-dir
    $cacheFile = Join-Path $gitDir 'yafp-remote-status'
    & git -C $local remote add origin $origin
    $remote = Get-YafpRemoteContext -RepoRoot $local -Branch main
    Assert-Equal no-upstream $remote.State 'no upstream warning'
    Assert-Equal $null $remote.RefreshIn 'no tracking countdown'
    Assert-Equal $false $remote.Refreshing 'no tracking refresh'
    Assert-Equal Yellow (Get-YafpRemoteStateColor no-upstream) 'tracking warning tone'
    Assert-Equal '⇡? No upstream' (Format-YafpRemoteStateLabel no-upstream) 'tracking label'
    foreach ($theme in 'default', 'minimal', 'light') {
        . (Join-Path $rootDir "themes/$theme.ps1")
        $indicator = Write-YafpGitRemoteStatus -Git ([pscustomobject]@{
            RemoteStatus = $remote
        }) 6>&1 | Out-String
        if ($indicator -notmatch '⇡\?' -or $indicator -notmatch '⚠ NO UPSTREAM') {
            throw "$theme missing tracking warning"
        }
    }
    if (Test-Path -LiteralPath "$cacheFile.lock") {
        throw 'no upstream started a worker'
    }
    & git -C $local checkout --quiet --detach
    $remote = Get-YafpRemoteContext -RepoRoot $local -Branch unnamed
    Assert-Equal $null $remote 'detached has no tracking warning'
    & git -C $local checkout --quiet main
    & git -C $local remote remove origin
    $remote = Get-YafpRemoteContext -RepoRoot $local -Branch main
    Assert-Equal $null $remote 'local-only repo has no tracking warning'
    & git -C $local remote add publish $origin
    $remote = Get-YafpRemoteContext -RepoRoot $local -Branch main
    Assert-Equal no-upstream $remote.State 'remote without tracking refs'

    $global:YAFP_REMOTE_CHECK_INTERVAL = 0
    Assert-Equal $null (Get-YafpRemoteContext -RepoRoot $local -Branch main) 'disabled'
    $global:YAFP_REMOTE_CHECK_INTERVAL = 300
    & git -C $local push --quiet -u publish main
    $null = Get-YafpRemoteContext -RepoRoot $local -Branch main
    $job = $script:YafpRemoteJobs[$cacheFile]
    $null = Wait-Job -Job $job -Timeout 30
    Assert-Equal Completed $job.State 'tracking refresh completed'
    $remote = Get-YafpRemoteContext -RepoRoot $local -Branch main
    Assert-Equal current $remote.State 'configured tracking clears warning'
    Write-Output 'ok - no upstream warning, themes, and tracking recovery'
}
finally {
    if (Get-Variable YafpRemoteJobs -Scope Script -ErrorAction Ignore) {
        @($script:YafpRemoteJobs.Values) | Remove-Job -Force -ErrorAction Ignore
    }
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
