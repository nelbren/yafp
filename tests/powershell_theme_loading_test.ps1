$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$rootDir = Split-Path -Parent $PSScriptRoot
. (Join-Path $rootDir 'yafp-ps.ps1')

foreach ($case in @(
    @{ Requested = 'default'; Expected = 'default' }
    @{ Requested = 'minimal'; Expected = 'minimal' }
    @{ Requested = 'light'; Expected = 'light' }
    @{ Requested = 'missing-theme'; Expected = 'default' }
)) {
    $global:YAFP_THEME = $case.Requested
    Import-YafpTheme
    if ($script:YafpThemeName -ne $case.Expected) {
        throw "$($case.Requested) loaded $script:YafpThemeName instead of " +
            $case.Expected
    }
}

$global:YAFP_REPOS = 0
$global:YAFP_PVENV = 0
$global:YAFP_ERROR = 0
$global:YAFP_DEVEL = 0

foreach ($theme in @('default', 'minimal', 'light')) {
    $global:YAFP_THEME = $theme
    Import-YafpTheme

    $global:YAFP_CLOCK = 1
    $script:promptRan = $false
    $withClock = prompt 6>&1 | Out-String
    if ($withClock -notmatch '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}') {
        throw "$theme theme did not render the enabled clock"
    }

    $global:YAFP_CLOCK = 0
    $script:promptRan = $false
    $withoutClock = prompt 6>&1 | Out-String
    if ($withoutClock -match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}') {
        throw "$theme theme rendered the disabled clock"
    }
}

Write-Output 'ok - PowerShell theme loading, fallback, and clock setting'
