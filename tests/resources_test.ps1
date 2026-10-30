$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$env:YAFP_METRICS_DISABLED = '1'
$env:COMPUTERNAME = 'yafp-test'
$env:USERNAME = 'yafp-test'
. (Join-Path $PSScriptRoot '../yafp-ps.ps1')

foreach ($interval in @('0', '-1', 'bad', '9999999999999999999')) {
    $global:YAFP_RESOURCE_CHECK_INTERVAL = $interval
    if ($null -ne (Get-YafpResourceContext)) { throw 'Intervalo inválido aceptado' }
    if ($null -ne $script:YafpResourceJob) { throw 'Se creó un worker desactivado' }
}
Write-Output 'ok - recursos PowerShell desactivados o inválidos no crean workers'

function Get-CimInstance {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidOverwritingBuiltInCmdlets', '',
        Justification = 'Local fixture: replace CIM to validate Windows on any OS.'
    )]
    param([string]$ClassName, [string]$Filter, [string]$ErrorAction)
    if ($ErrorAction -ne 'Stop') { throw 'La sonda debe capturar errores' }
    switch ($ClassName) {
        Win32_OperatingSystem {
            [pscustomobject]@{ TotalVisibleMemorySize = 16777216; FreePhysicalMemory = 4194304 }
        }
        Win32_PageFileUsage {
            [pscustomobject]@{ CurrentUsage = 1024; AllocatedBaseSize = 2048 }
            [pscustomobject]@{ CurrentUsage = 512; AllocatedBaseSize = 1024 }
        }
        Win32_PerfFormattedData_PerfOS_Processor {
            if ($Filter -ne "Name='_Total'") { throw 'Falta contador total' }
            [pscustomobject]@{ PercentProcessorTime = 25 }
        }
    }
}
$sample = & $script:YafpResourceCollector $HOME $true
if ($sample.RamUsed -ne 12288 -or $sample.RamTotal -ne 16384 -or
    $sample.SwapUsed -ne 1536 -or $sample.SwapTotal -ne 3072 -or $sample.Cpu -ne 25) {
    throw 'Sondas Windows incorrectas'
}
function Get-CimInstance {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidOverwritingBuiltInCmdlets', '',
        Justification = 'Local failure fixture: no real CIM queries are made.'
    )]
    param()
    throw 'Sonda no disponible'
}
$sample = & $script:YafpResourceCollector $HOME $true
if ($null -ne $sample.RamUsed -or $null -ne $sample.SwapUsed -or $null -ne $sample.Cpu) {
    throw 'Una sonda fallida inventó métricas'
}
Remove-Item Function:Get-CimInstance
Write-Output 'ok - sondas Windows, suma de pagefiles y fallos parciales'

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
                throw "Caso incorrecto: $line/$labels/$values"
            }
        }
    }
}
$global:YAFP_RESOURCE_LABEL_STYLE = 'bad'
$global:YAFP_RESOURCE_VALUE_STYLE = 'bad'
if ((Format-YafpResourceSegment -Kind R -Value 74).Text -ne 'R74%') {
    throw 'Fallback de estilos inválidos incorrecto'
}
$global:YAFP_RESOURCE_LABEL_STYLE = 'letters'
$global:YAFP_RESOURCE_VALUE_STYLE = 'percent'
Write-Output 'ok - etiquetas, Braille y límites de color compartidos en PowerShell'

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
    if ($timer.ElapsedMilliseconds -ge 500) { throw 'El worker bloqueó el contexto' }
    $job = $script:YafpResourceJob
    if ($context.Text -notmatch 'esperando muestra') { throw 'Falta estado pendiente' }
    1..3 | ForEach-Object { $null = Get-YafpResourceContext }
    if ($script:YafpResourceJob.Id -ne $job.Id) { throw 'Workers duplicados' }
    Invoke-YafpReload
    $global:YAFP_RESOURCE_CHECK_INTERVAL = 30
    $null = Get-YafpResourceContext
    if ($script:YafpResourceJob.Id -ne $job.Id) { throw 'Reload duplicó el worker' }
    $null = Wait-Job -Job $job -Timeout 10
    $context = Get-YafpResourceContext
    if ($context.Text -notmatch '^C25% R50% S50% D75% \d+s$') {
        throw "Muestra incorrecta: $($context.Text)"
    }
    if ($null -ne $script:YafpResourceJob) { throw 'Job completado no se eliminó' }
    if ((Get-Job -Id $job.Id -ErrorAction Ignore)) { throw 'Job registrado después de completarse' }
    if ((Show-YafpResources | Out-String) -notmatch '2048/4096 MiB') { throw 'Falta detalle' }

    # The hot path neither starts another job nor queries the probes again.
    function Start-ThreadJob { throw 'Se inició otro trabajo en el intervalo' }
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
                throw "Falta muestra en tema $theme/$($case.Labels)/$($case.Values)"
            }
            if ([regex]::Matches($output, [regex]::Escape($block)).Count -ne 1) {
                throw 'Recursos duplicados'
            }
            if ($global:LASTEXITCODE -ne 7) { throw 'Código de salida alterado' }
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
                            throw "Marco o edad incorrectos: $theme/$labels/$values"
                        }
                        if (($script:resourceWrites[1..4].Color -join ',') -ne 'Green,Green,Red,Green') {
                            throw 'Colores por recurso incorrectos'
                        }
                        foreach ($index in @(0, 5)) {
                            $write = $script:resourceWrites[$index]
                            if ($write.Color -ne $frameForeground -or $write.Background -ne $frameBackground -or
                                -not $write.NoNewline) {
                                throw "Colores del marco Git incorrectos: $theme/$dark"
                            }
                        }
                        foreach ($write in $script:resourceWrites[1..4]) {
                            if ($null -ne $write.Background -or -not $write.NoNewline) {
                                throw 'El recurso debe usar solo color frontal y permanecer en la misma línea'
                            }
                        }
                    }
                }
            }
        }
        $global:YAFP_RESOURCE_CHECK_INTERVAL = 0
        $script:resourceWrites.Clear()
        Write-YafpResources -Context ([pscustomobject]@{ Resources = (Get-YafpResourceContext) })
        if ($script:resourceWrites.Count -ne 0) { throw 'Marco vacío con monitoreo desactivado' }
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
    if ($context.Text -notmatch '^CN/D RN/D S0% DN/D 60s$') {
        throw 'Degradación de métricas ausentes o edad incorrecta'
    }
    $script:YafpResourceSample.SwapUsed = 1552
    $script:YafpResourceSample.SwapTotal = 3072
    if ((Get-YafpResourceContext).Text -notmatch ' S50% ') {
        throw 'Porcentaje entero de swap incorrecto'
    }
    $script:YafpResourceSample.SwapTotal = $null
    if ((Get-YafpResourceContext).Text -notmatch ' SN/D ') {
        throw 'Capacidad de swap ausente debe indicar N/D'
    }
    Write-Output 'ok - worker PowerShell único, no bloqueante, reload, tres temas y estado previo'
}
finally {
    if ($null -ne $script:YafpResourceJob) {
        Remove-Job -Job $script:YafpResourceJob -Force -ErrorAction Ignore
    }
}
