# Local context and sampling. The worker runs in a PowerShell 7 thread.
if (-not (Get-Variable YAFP_RESOURCE_CHECK_INTERVAL -Scope Global -ErrorAction Ignore)) {
    $global:YAFP_RESOURCE_CHECK_INTERVAL = 0
}
foreach ($option in @{
    YAFP_RESOURCE_LABEL_STYLE = 'letters'
    YAFP_RESOURCE_VALUE_STYLE = 'percent'
}.GetEnumerator()) {
    if (-not (Get-Variable $option.Key -Scope Global -ErrorAction Ignore)) {
        Set-Variable -Name $option.Key -Value $option.Value -Scope Global
    }
}
foreach ($name in @('YafpResourceJob', 'YafpResourceSample', 'YafpResourceAttempt')) {
    if (-not (Get-Variable $name -Scope Script -ErrorAction Ignore)) {
        Set-Variable -Name $name -Scope Script -Value $null
    }
}

$script:YafpResourceCollector = {
    param([string]$HomePath, [bool]$Windows = $IsWindows)
    $sample = [ordered]@{
        CheckedAt = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        RamUsed = $null; RamTotal = $null
        SwapUsed = $null; SwapTotal = $null
        Cpu = $null; DiskUsed = $null; DiskTotal = $null
    }
    if ($Windows) {
        try {
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
            $sample.RamTotal = [long]($os.TotalVisibleMemorySize / 1024)
            $sample.RamUsed = [long](($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1024)
        }
        catch { $sample.RamUsed = $null; $sample.RamTotal = $null }
        try {
            $pages = @(Get-CimInstance -ClassName Win32_PageFileUsage -ErrorAction Stop)
            $sample.SwapUsed = 0L
            $sample.SwapTotal = 0L
            foreach ($page in $pages) {
                $sample.SwapUsed += [long]$page.CurrentUsage
                $sample.SwapTotal += [long]$page.AllocatedBaseSize
            }
        }
        catch { $sample.SwapUsed = $null; $sample.SwapTotal = $null }
        try {
            $cpu = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor `
                -Filter "Name='_Total'" -ErrorAction Stop
            if ($null -ne $cpu) { $sample.Cpu = [long]$cpu.PercentProcessorTime }
        }
        catch { $sample.Cpu = $null }
    }
    try {
        $drive = [IO.DriveInfo]::new([IO.Path]::GetPathRoot($HomePath))
        $sample.DiskTotal = [long]($drive.TotalSize / 1024)
        $sample.DiskUsed = [long](($drive.TotalSize - $drive.AvailableFreeSpace) / 1024)
    }
    catch { $sample.DiskUsed = $null; $sample.DiskTotal = $null }
    [pscustomobject]$sample
}

function global:Format-YafpResourceSegment {
    param(
        [ValidateSet('R', 'S', 'C', 'D')][string]$Kind,
        [AllowNull()][Nullable[long]]$Value
    )
    $label = $Kind
    if ($global:YAFP_RESOURCE_LABEL_STYLE -eq 'unicode') {
        # Anterior: $label = @{ R = '▦'; S = '⇄'; C = '⚙'; D = '◉' }[$Kind]
        $label = @{ R = '▦'; S = ''; C = ''; D = '' }[$Kind]
    }
    $text = "${label}"
    $color = 'Red'
    if ($null -ne $Value -and $Value -ge 0 -and $Value -le 100) {
        $warning = if ($Kind -eq 'S') { 10 } else { 85 }
        $critical = if ($Kind -eq 'S') { 30 } else { 95 }
        $color = if ($Value -gt $critical) { 'Red' }
            elseif ($Value -gt $warning) { 'Yellow' } else { 'Green' }
        $text = "$label$Value%"
        if ($global:YAFP_RESOURCE_VALUE_STYLE -eq 'symbols') {
            $cells = @('⡀', '⣀', '⣄', '⣤', '⣦', '⣶', '⣷', '⣿')
            $level = [Math]::Min(7, [int][Math]::Floor($Value * 8 / 100))
            $text = "$label$($cells[$level])"
        }
    }
    return [pscustomobject]@{ Text = $text; Foreground = $color }
}

function global:Get-YafpResourceContext {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingEmptyCatchBlock', '',
        Justification = 'Optional sampling fails silently and retries when the interval expires.'
    )]
    param()
    $interval = 0
    if (-not [int]::TryParse("$global:YAFP_RESOURCE_CHECK_INTERVAL", [ref]$interval) -or
        $interval -lt 1 -or $interval -gt 86400) {
        return $null
    }
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if ($null -ne $script:YafpResourceJob -and
        $script:YafpResourceJob.State -in @('Completed', 'Failed', 'Stopped')) {
        try {
            $result = @(Receive-Job -Job $script:YafpResourceJob -ErrorAction Stop)
            if ($result.Count -gt 0) { $script:YafpResourceSample = $result[-1] }
        }
        catch { }
        Remove-Job -Job $script:YafpResourceJob -Force -ErrorAction Ignore
        $script:YafpResourceJob = $null
    }
    if ($null -eq $script:YafpResourceJob -and
        ($null -eq $script:YafpResourceAttempt -or $now - $script:YafpResourceAttempt -ge $interval)) {
        $script:YafpResourceAttempt = $now
        try {
            $script:YafpResourceJob = Start-ThreadJob -ScriptBlock $script:YafpResourceCollector `
                -ArgumentList $HOME -ErrorAction Stop
        }
        catch { }
    }
    $text = 'Resources: waiting for sample'
    $segments = @()
    $suffix = ''
    $separator = ' '
    if ($global:YAFP_RESOURCE_LABEL_STYLE -eq 'unicode' -and
        $global:YAFP_RESOURCE_VALUE_STYLE -eq 'symbols') {
        $separator = ''
    }
    $sample = $script:YafpResourceSample
    $percentages = @($null, $null, $null, $null)
    $state = 'unavailable'
    if ($null -ne $sample) {
        $state = 'ok'
        $ram = if ($sample.RamTotal -gt 0 -and $null -ne $sample.RamUsed) {
            [long][Math]::Floor(100 * $sample.RamUsed / $sample.RamTotal)
        } else { $null }
        $swap = if ($sample.SwapTotal -gt 0 -and $null -ne $sample.SwapUsed) {
            [long][Math]::Floor(100 * $sample.SwapUsed / $sample.SwapTotal)
        } elseif ($null -ne $sample.SwapTotal -and $sample.SwapTotal -eq 0 -and
            $null -ne $sample.SwapUsed -and $sample.SwapUsed -eq 0) {
            0L
        } else { $null }
        $disk = if ($sample.DiskTotal -gt 0 -and $null -ne $sample.DiskUsed) {
            [long][Math]::Floor(100 * $sample.DiskUsed / $sample.DiskTotal)
        } else { $null }
        $age = [Math]::Max(0, $now - $sample.CheckedAt)
        $percentages = @($sample.Cpu, $ram, $swap, $disk)
        $segments = @(
            Format-YafpResourceSegment -Kind C -Value $sample.Cpu
            Format-YafpResourceSegment -Kind R -Value $ram
            Format-YafpResourceSegment -Kind S -Value $swap
            Format-YafpResourceSegment -Kind D -Value $disk
        )
        $suffix = "$($age)s"
        $text = ($segments.Text -join $separator) + " $suffix"
    }
    if ($null -ne $script:YafpResourceJob) {
        $text += ''; $suffix += ''
        $state = if ($null -eq $sample) { 'pending' } else { 'refreshing' }
    }
    elseif ($null -eq $sample) { $text = 'Resources: no valid sample' }
    if ($null -eq $sample) {
        $placeholder = if ($null -ne $script:YafpResourceJob) { '⟳' } else { '' }
        $segments = @(foreach ($kind in @('C', 'R', 'S', 'D')) {
            $segment = Format-YafpResourceSegment -Kind $kind -Value $null
            $segment.Text = $segment.Text.Replace('', $placeholder)
            if ($placeholder -eq '⟳') { $segment.Foreground = 'DarkGray' }
            $segment
        })
        $suffix = ''
    }
    return [pscustomobject]@{
        Text = $text; Sample = $sample; Segments = $segments; Suffix = $suffix; Separator = $separator
        State = $state; Percentages = $percentages
    }
}

function global:Write-YafpOsIcon {
    param([Parameter(Mandatory)][object]$Context)

    $color = 'White'
    if ($Context.PSObject.Properties['Resources'] -and $Context.Resources) {
        foreach ($segment in $Context.Resources.Segments) {
            if ($segment.Foreground -eq 'Red') {
                $color = 'Red'
                break
            }
            if ($segment.Foreground -eq 'Yellow') { $color = 'Yellow' }
        }
    }
    Write-YafpText -Text '' -ForegroundColor $color -BackgroundColor $null -NoNewline
}

function global:Write-YafpResources {
    param([Parameter(Mandatory)][object]$Context)
    # Earlier theme consumers may omit the new property.
    if ($Context.PSObject.Properties['Resources'] -and $Context.Resources) {
        $resource = $Context.Resources
        $frameForeground = 'White'
        $frameBackground = $null
        if ($script:YafpThemeName -eq 'default') {
            $frameForeground = $script:grayColorForeground
            $frameBackground = $script:grayColorBackground
        }
        Write-YafpText -Text '↦[' -ForegroundColor $frameForeground `
            -BackgroundColor $frameBackground -NoNewline
        if ($resource.Segments.Count -gt 0) {
            $separator = ''
            foreach ($segment in $resource.Segments) {
                Write-YafpText -Text "$separator$($segment.Text)" -ForegroundColor $segment.Foreground `
                    -BackgroundColor $null -NoNewline
                $separator = $resource.Separator
            }
            if ($resource.Suffix.EndsWith('')) {
                Write-YafpText -Text '' -ForegroundColor DarkGray `
                    -BackgroundColor $null -NoNewline
            }
        }
        else {
            Write-YafpText -Text $resource.Text -ForegroundColor DarkGray `
                -BackgroundColor $null -NoNewline
        }
        Write-YafpText -Text ']' -ForegroundColor $frameForeground `
            -BackgroundColor $frameBackground -NoNewline
    }
}

function global:Show-YafpDemoResources {
    param(
        [ValidateSet('CPU', 'MEMORY', 'SWAP', 'DISK', 'ALL', 'RAM', 'MEMORIA', 'DISCO')]
        [string]$Resource = 'CPU'
    )

    $names = @('CPU', 'MEMORY', 'SWAP', 'DISK')
    if ($Resource -eq 'ALL') {
        foreach ($name in $names) {
            if ($name -ne 'CPU') { Write-Host }
            Show-YafpDemoResources -Resource $name
        }
        return
    }
    $index = @{ CPU = 0; MEMORY = 1; RAM = 1; MEMORIA = 1; SWAP = 2; DISK = 3; DISCO = 3 }[$Resource]
    $values = @(20, 40, 5, 50)
    $loads = if ($index -eq 2) { @(5, 20, 40) } else { @(20, 90, 98) }
    $separator = if ($global:YAFP_RESOURCE_LABEL_STYLE -eq 'unicode' -and
        $global:YAFP_RESOURCE_VALUE_STYLE -eq 'symbols') { '' } else { ' ' }

    foreach ($load in $loads) {
        $values[$index] = $load
        $segments = @(
            Format-YafpResourceSegment -Kind C -Value $values[0]
            Format-YafpResourceSegment -Kind R -Value $values[1]
            Format-YafpResourceSegment -Kind S -Value $values[2]
            Format-YafpResourceSegment -Kind D -Value $values[3]
        )
        $context = [pscustomobject]@{
            Resources = [pscustomobject]@{ Segments = $segments; Separator = $separator; Suffix = '' }
        }
        Write-Host ('{0,-10}  ' -f "$($names[$index]) $load%") -NoNewline
        Write-YafpOsIcon -Context $context
        Write-Host ' ' -NoNewline
        Write-YafpResources -Context $context
        Write-Host
    }
}

function global:Show-YafpResources {
    $resource = Get-YafpResourceContext
    $state = 'disabled'; $age = ''; $ageColor = 90
    $labels = @('          CPU:', '          RAM:', '         SWAP:', '  Disk (HOME):')
    $used = @($null, $null, $null); $totals = @($null, $null, $null)
    if ($null -ne $resource) {
        $state = $resource.State
        if ($null -ne $resource.Sample) {
            $sample = $resource.Sample
            $age = "$([Math]::Max(0, [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $sample.CheckedAt))s"
            $ageColor = 37
            $used = @($sample.RamUsed, $sample.SwapUsed, $sample.DiskUsed)
            $totals = @($sample.RamTotal, $sample.SwapTotal, $sample.DiskTotal)
        }
    }
    $stateIcon = ''; $stateColor = 91
    switch ($state) {
        ok { $stateIcon = ''; $stateColor = 92 }
        refreshing { $stateIcon = ''; $stateColor = 90 }
        pending { $stateIcon = ''; $stateColor = 93 }
        disabled { $stateIcon = ''; $stateColor = 90 }
    }
    $escape = [char]27
    $report = "        State: $escape[$($stateColor)m$stateIcon $state$escape[0m`n" +
        "   Sample age: $escape[$($ageColor)m$age$escape[0m"
    for ($index = 0; $index -lt 4; $index++) {
        $value = ''; $color = 90; $detail = ''
        if ($null -ne $resource -and $null -ne $resource.Sample -and
            $null -ne $resource.Percentages[$index] -and
            $resource.Percentages[$index] -ge 0 -and $resource.Percentages[$index] -le 100) {
            $value = "$($resource.Percentages[$index])%"
            $color = switch ($resource.Segments[$index].Foreground) { Green { 92 }; Yellow { 93 }; Red { 91 }; default { 90 } }
        }
        if ($index -gt 0 -and ($null -ne $used[$index - 1] -or $null -ne $totals[$index - 1])) {
            $usedText = if ($null -eq $used[$index - 1]) { '' } else { "$($used[$index - 1])" }
            $totalText = if ($null -eq $totals[$index - 1]) { '' } else { "$($totals[$index - 1])" }
            $unit = if ($index -eq 3) { 'KiB' } else { 'MiB' }
            $detail = " · $usedText/$totalText $unit"
        }
        $report += "`n$($labels[$index]) $escape[$($color)m$value$detail$escape[0m"
    }
    . (Join-Path $script:YafpRoot 'scripts/windows/preview/lib/frame.ps1')
    Write-YafpPreviewFrame -Text $report
    if ($state -eq 'disabled') {
        Write-Output 'Resources disabled. Set $global:YAFP_RESOURCE_CHECK_INTERVAL=30.'
    }
}
