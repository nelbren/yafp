$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$rootDir = Split-Path -Parent $PSScriptRoot
. (Join-Path $rootDir 'yafp-ps.ps1')

function New-DevelopmentMetrics {
    param([int]$Total)

    return [pscustomobject]@{
        Total = $Total
        General = 2
        Git = 3
        Venv = 4
        Error = 5
        Timer = 6
    }
}

foreach ($case in @(
    @{ Total = 49; Icon = '🚀' }
    @{ Total = 50; Icon = '⏱️' }
    @{ Total = 200; Icon = '🐢' }
)) {
    $metrics = New-DevelopmentMetrics -Total $case.Total
    $output = Write-YafpDevelopmentMetrics -Development $metrics 6>&1 |
        Out-String
    $expected = "$($case.Icon)$($case.Total)ms | ⚙️2 🌱3 🐍4 ❌5 ⚡6"
    if ($output -notmatch [regex]::Escape($expected)) {
        throw "development metrics were not rendered for $($case.Total) ms"
    }
}

$global:YAFP_REPOS = 0
$global:YAFP_PVENV = 0
$global:YAFP_DEVEL = 0
$script:promptRan = $false
$withoutMetrics = prompt 6>&1 | Out-String
if ($withoutMetrics -match 'ms \| ⚙️') {
    throw 'development metrics rendered while YAFP_DEVEL was disabled'
}

$global:YAFP_DEVEL = 1
foreach ($theme in @('default', 'minimal', 'light')) {
    $global:YAFP_THEME = $theme
    Import-YafpTheme
    $script:promptRan = $false
    $withMetrics = prompt 6>&1 | Out-String
    if ($withMetrics -notmatch '(?:🚀|⏱️|🐢)\d+ms \| ⚙️\d+ 🌱\d+ 🐍\d+ ❌\d+ ⚡\d+') {
        throw "$theme theme did not render development timing metrics"
    }
}

Write-Output 'ok - PowerShell development timing metrics'
