$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot '../scripts/windows/update/context.ps1')
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('yafp update ' + [guid]::NewGuid())
$null = New-Item -ItemType Directory $temporary
# Capture the common text writer arguments without changing the host palette.
$script:startupStyles = [Collections.Generic.List[object]]::new()
function Write-YafpText {
    param([string]$Text, [string]$ForegroundColor, [object]$BackgroundColor)
    $script:startupStyles.Add(@{ Text = $Text; Foreground = $ForegroundColor; Background = $BackgroundColor })
}
foreach ($case in @(
    @{ Severity = 'info'; Foreground = 'White'; Background = $null }
    @{ Severity = 'warning'; Foreground = 'Black'; Background = 'Yellow' }
    @{ Severity = 'error'; Foreground = 'White'; Background = 'DarkRed' }
    @{ Severity = 'success'; Foreground = 'White'; Background = 'DarkGreen' }
)) {
    $global:YAFP_DARKC = 1
    Write-YafpUpdateMessage -Severity $case.Severity -Text 'startup text'
    $actual = $script:startupStyles[-1]
    if ($actual.Foreground -ne $case.Foreground -or $actual.Background -ne $case.Background -or $actual.Text -ne 'startup text') {
        throw "Incorrect startup style: $($case.Severity)"
    }
}
$global:YAFP_DARKC = 0
Write-YafpUpdateMessage -Severity error -Text 'startup text'
if ($script:startupStyles[-1].Background -ne 'Red') { throw 'Bright error style must honor YAFP_DARKC' }
Remove-Item Function:Write-YafpText
$script:reloads = 0
$script:answer = ''
$previousUpdateSetting = $env:YAFP_UPDATE_CHECK
$env:YAFP_UPDATE_CHECK = '1'
function Invoke-YafpReload { $script:reloads++ }
function Read-Host {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidOverwritingBuiltInCmdlets', '',
        Justification = 'Supply explicit consent without reading the test runner terminal.'
    )]
    param([string]$Prompt)
    if ($Prompt -ne 'Update YAFP now? [y/N]') { throw 'Missing English consent prompt' }
    return $script:answer
}
function Invoke-TestGit {
    param([string[]]$Arguments)
    $result = & git @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Git fixture failed: $result" }
    return $result
}
function Start-TestCheck {
    Start-YafpUpdateCheck -Interactive $true
    if ($null -eq $script:YafpUpdateSample) { throw 'Check returned without a result' }

}
function Complete-TestCheck {
    return (@(Complete-YafpUpdateCheck 6>&1) | ForEach-Object { "$_" }) -join ''
}
try {
    $remote = Join-Path $temporary 'remote.git'
    $seed = Join-Path $temporary 'seed'
    $script:YafpRoot = Join-Path $temporary 'YAFP install'
    $null = Invoke-TestGit @('init', '--quiet', '--bare', $remote)
    $null = Invoke-TestGit @('clone', '--quiet', $remote, $seed)
    $null = Invoke-TestGit @('-C', $seed, 'config', 'user.name', 'Test')
    $null = Invoke-TestGit @('-C', $seed, 'config', 'user.email', 'test@example.invalid')
    $destination = Join-Path $seed 'scripts/windows/update'
    $null = New-Item -ItemType Directory $destination -Force
    Copy-Item (Join-Path $PSScriptRoot '../scripts/windows/update/collect.ps1') $destination
    Set-Content (Join-Path $seed 'file.txt') 'one'
    $null = Invoke-TestGit @('-C', $seed, 'add', '.')
    $null = Invoke-TestGit @('-C', $seed, 'commit', '--quiet', '-m', 'initial')
    $null = Invoke-TestGit @('-C', $seed, 'push', '--quiet', 'origin', 'HEAD')
    $null = Invoke-TestGit @('clone', '--quiet', $remote, $script:YafpRoot)
    $initial = Invoke-TestGit @('-C', $script:YafpRoot, 'rev-parse', 'HEAD')
    $initialBranch = Invoke-TestGit @('-C', $script:YafpRoot, 'symbolic-ref', '--short', 'HEAD')
    Add-Content (Join-Path $seed 'file.txt') 'two'
    $null = Invoke-TestGit @('-C', $seed, 'commit', '--quiet', '-am', 'second')
    $null = Invoke-TestGit @('-C', $seed, 'push', '--quiet', 'origin', 'HEAD')
    Start-YafpUpdateCheck -Interactive $false
    if ($null -ne $script:YafpUpdateSample) { throw 'Noninteractive loading started a check' }
    Start-TestCheck
    $output = Complete-TestCheck
    if ($output -notmatch '☒ OUTDATED REPOSITORY: YAFP is 1 commit\(s\)' -or $script:reloads -ne 0) {
        throw "Default consent or behind count incorrect: $output"
    }
    if ((Invoke-TestGit @('-C', $script:YafpRoot, 'rev-parse', 'HEAD')) -ne $initial) { throw 'Default answer pulled' }
    $script:answer = 'y'
    Start-TestCheck
    $null = Complete-TestCheck
    if ($script:reloads -ne 1 -or $null -ne $script:YafpUpdateSample) { throw 'Accepted pull must reload once without recursion' }
    if ((Invoke-TestGit @('-C', $script:YafpRoot, 'rev-parse', 'HEAD')) -ne
        (Invoke-TestGit @('-C', $seed, 'rev-parse', 'HEAD'))) { throw 'Wrong checkout updated' }
    Start-TestCheck
    if ((Complete-TestCheck) -notmatch 'REPOSITORY UP TO DATE') { throw 'Missing current status' }
    $null = Invoke-TestGit @('-C', $script:YafpRoot, 'remote', 'set-url', 'origin', (Join-Path $temporary 'missing.git'))
    Start-TestCheck
    if ((Complete-TestCheck) -ne '☒🌐 REMOTE CHECK FAILED') { throw 'Remote failure message' }
    $null = Invoke-TestGit @('-C', $script:YafpRoot, 'remote', 'set-url', 'origin', $remote)
    $null = Invoke-TestGit @('-C', $script:YafpRoot, 'config', 'user.name', 'Test')
    $null = Invoke-TestGit @('-C', $script:YafpRoot, 'config', 'user.email', 'test@example.invalid')
    Set-Content (Join-Path $script:YafpRoot 'local.txt') 'local'
    $null = Invoke-TestGit @('-C', $script:YafpRoot, 'add', 'local.txt')
    $null = Invoke-TestGit @('-C', $script:YafpRoot, 'commit', '--quiet', '-m', 'local')
    Start-TestCheck
    if ((Complete-TestCheck) -notmatch '⚠ REMOTE NOT UPDATED: 1 local commit has not been pushed to origin/') { throw 'Missing ahead warning' }
    Set-Content (Join-Path $script:YafpRoot 'dirty.tmp') 'dirty'
    Start-TestCheck
    if ((Complete-TestCheck) -notmatch 'UNCOMMITTED CHANGES') { throw 'Missing dirty warning' }
    Remove-Item -LiteralPath (Join-Path $script:YafpRoot 'dirty.tmp')
    Add-Content (Join-Path $seed 'file.txt') 'three'
    $null = Invoke-TestGit @('-C', $seed, 'commit', '--quiet', '-am', 'third')
    $null = Invoke-TestGit @('-C', $seed, 'push', '--quiet', 'origin', 'HEAD')
    $head = Invoke-TestGit @('-C', $script:YafpRoot, 'rev-parse', 'HEAD')
    Start-TestCheck
    if ((Complete-TestCheck) -notmatch '☒ DIVERGED REPOSITORY' -or $script:reloads -ne 1) { throw 'Diverged pull reloaded' }
    if ((Invoke-TestGit @('-C', $script:YafpRoot, 'rev-parse', 'HEAD')) -ne $head) { throw 'Divergence changed HEAD' }
    Start-TestCheck
    $null = Invoke-TestGit @('-C', $script:YafpRoot, 'checkout', '--quiet', '--detach')
    if ((Complete-TestCheck) -ne '') { throw 'Stale result requested consent' }
    Start-TestCheck
    if ((Complete-TestCheck) -notmatch 'DETACHED HEAD') { throw 'Missing detached status' }
    $null = Invoke-TestGit @('-C', $script:YafpRoot, 'checkout', '--quiet', $initialBranch)
    $null = Invoke-TestGit @('-C', $script:YafpRoot, 'branch', '--unset-upstream')
    Start-TestCheck
    if ((Complete-TestCheck) -notmatch 'NO UPSTREAM') { throw 'Missing upstream status' }
    $worktree = Join-Path $temporary 'worktree'
    $null = Invoke-TestGit @('-C', $script:YafpRoot, 'worktree', 'add', '--quiet', '-b', 'startup-worktree', $worktree, "origin/$initialBranch")
    $script:YafpRoot = $worktree
    Start-TestCheck
    $sample = $script:YafpUpdateSample
    if ($sample.State -ne 'ok' -or $sample.Behind -ne 0) { throw 'Tracking worktree was not checked' }
    if ((Complete-TestCheck) -notmatch 'REPOSITORY UP TO DATE') { throw 'Missing worktree status' }
    $first = (@(Invoke-YafpStartupUpdate -Interactive $true 6>&1) | ForEach-Object { "$_" }) -join ''
    $second = (@(Invoke-YafpStartupUpdate -Interactive $true 6>&1) | ForEach-Object { "$_" }) -join ''
    if ($first -notmatch 'YAFP startup check:' -or $second -ne '') { throw 'Startup must check once per session' }
    $env:YAFP_UPDATE_CHECK = '0'
    Start-YafpUpdateCheck -Interactive $true
    if ($null -ne $script:YafpUpdateSample) { throw 'Disabled check launched a worker' }
    Write-Output 'ok - PowerShell startup update consent, reload, synchronous checks and once-per-session loading, and remote/divergent/stale/detached states'
}
finally {
    $env:YAFP_UPDATE_CHECK = $previousUpdateSetting
    # The resolved temporary workspace is the only recursive removal target.
    $resolved = [IO.Path]::GetFullPath($temporary)
    if ([IO.Path]::GetDirectoryName($resolved) -eq [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
