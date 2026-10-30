$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$env:YAFP_METRICS_DISABLED = '1'
$env:COMPUTERNAME = 'yafp-test'
$env:USERNAME = 'yafp-test'
. (Join-Path $PSScriptRoot '../yafp-ps.ps1')

foreach ($interval in @('0', '-1', 'bad', '9999999999999999999')) {
    $global:YAFP_RESOURCE_CHECK_INTERVAL = $interval
    if ($null -ne (Get-YafpResourceContext)) { throw 'Invalid interval accepted' }
    if ($null -ne $script:YafpResourceJob) { throw 'Disabled monitoring created a worker' }
}
Write-Output 'ok - disabled or invalid PowerShell resource monitoring starts no workers'

function Get-CimInstance {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidOverwritingBuiltInCmdlets', '',
        Justification = 'Local fixture: replace CIM to validate Windows on any OS.'
    )]
    param([string]$ClassName, [string]$Filter, [string]$ErrorAction)
    if ($ErrorAction -ne 'Stop') { throw 'The probe must capture errors' }
    switch ($ClassName) {
        Win32_OperatingSystem {
            [pscustomobject]@{ TotalVisibleMemorySize = 16777216; FreePhysicalMemory = 4194304 }
        }
        Win32_PageFileUsage {
            [pscustomobject]@{ CurrentUsage = 1024; AllocatedBaseSize = 2048 }
            [pscustomobject]@{ CurrentUsage = 512; AllocatedBaseSize = 1024 }
        }
        Win32_PerfFormattedData_PerfOS_Processor {
            if ($Filter -ne "Name='_Total'") { throw 'Missing total CPU counter' }
            [pscustomobject]@{ PercentProcessorTime = 25 }
        }
    }
}
$sample = & $script:YafpResourceCollector $HOME $true
if ($sample.RamUsed -ne 12288 -or $sample.RamTotal -ne 16384 -or
    $sample.SwapUsed -ne 1536 -or $sample.SwapTotal -ne 3072 -or $sample.Cpu -ne 25) {
    throw 'Incorrect Windows probes'
}
function Get-CimInstance {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidOverwritingBuiltInCmdlets', '',
        Justification = 'Local failure fixture: no real CIM queries are made.'
    )]
    param()
    throw 'Probe unavailable'
}
$sample = & $script:YafpResourceCollector $HOME $true
if ($null -ne $sample.RamUsed -or $null -ne $sample.SwapUsed -or $null -ne $sample.Cpu) {
    throw 'A failed probe invented metrics'
}
Remove-Item Function:Get-CimInstance
Write-Output 'ok - Windows probes, summed pagefiles, and partial failures'

foreach ($line in Get-Content (Join-Path $PSScriptRoot 'resource_display_cases.txt')) {
    $kind, $value, $color, $cell = $line.Split('|')
    $number = if ($value -eq '-') { $null } else { [long]$value }
    foreach ($labels in @('letters', 'unicode')) {
        foreach ($values in @('percent', 'symbols')) {
            $global:YAFP_RESOURCE_LABEL_STYLE = $labels
            $global:YAFP_RESOURCE_VALUE_STYLE = $values
            $label = if ($labels -eq 'letters') { $kind }
                else { @{ R = '▦'; S = '⇄'; C = '⚙'; D = '◉' }[$kind] }
            $expected = if ($values -eq 'percent' -and $null -ne $number) { "$label$value%" }
                else { "$label$cell" }
            $segment = Format-YafpResourceSegment -Kind $kind -Value $number
            if ($segment.Text -ne $expected -or $segment.Foreground -ne $color) {
                throw "Incorrect test case: $line/$labels/$values"
            }
        }
    }
}
$global:YAFP_RESOURCE_LABEL_STYLE = 'bad'
$global:YAFP_RESOURCE_VALUE_STYLE = 'bad'
if ((Format-YafpResourceSegment -Kind R -Value 74).Text -ne 'R74%') {
    throw 'Incorrect invalid-style fallback'
}
$global:YAFP_RESOURCE_LABEL_STYLE = 'letters'
$global:YAFP_RESOURCE_VALUE_STYLE = 'percent'
Write-Output 'ok - PowerShell labels, Braille, and shared color boundaries'

$script:YafpResourceCollector = {
    Start-Sleep -Seconds 1
    [pscustomobject]@{
        CheckedAt = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        RamUsed = 8192; RamTotal = 16384; SwapUsed = 2048; SwapTotal = 4096
        Cpu = 25; DiskUsed = 750; DiskTotal = 1000
    }
}
$global:YAFP_RESOURCE_CHECK_INTERVAL = 30
try {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $context = Get-YafpResourceContext
    $timer.Stop()
    if ($timer.ElapsedMilliseconds -ge 500) { throw 'The worker blocked context collection' }
    $job = $script:YafpResourceJob
    if ($context.Text -notmatch 'waiting for sample') { throw 'Missing pending state' }
    if ($context.Text -ne 'Resources: waiting for sample~') { throw 'Pending message must be English and compact' }
    1..3 | ForEach-Object { $null = Get-YafpResourceContext }
    if ($script:YafpResourceJob.Id -ne $job.Id) { throw 'Duplicate workers' }
    Invoke-YafpReload
    $global:YAFP_RESOURCE_CHECK_INTERVAL = 30
    $null = Get-YafpResourceContext
    if ($script:YafpResourceJob.Id -ne $job.Id) { throw 'Reload duplicated the worker' }
    $null = Wait-Job -Job $job -Timeout 10
    $context = Get-YafpResourceContext
    if ($context.Text -notmatch '^C25% R50% S50% D75% \d+s$') {
        throw "Incorrect sample: $($context.Text)"
    }
    if ($null -ne $script:YafpResourceJob) { throw 'Completed job was not removed' }
    if ((Get-Job -Id $job.Id -ErrorAction Ignore)) { throw 'Completed job remains registered' }
    if ((Show-YafpResources | Out-String) -notmatch '2048/4096 MiB') { throw 'Missing details' }

    $script:YafpResourceJob = Start-ThreadJob -ScriptBlock { Start-Sleep -Seconds 1 }
    $refreshJob = $script:YafpResourceJob
    $context = Get-YafpResourceContext
    if ($context.Text -notmatch 's~$' -or $context.Text.Contains(' ~') -or $context.Suffix.Contains(' ~')) {
        throw 'Cached refresh must attach the tilde to sample age'
    }
    $null = Wait-Job $refreshJob -Timeout 5
    $null = Get-YafpResourceContext

    # The hot path neither starts another job nor queries the probes again.
    function Start-ThreadJob { throw 'Another job started before the interval expired' }
    $null = Get-YafpResourceContext
    Remove-Item Function:Start-ThreadJob
    $global:YAFP_REPOS = 0
    $global:YAFP_PVENV = 0
    $global:YAFP_OSC133 = 0
    $global:YAFP_CLOCK = 0
    $global:YAFP_ERROR = 0
    function Test-YafpAdministrator { return $false }
    foreach ($theme in @('default', 'minimal', 'light')) {
        $global:YAFP_THEME = $theme
        Import-YafpTheme
        foreach ($case in @(
            @{ Labels = 'letters'; Values = 'percent'; Text = 'C25% R50% S50% D75%' }
            @{ Labels = 'unicode'; Values = 'percent'; Text = '⚙25% ▦50% ⇄50% ◉75%' }
            @{ Labels = 'letters'; Values = 'symbols'; Text = 'C⣄ R⣦ S⣦ D⣷' }
            @{ Labels = 'unicode'; Values = 'symbols'; Text = '⚙⣄▦⣦⇄⣦◉⣷' }
        )) {
            $global:YAFP_RESOURCE_LABEL_STYLE = $case.Labels
            $global:YAFP_RESOURCE_VALUE_STYLE = $case.Values
            $global:LASTEXITCODE = 7
            $output = (@(prompt 6>&1) | ForEach-Object { "$_" }) -join ''
            $block = "↦[$($case.Text)]"
            if (-not $output.Contains("$env:COMPUTERNAME$block")) {
                throw "Missing sample in theme $theme/$($case.Labels)/$($case.Values)"
            }
            if ([regex]::Matches($output, [regex]::Escape($block)).Count -ne 1) {
                throw 'Duplicate resources'
            }
            if ($global:LASTEXITCODE -ne 7) { throw 'Previous exit code changed' }
        }
    }
    $global:YAFP_RESOURCE_LABEL_STYLE = 'letters'
    $global:YAFP_RESOURCE_VALUE_STYLE = 'percent'
    $resource = Get-YafpResourceContext
    $originalWriter = (Get-Command Write-YafpText).ScriptBlock
    $script:resourceWrites = [Collections.Generic.List[object]]::new()
    function Write-YafpText {
        param([string]$Text, [string]$ForegroundColor, [object]$BackgroundColor, [switch]$NoNewline)
        $script:resourceWrites.Add([pscustomobject]@{
            Text = $Text; Color = $ForegroundColor; Background = $BackgroundColor; NoNewline = $NoNewline
        })
    }
    try {
        foreach ($dark in @(0, 1)) {
            $global:YAFP_DARKC = $dark
            foreach ($theme in @('default', 'minimal', 'light')) {
                $global:YAFP_THEME = $theme
                Import-YafpTheme
                $frameForeground = if ($theme -eq 'default') { $script:grayColorForeground } else { 'White' }
                $frameBackground = if ($theme -eq 'default') { $script:grayColorBackground } else { $null }
                foreach ($labels in @('letters', 'unicode')) {
                    foreach ($values in @('percent', 'symbols')) {
                        $global:YAFP_RESOURCE_LABEL_STYLE = $labels
                        $global:YAFP_RESOURCE_VALUE_STYLE = $values
                        $resource = Get-YafpResourceContext
                        $script:resourceWrites.Clear()
                        Write-YafpResources -Context ([pscustomobject]@{ Resources = $resource })
                        $tokens = $resource.Segments.Text -join $resource.Separator
                        if (($script:resourceWrites.Text -join '') -ne "↦[$tokens]") {
                            throw "Incorrect frame or sample age: $theme/$labels/$values"
                        }
                        if (($script:resourceWrites[1..4].Color -join ',') -ne 'Green,Green,Red,Green') {
                            throw 'Incorrect resource colors'
                        }
                        foreach ($index in @(0, 5)) {
                            $write = $script:resourceWrites[$index]
                            if ($write.Color -ne $frameForeground -or $write.Background -ne $frameBackground -or
                                -not $write.NoNewline) {
                                throw "Incorrect Git frame colors: $theme/$dark"
                            }
                        }
                        foreach ($write in $script:resourceWrites[1..4]) {
                            if ($null -ne $write.Background -or -not $write.NoNewline) {
                                throw 'Resources must use foreground color only and stay on the same line'
                            }
                        }
                        $resource.Suffix += '~'
                        $resource.Text += '~'
                        $script:resourceWrites.Clear()
                        Write-YafpResources -Context ([pscustomobject]@{ Resources = $resource })
                        if (($script:resourceWrites.Text -join '') -ne "↦[${tokens}~]") {
                            throw "Space before refresh marker: $theme/$labels/$values"
                        }
                    }
                }
            }
        }
        $global:YAFP_RESOURCE_CHECK_INTERVAL = 0
        $script:resourceWrites.Clear()
        Write-YafpResources -Context ([pscustomobject]@{ Resources = (Get-YafpResourceContext) })
        if ($script:resourceWrites.Count -ne 0) { throw 'Empty frame while monitoring is disabled' }
        if ((Show-YafpResources) -ne 'Resources disabled. Set $global:YAFP_RESOURCE_CHECK_INTERVAL=30.') {
            throw 'Disabled message must be English'
        }
        $global:YAFP_RESOURCE_CHECK_INTERVAL = 30
    }
    finally { Set-Item Function:Write-YafpText -Value $originalWriter }
    $global:YAFP_RESOURCE_LABEL_STYLE = 'letters'
    $global:YAFP_RESOURCE_VALUE_STYLE = 'percent'
    $script:YafpResourceSample = [pscustomobject]@{
        CheckedAt = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - 60
        RamUsed = $null; RamTotal = $null; SwapUsed = 0; SwapTotal = 0
        Cpu = $null; DiskUsed = $null; DiskTotal = $null
    }
    $context = Get-YafpResourceContext
    if ($context.Text -notmatch '^CN/A RN/A S0% DN/A 60s$') {
        throw 'Incorrect missing-metric fallback or sample age'
    }
    $script:YafpResourceSample.SwapUsed = 1552
    $script:YafpResourceSample.SwapTotal = 3072
    if ((Get-YafpResourceContext).Text -notmatch ' S50% ') {
        throw 'Incorrect integer swap percentage'
    }
    $script:YafpResourceSample.SwapTotal = $null
    if ((Get-YafpResourceContext).Text -notmatch ' SN/A ') {
        throw 'Missing swap capacity must display N/A'
    }
    Write-Output 'ok - single nonblocking PowerShell worker, reload, three themes, and previous status'
}
finally {
    if ($null -ne $script:YafpResourceJob) {
        Remove-Job -Job $script:YafpResourceJob -Force -ErrorAction Ignore
    }
}
