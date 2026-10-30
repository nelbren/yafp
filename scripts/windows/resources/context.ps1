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
        $label = @{ R = '▦'; S = '⇄'; C = '⚙'; D = '◉' }[$Kind]
    }
    $text = "${label}N/A"
    $color = 'DarkGray'
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
    if ($null -ne $sample) {
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
        $segments = @(
            Format-YafpResourceSegment -Kind C -Value $sample.Cpu
            Format-YafpResourceSegment -Kind R -Value $ram
            Format-YafpResourceSegment -Kind S -Value $swap
            Format-YafpResourceSegment -Kind D -Value $disk
        )
        $suffix = "$($age)s"
        $text = ($segments.Text -join $separator) + " $suffix"
    }
    if ($null -ne $script:YafpResourceJob) { $text += '~'; $suffix += '~' }
    elseif ($null -eq $sample) { $text = 'Resources: no valid sample' }
    return [pscustomobject]@{
        Text = $text; Sample = $sample; Segments = $segments; Suffix = $suffix; Separator = $separator
    }
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
            if ($resource.Suffix.EndsWith('~')) {
                Write-YafpText -Text '~' -ForegroundColor DarkGray `
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

function global:Show-YafpResources {
    $resource = Get-YafpResourceContext
    if ($null -eq $resource) {
        Write-Output 'Resources disabled. Set $global:YAFP_RESOURCE_CHECK_INTERVAL=30.'
        return
    }
    Write-Output $resource.Text
    $sample = $resource.Sample
    if ($null -ne $sample) {
        Write-Output "RAM: $($sample.RamUsed)/$($sample.RamTotal) MiB  SWAP: $($sample.SwapUsed)/$($sample.SwapTotal) MiB"
        Write-Output "Disk (HOME volume): $($sample.DiskUsed)/$($sample.DiskTotal) KiB"
    }
}
