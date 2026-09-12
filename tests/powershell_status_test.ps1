$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$rootDir = Split-Path -Parent $PSScriptRoot
. (Join-Path $rootDir 'yafp-ps.ps1')

function Assert-Status {
    param(
        [Parameter(Mandatory)][object]$Status,
        [Parameter(Mandatory)][bool]$HadError,
        [Parameter(Mandatory)][int]$Code,
        [Parameter(Mandatory)][string]$Label
    )

    if ($Status.HadError -ne $HadError -or $Status.Code -ne $Code) {
        throw "$Label`: expected error=$HadError code=$Code; " +
            "got error=$($Status.HadError) code=$($Status.Code)"
    }
}

$staleNativeCode = Get-LastCommandStatus -PreviousSucceeded $true `
    -NativeExitCode 141 -WasEmpty $false
Assert-Status -Status $staleNativeCode -HadError $false -Code 0 `
    -Label 'successful PowerShell command with stale native exit code'

$nativeFailure = Get-LastCommandStatus -PreviousSucceeded $false `
    -NativeExitCode 141 -WasEmpty $false
Assert-Status -Status $nativeFailure -HadError $true -Code 141 `
    -Label 'failed native command'

$internalFailure = Get-LastCommandStatus -PreviousSucceeded $false `
    -NativeExitCode 0 -WasEmpty $false
Assert-Status -Status $internalFailure -HadError $true -Code 1 `
    -Label 'failed PowerShell command'

$emptyInput = Get-LastCommandStatus -PreviousSucceeded $false `
    -NativeExitCode 141 -WasEmpty $true
Assert-Status -Status $emptyInput -HadError $false -Code 0 `
    -Label 'empty input'

$global:YAFP_REPOS = 0
$global:YAFP_THEME = 'light'
Import-YafpTheme
$script:promptRan = $false
$global:LASTEXITCODE = 141
$renderedPrompt = prompt 6>&1 | Out-String
if ($renderedPrompt -match '☒\s*141') {
    throw 'prompt rendered a stale native exit code as an error'
}
if ($renderedPrompt -notmatch '✓') {
    throw 'prompt did not render the successful PowerShell command state'
}

Write-Output 'ok - PowerShell command status classification'
