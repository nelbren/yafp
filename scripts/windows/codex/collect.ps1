# This file runs only inside the background job. Never return account identifiers.
param([int]$TimeoutMilliseconds = 10000, [hashtable]$Control = $null)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Off
$sample = [pscustomobject]@{
    CheckedAt = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    State = 'unavailable'; Remaining = $null; Primary = $null; Secondary = $null; ResetsAt = $null
}
$process = $null
try {
    if ($null -ne $Control -and $Control.Cancelled) { return $sample }
    $command = Get-Command codex -CommandType Application -ErrorAction Ignore | Select-Object -First 1
    if ($null -eq $command) { $sample.State = 'missing-cli'; return $sample }
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $command.Source
    $start.ArgumentList.Add('app-server')
    # npm installs a .cmd launcher on Windows; native binaries run directly.
    if ($IsWindows -and [IO.Path]::GetExtension($command.Source) -in @('.cmd', '.bat')) {
        $start.FileName = $env:ComSpec
        $start.ArgumentList.Clear()
        $start.Arguments = '/d /s /c ""' + $command.Source + '" app-server"'
    }
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $null = $process.Start()
    if ($null -ne $Control) {
        $Control.Process = $process
        if ($Control.Cancelled) { throw 'Worker cancelled' }
    }
    # Drain stderr without logging it or letting a full pipe block the server.
    $stderr = $process.StandardError.ReadToEndAsync()
    $deadline = [Environment]::TickCount64 + $TimeoutMilliseconds
    function Read-YafpCodexResponse {
        param([int]$Identifier, [string]$Method, [object]$Parameters)
        $request = @{ id = $Identifier; method = $Method }
        if ($null -ne $Parameters) { $request.params = $Parameters }
        $process.StandardInput.WriteLine(($request | ConvertTo-Json -Compress -Depth 8))
        $process.StandardInput.Flush()
        while ($true) {
            $remaining = [int]($deadline - [Environment]::TickCount64)
            if ($remaining -le 0) { throw [TimeoutException]::new() }
            $lineTask = $process.StandardOutput.ReadLineAsync()
            if (-not $lineTask.Wait($remaining)) { throw [TimeoutException]::new() }
            $line = $lineTask.GetAwaiter().GetResult()
            if ($null -eq $line) { throw 'App server closed' }
            try { $message = ConvertFrom-Json -InputObject $line -AsHashtable }
            catch { continue }
            if ($message -is [System.Collections.IDictionary] -and $message.id -eq $Identifier) {
                if ($message.Contains('error') -or $message.result -isnot [System.Collections.IDictionary]) {
                    throw 'App server request failed'
                }
                return $message.result
            }
        }
    }
    $null = Read-YafpCodexResponse 1 'initialize' @{ clientInfo = @{ name = 'yafp'; version = '1' } }
    $process.StandardInput.WriteLine('{"method":"initialized"}')
    $process.StandardInput.Flush()
    $account = (Read-YafpCodexResponse 2 'account/read' @{ refreshToken = $false }).account
    if ($null -eq $account) { $sample.State = 'logged-out'; return $sample }
    if ($account.type -ne 'chatgpt') { $sample.State = 'unsupported-auth'; return $sample }
    $result = Read-YafpCodexResponse 3 'account/rateLimits/read' $null
    $limits = $result.rateLimits
    if ($result.rateLimitsByLimitId -is [System.Collections.IDictionary] -and
        $result.rateLimitsByLimitId.Contains('codex')) {
        $limits = $result.rateLimitsByLimitId.codex
    }
    if ($limits -isnot [System.Collections.IDictionary] -or
        ($null -ne $limits.limitId -and $limits.limitId -ne 'codex')) { return $sample }
    $resetTimes = @{}
    foreach ($window in @(@('primary', 'Primary'), @('secondary', 'Secondary'))) {
        $used = $limits[$window[0]].usedPercent
        if (($used -is [long] -or $used -is [int] -or $used -is [double] -or $used -is [decimal]) -and
            -not [double]::IsNaN($used) -and $used -ge 0 -and $used -le 100) {
            $sample.($window[1]) = [int][Math]::Floor(100 - $used)
            $reset = $limits[$window[0]].resetsAt
            if (($reset -is [long] -or $reset -is [int]) -and $reset -gt 0 -and $reset -le 9999999999) {
                $resetTimes[$window[1]] = [long]$reset
            }
        }
    }
    $available = @($sample.Primary, $sample.Secondary | Where-Object { $null -ne $_ })
    if ($available.Count -gt 0) {
        $sample.Remaining = ($available | Measure-Object -Minimum).Minimum
        $selected = if ($sample.Primary -eq $sample.Remaining) { 'Primary' } else { 'Secondary' }
        $sample.ResetsAt = $resetTimes[$selected]
        $sample.State = 'ok'
    }
}
catch [TimeoutException] { $sample.State = 'timeout' }
catch { $sample.State = 'unavailable' }
finally {
    if ($null -ne $process) {
        try {
            if (-not $process.HasExited) { $process.Kill($true) }
            $null = $process.WaitForExit(1000)
            $null = $stderr
        }
        catch { $sample.State = 'unavailable' }
        $process.Dispose()
    }
    if ($null -ne $Control) { $Control.Process = $null }
}
$sample
