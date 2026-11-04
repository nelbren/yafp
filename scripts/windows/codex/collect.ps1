# This file runs only inside the background job. Never return account identifiers.
param([int]$TimeoutMilliseconds = 10000, [hashtable]$Control = $null, [long]$Attempt = 0)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Off
$sample = [pscustomobject]@{
    CheckedAt = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    State = 'unavailable'; Remaining = $null; Primary = $null; Secondary = $null; ResetsAt = $null
    Diagnostic = $null
}
$process = $null
$timer = [Diagnostics.Stopwatch]::StartNew()
$attemptAt = if ($Attempt -gt 0) { $Attempt } else { $sample.CheckedAt }
$diagnostic = @{ Stage = 'locate-cli'; Reason = 'in-progress'; ServerPid = 0 }
function Publish-YafpCodexDiagnostic {
    $snapshot = [pscustomobject]@{
        CheckedAt = $attemptAt
        Stage = $diagnostic.Stage; Reason = $diagnostic.Reason
        Duration = $timer.ElapsedMilliseconds; ServerPid = $diagnostic.ServerPid
    }
    $sample.Diagnostic = $snapshot
    if ($null -ne $Control) { $Control.Diagnostic = $snapshot }
}
try {
    Publish-YafpCodexDiagnostic
    if ($null -ne $Control -and $Control.Cancelled) {
        $diagnostic.Reason = 'cancelled'; return $sample
    }
    $command = Get-Command codex -CommandType Application -ErrorAction Ignore | Select-Object -First 1
    if ($null -eq $command) {
        $diagnostic.Reason = 'missing-cli'; $sample.State = 'missing-cli'; return $sample
    }
    $diagnostic.Stage = 'start-server'
    Publish-YafpCodexDiagnostic
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
    $diagnostic.ServerPid = $process.Id
    if ($null -ne $Control) {
        $Control.Process = $process
        if ($Control.Cancelled) { $diagnostic.Reason = 'cancelled'; throw 'Worker cancelled' }
    }
    # Drain stderr without logging it or letting a full pipe block the server.
    $stderr = $process.StandardError.ReadToEndAsync()
    $deadline = [Environment]::TickCount64 + $TimeoutMilliseconds
    function Read-YafpCodexResponse {
        param([int]$Identifier, [string]$Method, [object]$Parameters)
        $diagnostic.Stage = $Method
        Publish-YafpCodexDiagnostic
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
            if ($null -eq $line) { $diagnostic.Reason = 'server-closed'; throw 'App server closed' }
            try { $message = ConvertFrom-Json -InputObject $line -AsHashtable }
            catch { continue }
            if ($message -is [System.Collections.IDictionary] -and $message.id -eq $Identifier) {
                if ($message.Contains('error')) {
                    $diagnostic.Reason = 'rpc-error'
                    throw 'App server request failed'
                }
                if ($message.result -isnot [System.Collections.IDictionary]) {
                    $diagnostic.Reason = 'invalid-response'; throw 'Invalid app server response'
                }
                return $message.result
            }
        }
    }
    $null = Read-YafpCodexResponse 1 'initialize' @{ clientInfo = @{ name = 'yafp'; version = '1' } }
    $process.StandardInput.WriteLine('{"method":"initialized"}')
    $process.StandardInput.Flush()
    $account = (Read-YafpCodexResponse 2 'account/read' @{ refreshToken = $false }).account
    if ($null -eq $account) {
        $diagnostic.Reason = 'logged-out'; $sample.State = 'logged-out'; return $sample
    }
    if ($account.type -ne 'chatgpt') {
        $diagnostic.Reason = 'unsupported-auth'; $sample.State = 'unsupported-auth'; return $sample
    }
    $result = Read-YafpCodexResponse 3 'account/rateLimits/read' $null
    $diagnostic.Stage = 'parse-limits'
    Publish-YafpCodexDiagnostic
    $diagnostic.Reason = 'no-valid-limits'
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
        $diagnostic.Reason = 'ok'
    }
}
catch [TimeoutException] { $diagnostic.Reason = 'timeout'; $sample.State = 'timeout' }
catch {
    if ($diagnostic.Reason -eq 'in-progress') {
        $diagnostic.Reason = if ($diagnostic.Stage -eq 'start-server') { 'server-start-failed' } else { 'io-error' }
    }
    $sample.State = 'unavailable'
}
finally {
    if ($null -ne $process) {
        try {
            if (-not $process.HasExited) { $process.Kill($true) }
            $null = $process.WaitForExit(1000)
            $null = $stderr
        }
        catch {
            if ($diagnostic.ServerPid -gt 0) { $diagnostic.Reason = 'cleanup-failed' }
            $sample.State = 'unavailable'
        }
        $process.Dispose()
    }
    if ($null -ne $Control) { $Control.Process = $null }
    Publish-YafpCodexDiagnostic
}
$sample
