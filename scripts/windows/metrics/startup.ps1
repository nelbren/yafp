# Record startup once and asynchronously; this does not run inside prompt.
function Register-YafpStartup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][bool]$Interactive
    )
    if (-not $Interactive -or $env:YAFP_METRICS_DISABLED -eq '1') { return }
    $previous = Get-Variable YafpStartupMetricsProcessId -Scope Global -ErrorAction Ignore
    if ($previous -and $previous.Value -eq $PID) { return }
    $tools = if ($env:AI_DEV_TOOLS_ROOT) { $env:AI_DEV_TOOLS_ROOT } else { Join-Path $HOME 'ai-dev-tools' }
    $relativePython = if ($IsWindows) { '.venv/Scripts/python.exe' } else { '.venv/bin/python' }
    $python = Join-Path $tools $relativePython
    $recorder = Join-Path $tools 'bin/application-startup'
    if (-not (Test-Path -LiteralPath $python -PathType Leaf) -or
        -not (Test-Path -LiteralPath $recorder -PathType Leaf)) { return }
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $python
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    foreach ($argument in @($recorder, '--path', $Root, '--shell', 'powershell')) {
        $start.ArgumentList.Add($argument)
    }
    try {
        $process = [Diagnostics.Process]::Start($start)
        $global:YafpStartupMetricsProcessId = $PID
        $process.Dispose()
    }
    catch {
        # The prompt keeps working; Software Facts retains the missing measurement.
        Write-Verbose "No se pudo iniciar el registro local de YAFP: $_"
    }
}
