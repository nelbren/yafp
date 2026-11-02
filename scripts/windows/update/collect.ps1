# Synchronous, bounded startup check; pulls require explicit consent.
param([string]$Root, [bool]$Pull = $false)
$ErrorActionPreference = 'Stop'
$repositoryRoot = $Root
function Invoke-UpdateGit {
    param([string[]]$Arguments)
    $command = Get-Command git -CommandType Application -ErrorAction Stop | Select-Object -First 1
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $command.Source
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.Environment['GIT_TERMINAL_PROMPT'] = '0'
    $start.Environment['GIT_ASKPASS'] = 'false'
    $start.Environment['SSH_ASKPASS'] = 'false'
    $ssh = if ($env:GIT_SSH_COMMAND) { $env:GIT_SSH_COMMAND } else { 'ssh' }
    $start.Environment['GIT_SSH_COMMAND'] = "$ssh -oBatchMode=yes -oConnectTimeout=10"
    foreach ($argument in (@('-C', $repositoryRoot, '-c', 'credential.interactive=never') + $Arguments)) {
        $start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $started = $false
    try {
        $null = $process.Start()
        $started = $true
        $process.StandardInput.Close()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(15000)) { throw 'Git timed out' }
        [pscustomobject]@{ Code = $process.ExitCode; Text = $stdout.GetAwaiter().GetResult().Trim() }
        $null = $stderr.GetAwaiter().GetResult()
    }
    finally {
        if ($started -and -not $process.HasExited) { $process.Kill($true) }
        $process.Dispose()
    }
}

$sample = [pscustomobject]@{ State = 'missing-git'; Ahead = 0; Behind = 0; Head = ''; Branch = ''; Upstream = '' }
try {
    if ($Pull) {
        $result = Invoke-UpdateGit @('pull', '--ff-only')
        $sample.State = if ($result.Code -eq 0) { 'updated' } else { 'error' }
        return $sample
    }
    if (-not (Get-Command git -CommandType Application -ErrorAction Ignore)) { return $sample }
    $sample.State = 'not-git'
    if ((Invoke-UpdateGit @('rev-parse', '--is-inside-work-tree')).Code -ne 0) { return $sample }
    $sample.State = 'unborn'
    if ((Invoke-UpdateGit @('rev-parse', '--verify', 'HEAD')).Code -ne 0) { return $sample }
    $sample.State = 'detached'
    $branch = Invoke-UpdateGit @('symbolic-ref', '--quiet', 'HEAD')
    if ($branch.Code -ne 0) { return $sample }
    $sample.State = 'no-upstream'
    $upstream = Invoke-UpdateGit @('rev-parse', '--symbolic-full-name', '@{upstream}')
    if ($branch.Code -ne 0 -or $upstream.Code -ne 0) { return $sample }
    $sample.State = 'no-remote'
    $remote = Invoke-UpdateGit @('config', '--get', "branch.$($branch.Text -replace '^refs/heads/', '').remote")
    if ($remote.Code -ne 0 -or -not $remote.Text -or $remote.Text -eq '.') { return $sample }
    $sample.State = 'error'
    $fetch = Invoke-UpdateGit @('fetch', '--quiet', '--no-tags', '--', $remote.Text)
    if ($fetch.Code -ne 0) { return $sample }
    $head = Invoke-UpdateGit @('rev-parse', '--verify', 'HEAD')
    $behind = Invoke-UpdateGit @('rev-list', '--count', 'HEAD..@{upstream}')
    $ahead = Invoke-UpdateGit @('rev-list', '--count', '@{upstream}..HEAD')
    if ($ahead.Code -eq 0 -and $ahead.Text -match '^\d+$' -and $head.Code -eq 0 -and $behind.Code -eq 0 -and $behind.Text -match '^\d+$') {
        $sample.State = 'ok'
        $sample.Behind = [long]$behind.Text
        $sample.Ahead = [long]$ahead.Text
        $sample.Head = $head.Text
        $sample.Branch = $branch.Text
        $sample.Upstream = $upstream.Text
    }
}
catch { $sample.State = 'error' }
$sample
