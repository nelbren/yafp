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

Write-Output 'ok - PowerShell theme loading and fallback'
