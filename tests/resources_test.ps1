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

$global:YAFP_RESOURCE_LABEL_STYLE = 'letters'
$global:YAFP_RESOURCE_VALUE_STYLE = 'percent'
function Get-ResourceDemoBody {
    param([string]$Text)
    $lines = ($Text -replace '\x1b\[[0-?]*[ -/]*[@-~]', '') -split "`n"
    if ($lines[0] -notmatch '^┌─+┐$' -or $lines[1] -notmatch '^│ + yafp-demo-resources +│$' -or
        $lines[2] -notmatch '^├─+┤$' -or $lines[-1] -notmatch '^└─+┘$' -or
        @($lines -match '^┌').Count -ne 1) {
        throw 'Missing resource demo title or single frame'
    }
    $body = foreach ($line in $lines[3..($lines.Count - 2)]) {
        $line.Substring(2, $line.Length - 4).TrimEnd()
    }
    $body -join "`n"
}

$expectedGroups = @()
foreach ($case in @(
    @{ Resource = 'CPU'; Expected = 'C98% R40% S5% D50%' }
    @{ Resource = 'MEMORY'; Expected = 'C20% R98% S5% D50%' }
    @{ Resource = 'SWAP'; Expected = 'C20% R40% S40% D50%' }
    @{ Resource = 'DISK'; Expected = 'C20% R40% S5% D98%' }
)) {
    $demo = (yafp-demo-resources $case.Resource 6>&1 | ForEach-Object { "$_" }) -join "`n"
    $iconColors = [regex]::Matches($demo, '\x1b\[(97|93|91)m') | ForEach-Object { $_.Groups[1].Value }
    $text = Get-ResourceDemoBody -Text $demo
    $expectedGroups += $text
    if (($iconColors -join ',') -ne '97,93,91' -or -not $text.Contains("↦[$($case.Expected)]")) {
        throw "Incorrect demo output: $($case.Resource)"
    }
}
$demoAll = (yafp-demo-resources ALL 6>&1 | ForEach-Object { "$_" }) -join "`n"
$allText = Get-ResourceDemoBody -Text $demoAll
$allColors = [regex]::Matches($demoAll, '\x1b\[(97|93|91)m') | ForEach-Object { $_.Groups[1].Value }
if ($allText -ne ($expectedGroups -join "`n`n") -or ($allColors -join ',') -ne ('97,93,91,' * 4).TrimEnd(',')) {
    throw 'Resource demo ALL must separate all four sets of colors in order'
}
$prefixes = @([regex]::Matches($allText, '(?m)^(CPU|MEMORY|SWAP|DISK) \d+% +(?=)') | ForEach-Object { $_.Value })
if ($prefixes.Count -ne 12 -or @($prefixes | Where-Object Length -NE 12).Count -ne 0) {
    throw 'Resource demo prompt is not aligned'
}
if ($null -ne $script:YafpResourceJob -or $null -ne $script:YafpResourceSample) {
    throw 'Resource demo changed the live sample'
}
Write-Output 'ok - PowerShell resource demo shows three colors without sampling'

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
$script:processReads = 0
function Get-Process {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidOverwritingBuiltInCmdlets', '', Justification = 'Local fixture for both process snapshots.'
    )]
    param([string]$ErrorAction)
    if ($ErrorAction -ne 'Stop') { throw 'The probe must capture errors' }
    $script:processReads++
    $started = [datetime]'2026-01-01'
    $rows = switch ($script:processReads) {
        { $_ -in 1, 2 } {
            @{ Id = 10; Name = 'old'; Cpu = 900 }
            @{ Id = 13; Name = 'medium'; Cpu = 4 }
            @{ Id = 14; Name = 'fast'; Cpu = 1 }
            @{ Id = 15; Name = 'previous'; Cpu = 0 }
            @{ Id = 16; Name = 'busy'; Cpu = 2 }
            @{ Id = 17; Name = 'exiting'; Cpu = 500 }
        }
        3 {
            @{ Id = 0; Name = 'Idle'; Cpu = 500 }
            @{ Id = 10; Name = 'old'; Cpu = 900 }
            @{ Id = 13; Name = 'medium'; Cpu = 4.05 }
            @{ Id = 14; Name = 'fast'; Cpu = 1.3 }
            @{ Id = 15; Name = 'reused'; Cpu = 5; Started = $started.AddSeconds(1) }
            @{ Id = 16; Name = 'busy'; Cpu = 2.1 }
            @{ Id = 18; Name = 'new'; Cpu = 300 }
        }
        default { throw 'Process probe unavailable' }
    }
    foreach ($row in $rows) {
        [pscustomobject]@{
            Id = $row.Id; ProcessName = $row.Name; WorkingSet64 = 1MB
            StartTime = $row['Started'] ?? $started
            TotalProcessorTime = [TimeSpan]::FromSeconds($row.Cpu)
        }
    }
}
$sample = & $script:YafpResourceCollector $HOME $true
if ($sample.RamUsed -ne 12288 -or $sample.RamTotal -ne 16384 -or
    $sample.SwapUsed -ne 1536 -or $sample.SwapTotal -ne 3072 -or $sample.Cpu -ne 25) {
    throw 'Incorrect Windows probes'
}
if ($script:processReads -ne 3 -or ($sample.TopCpuProcesses.Name -join ',') -ne 'fast,busy,medium' -or
    ($sample.TopCpuProcesses.Id -join ',') -ne '14,16,13' -or
    @($sample.TopCpuProcesses | Where-Object CpuPercent -LE 0).Count -gt 0) {
    throw 'Incorrect Windows recent CPU process ranking'
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
if ($null -ne $sample.RamUsed -or $null -ne $sample.SwapUsed -or $null -ne $sample.Cpu -or
    $sample.TopCpuProcesses.Count -ne 0) {
    throw 'A failed probe invented metrics'
}
Remove-Item Function:Get-CimInstance
Remove-Item Function:Get-Process
Write-Output 'ok - Windows probes, summed pagefiles, and partial failures'

foreach ($line in Get-Content (Join-Path $PSScriptRoot 'resource_display_cases.txt')) {
    $kind, $value, $color, $cell = $line.Split('|')
    $number = if ($value -eq '-') { $null } else { [long]$value }
    foreach ($labels in @('letters', 'unicode')) {
        foreach ($values in @('percent', 'symbols')) {
            $global:YAFP_RESOURCE_LABEL_STYLE = $labels
            $global:YAFP_RESOURCE_VALUE_STYLE = $values
            $label = if ($labels -eq 'letters') { $kind }
                else { @{ R = '▦'; S = ''; C = ''; D = '' }[$kind] }
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
    if ($context.Text -ne 'Resources: waiting for sample') { throw 'Pending message must be English and compact' }
    foreach ($labels in @('letters', 'unicode')) {
        foreach ($values in @('percent', 'symbols')) {
            $global:YAFP_RESOURCE_LABEL_STYLE = $labels
            $global:YAFP_RESOURCE_VALUE_STYLE = $values
            $pending = Get-YafpResourceContext
            $expected = if ($labels -eq 'letters') { 'C⟳ R⟳ S⟳ D⟳' }
                elseif ($values -eq 'symbols') { '⟳▦⟳⟳⟳' } else { '⟳ ▦⟳ ⟳ ⟳' }
            $output = (@(Write-YafpResources -Context ([pscustomobject]@{ Resources = $pending }) 6>&1) |
                ForEach-Object { "$_" }) -join ''
            if ($output -ne "↦[$expected]" -or $pending.Suffix -ne '' -or
                @($pending.Segments | Where-Object Foreground -NE 'DarkGray').Count -ne 0) {
                throw "Incorrect pending resource frame: $labels/$values/$output"
            }
        }
    }
    $global:YAFP_RESOURCE_LABEL_STYLE = 'letters'
    $global:YAFP_RESOURCE_VALUE_STYLE = 'percent'
    1..3 | ForEach-Object { $null = Get-YafpResourceContext }
    if ($script:YafpResourceJob.Id -ne $job.Id) { throw 'Duplicate workers' }
    Invoke-YafpReload
    $global:YAFP_RESOURCE_CHECK_INTERVAL = 30
    $global:YAFP_RESOURCE_LABEL_STYLE = 'letters'
    $global:YAFP_RESOURCE_VALUE_STYLE = 'percent'
    $null = Get-YafpResourceContext
    if ($script:YafpResourceJob.Id -ne $job.Id) { throw 'Reload duplicated the worker' }
    $null = Wait-Job -Job $job -Timeout 10
    $context = Get-YafpResourceContext
    if ($context.Text -notmatch '^C25% R50% S50% D75% \d+s$') {
        throw "Incorrect sample: $($context.Text)"
    }
    if ($null -ne $script:YafpResourceJob) { throw 'Completed job was not removed' }
    if ((Get-Job -Id $job.Id -ErrorAction Ignore)) { throw 'Completed job remains registered' }
    if ((Show-YafpResources 6>&1 | Out-String) -notmatch '2/4 GiB') { throw 'Missing details' }
    if ((Format-YafpResourceCapacity 0 @(1024, 3072)) -ne '1/3 MiB' -or
        (Format-YafpResourceCapacity 0 @(599579884, 975664676)) -ne '571.8/930.47 GiB' -or
        (Format-YafpResourceCapacity 0 @(1024, 2147483648)) -ne '<0.01/2 TiB') {
        throw 'Incorrect disk capacity scaling'
    }

    $savedSample = $script:YafpResourceSample; $savedAttempt = $script:YafpResourceAttempt
    $savedLabels = $global:YAFP_RESOURCE_LABEL_STYLE; $savedValues = $global:YAFP_RESOURCE_VALUE_STYLE
    try {
        $script:YafpResourceAttempt = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $global:YAFP_RESOURCE_LABEL_STYLE = 'unicode'; $global:YAFP_RESOURCE_VALUE_STYLE = 'symbols'
        foreach ($line in Get-Content (Join-Path $PSScriptRoot 'resource_report_cases.txt')) {
            $state, $icon, $color = $line.Split('|')
            $global:YAFP_RESOURCE_CHECK_INTERVAL = 30; $script:YafpResourceJob = $null
            $script:YafpResourceSample = [pscustomobject]@{
                CheckedAt = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
                RamUsed = 8192; RamTotal = 16384; SwapUsed = 2048; SwapTotal = 4096
                Cpu = 25; DiskUsed = 750; DiskTotal = 1000
            }
            if ($state -in @('refreshing', 'pending')) { $script:YafpResourceJob = [pscustomobject]@{ State = 'Running' } }
            if ($state -in @('pending', 'unavailable')) { $script:YafpResourceSample = $null }
            if ($state -eq 'disabled') { $global:YAFP_RESOURCE_CHECK_INTERVAL = 0 }
            $out = (@(Show-YafpResources 6>&1) | ForEach-Object { "$_" }) -join "`n"
            if (-not $out.Contains("$([char]27)[$($color)m$icon $state")) { throw "Resource report state severity: $state" }
            $plain = $out -replace '\x1b\[[0-?]*[ -/]*[@-~]', ''
            if (-not $plain.Contains('┌') -or -not $plain.Contains('┘') -or
                -not $plain.Contains("        State: $icon $state")) { throw "Resource report framing/state: $state" }
            if ($state -in @('ok', 'refreshing')) {
                foreach ($text in @('          CPU: 25%', '          RAM: 50% · 8/16 GiB',
                    '         SWAP: 50% · 2/4 GiB', '  Disk (HOME): 75% · 750/1000 KiB')) {
                    if (-not $plain.Contains($text)) { throw "Resource report details missing: $text" }
                }
                if (-not $out.Contains("$([char]27)[91m50% · 2/4 GiB")) { throw 'Swap critical color changed' }
                if ($plain.Contains('')) { throw 'A sample without TopProcesses showed process details' }
            }
            elseif (-not $plain.Contains('   Sample age: ') -or -not $plain.Contains('          RAM: ') -or
                $plain.Contains('8/16 GiB')) {
                throw 'Unavailable resource report reused old data'
            }
        }
        $global:YAFP_RESOURCE_CHECK_INTERVAL = 30; $script:YafpResourceJob = $null
        $script:YafpResourceSample = [pscustomobject]@{
            CheckedAt = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            RamUsed = 8192; RamTotal = 16384; SwapUsed = 2048; SwapTotal = 4096
            Cpu = 25; DiskUsed = 750; DiskTotal = 1000
            TopProcesses = @(
                [pscustomobject]@{ Name = 'process-a'; RamMiB = 1536; Id = 123 }
                [pscustomobject]@{ Name = 'process-b'; RamMiB = 256; Id = 456 }
                [pscustomobject]@{ Name = 'process-c'; RamMiB = 128; Id = 789 }
            )
            TopCpuProcesses = @(
                [pscustomobject]@{ Name = 'cpu-a'; CpuPercent = 120; Id = 321 }
                [pscustomobject]@{ Name = 'cpu-b'; CpuPercent = 105; Id = 654 }
                [pscustomobject]@{ Name = 'cpu-c'; CpuPercent = 101; Id = 987 }
            )
        }
        foreach ($case in @(
            @{ SwapUsed = 2048; Cpu = 98; Color = 91 }
            @{ SwapUsed = 1024; Cpu = 90; Color = 93 }
            @{ SwapUsed = 0; Cpu = 25; Color = 92 }
            @{ SwapUsed = $null; Cpu = $null; Color = 90 }
        )) {
            $script:YafpResourceSample.SwapUsed = $case.SwapUsed
            $script:YafpResourceSample.Cpu = $case.Cpu
            $out = (@(& 'yafp-resources' 6>&1) | ForEach-Object { "$_" }) -join "`n"
            if ($out -match '|Start-Process|Stop-Process') { throw 'Resource report showed termination commands' }
            if (($out -replace '\x1b\[[0-?]*[ -/]*[@-~]', '') -notmatch '(?s)│ + yafp-resources +│\r?\n├─+┤.*\S │(?:\r?\n|$)') {
                throw 'Resource frame omitted its title or did not fit its longest row'
            }
            if ($out -notmatch '(?s)CPU:.*cpu-a.*cpu-b.*cpu-c.*RAM:.*SWAP:.*process-a.*process-b.*process-c') {
                throw 'CPU and SWAP process groups are out of order'
            }
            foreach ($process in $script:YafpResourceSample.TopCpuProcesses) {
                if (-not $out.Contains("$([char]27)[$($case.Color)m$($process.CpuPercent)%")) {
                    throw "Missing $($process.Name) CPU usage with CPU color $($case.Color)"
                }
            }
            foreach ($process in $script:YafpResourceSample.TopProcesses) {
                $size = if ($process.RamMiB -eq 1536) { '1.5 GiB' } else { "$($process.RamMiB) MiB" }
                if (-not $out.Contains($process.Name) -or
                    -not $out.Contains("$([char]27)[$($case.Color)m$size")) {
                    throw "Missing $($process.Name) or its RAM size with swap color $($case.Color)"
                }
            }
        }
        $out = (@(& 'yafp-resources-fix' 6>&1) | ForEach-Object { "$_" }) -join "`n"
        if (-not $out.Contains("$([char]27)[91m")) { throw 'Fix report omitted the red skull' }
        $plain = $out -replace '\x1b\[[0-?]*[ -/]*[@-~]', ''
        if ($plain -notmatch '(?s)│ + yafp-resources-fix +│\r?\n├─+┤.*\S │(?:\r?\n|$)') {
            throw 'Fix frame omitted its title or did not fit its longest row'
        }
        $plain = $plain -replace ' │\r?\n│ ', ''
        foreach ($processId in @(321, 654, 987, 123, 456, 789)) {
            $command = "Start-Process pwsh -Verb RunAs -ArgumentList '-NoProfile -Command `"Stop-Process -Id $processId -Force`"'"
            if (-not $plain.Contains($command)) { throw "Fix report omitted the command for process $processId" }
        }
        $script:YafpResourceSample = [pscustomobject]@{
            CheckedAt = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            RamUsed = $null; RamTotal = 16384; SwapUsed = 0; SwapTotal = 0
            Cpu = $null; DiskUsed = $null; DiskTotal = 1000
        }
        $out = (@(Show-YafpResources 6>&1) | ForEach-Object { "$_" }) -join "`n"
        $plain = $out -replace '\x1b\[[0-?]*[ -/]*[@-~]', ''
        foreach ($text in @('          CPU: ', '          RAM:  · /16 GiB',
            '         SWAP: 0% · 0/0 MiB', '  Disk (HOME):  · /1000 KiB')) {
            if (-not $plain.Contains($text)) { throw "Partial resource report missing: $text" }
        }
    }
    finally {
        $script:YafpResourceSample = $savedSample; $script:YafpResourceAttempt = $savedAttempt
        $global:YAFP_RESOURCE_LABEL_STYLE = $savedLabels; $global:YAFP_RESOURCE_VALUE_STYLE = $savedValues
        $script:YafpResourceJob = $null; $global:YAFP_RESOURCE_CHECK_INTERVAL = 30
    }

    $script:YafpResourceJob = Start-ThreadJob -ScriptBlock { Start-Sleep -Seconds 1 }
    $refreshJob = $script:YafpResourceJob
    $context = Get-YafpResourceContext
    if ($context.Text -notmatch 's$' -or $context.Text.Contains(' ') -or $context.Suffix.Contains(' ')) {
        throw 'Cached refresh must attach the refresh icon to sample age'
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
            @{ Labels = 'unicode'; Values = 'percent'; Text = '25% ▦50% 50% 75%' }
            @{ Labels = 'letters'; Values = 'symbols'; Text = 'C⣄ R⣦ S⣦ D⣷' }
            @{ Labels = 'unicode'; Values = 'symbols'; Text = '⣄▦⣦⣦⣷' }
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
        foreach ($theme in @('minimal', 'light')) {
            $global:YAFP_THEME = $theme
            Import-YafpTheme
            $script:resourceWrites.Clear()
            $null = prompt 6>$null
            $icon = $script:resourceWrites | Where-Object Text -EQ '' | Select-Object -First 1
            if ($null -eq $icon -or $icon.Color -ne 'Red' -or $null -ne $icon.Background) {
                throw "OS icon did not reflect the red swap sample: $theme"
            }
        }
        foreach ($case in @(
            @{ Colors = @('Red', 'Green', 'Yellow', 'Green'); Expected = 'Red' }
            @{ Colors = @('Green', 'Yellow', 'Green', 'Green'); Expected = 'Yellow' }
            @{ Colors = @('Green', 'Green', 'Green', 'Green'); Expected = 'White' }
            @{ Colors = @('DarkGray', 'DarkGray', 'DarkGray', 'DarkGray'); Expected = 'White' }
            @{ Colors = @(); Expected = 'White' }
        )) {
            $segments = @(foreach ($color in $case.Colors) { [pscustomobject]@{ Foreground = $color } })
            $resource = if ($segments.Count -gt 0) { [pscustomobject]@{ Segments = $segments } }
            $script:resourceWrites.Clear()
            Write-YafpOsIcon -Context ([pscustomobject]@{ Resources = $resource })
            $icon = $script:resourceWrites[0]
            if ($icon.Text -ne '' -or $icon.Color -ne $case.Expected -or $null -ne $icon.Background) {
                throw "Incorrect OS icon severity: $($case.Colors -join ',')"
            }
        }
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
                        $resource.Suffix += ''
                        $resource.Text += ''
                        $script:resourceWrites.Clear()
                        Write-YafpResources -Context ([pscustomobject]@{ Resources = $resource })
                        if (($script:resourceWrites.Text -join '') -ne "↦[${tokens}]") {
                            throw "Space before refresh marker: $theme/$labels/$values"
                        }
                        $marker = $script:resourceWrites[5]
                        if ($marker.Text -ne '' -or $marker.Color -ne 'DarkGray' -or
                            $null -ne $marker.Background -or -not $marker.NoNewline) {
                            throw 'Refresh icon must stay gray, transparent, and on the same line'
                        }
                    }
                }
            }
        }
        $global:YAFP_RESOURCE_CHECK_INTERVAL = 0
        $script:resourceWrites.Clear()
        Write-YafpResources -Context ([pscustomobject]@{ Resources = (Get-YafpResourceContext) })
        if ($script:resourceWrites.Count -ne 0) { throw 'Empty frame while monitoring is disabled' }
        if ((Show-YafpResources 6>&1 | Out-String) -notmatch [regex]::Escape('Resources disabled. Set $global:YAFP_RESOURCE_CHECK_INTERVAL=30.')) {
            throw 'Disabled message must be English'
        }
        $global:YAFP_RESOURCE_CHECK_INTERVAL = 30
    }
    finally { Set-Item Function:Write-YafpText -Value $originalWriter }
    $script:YafpResourceSample = $null
    $script:YafpResourceAttempt = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    foreach ($theme in @('default', 'minimal', 'light')) {
        $global:YAFP_THEME = $theme
        Import-YafpTheme
        foreach ($labels in @('letters', 'unicode')) {
            foreach ($values in @('percent', 'symbols')) {
                $global:YAFP_RESOURCE_LABEL_STYLE = $labels
                $global:YAFP_RESOURCE_VALUE_STYLE = $values
                $context = Get-YafpResourceContext
                $expected = if ($labels -eq 'letters') { 'C R S D' }
                    elseif ($values -eq 'symbols') { '▦' } else { ' ▦  ' }
                $output = (@(Write-YafpResources -Context ([pscustomobject]@{ Resources = $context }) 6>&1) |
                    ForEach-Object { "$_" }) -join ''
                if ($output -ne "↦[$expected]" -or $context.State -ne 'unavailable' -or
                    $context.Suffix -ne '' -or @($context.Segments | Where-Object Foreground -NE 'Red').Count -ne 0) {
                    throw "Incorrect unavailable resource frame: $theme/$labels/$values/$output"
                }
            }
        }
    }
    $global:YAFP_RESOURCE_LABEL_STYLE = 'letters'
    $global:YAFP_RESOURCE_VALUE_STYLE = 'percent'
    $script:YafpResourceSample = [pscustomobject]@{
        CheckedAt = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - 60
        RamUsed = $null; RamTotal = $null; SwapUsed = 0; SwapTotal = 0
        Cpu = $null; DiskUsed = $null; DiskTotal = $null
    }
    $context = Get-YafpResourceContext
    if ($context.Text -notmatch '^C R S0% D 60s$') {
        throw 'Incorrect missing-metric fallback or sample age'
    }
    $script:YafpResourceSample.SwapUsed = 1552
    $script:YafpResourceSample.SwapTotal = 3072
    if ((Get-YafpResourceContext).Text -notmatch ' S50% ') {
        throw 'Incorrect integer swap percentage'
    }
    $script:YafpResourceSample.SwapTotal = $null
    if ((Get-YafpResourceContext).Text -notmatch ' S ') {
        throw 'Missing swap capacity must display '
    }
    Write-Output 'ok - single nonblocking PowerShell worker, reload, three themes, and previous status'
}
finally {
    if ($null -ne $script:YafpResourceJob) {
        Remove-Job -Job $script:YafpResourceJob -Force -ErrorAction Ignore
    }
}
