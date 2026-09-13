$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$rootDir = Split-Path -Parent $PSScriptRoot
. (Join-Path $rootDir 'yafp-ps.ps1')

$escape = [char]27
$bell = [char]7

$global:YAFP_OSC133 = 1
$promptStart = Get-YafpOsc133Sequence -Payload 'A'
if ($promptStart -ne "$escape]133;A$bell") {
    throw 'OSC 133 prompt-start sequence is invalid'
}
$commandFinished = Get-YafpOsc133Sequence -Payload 'D;7'
if ($commandFinished -ne "$escape]133;D;7$bell") {
    throw 'OSC 133 command-finished sequence did not preserve the exit code'
}

$global:YAFP_OSC133 = 0
if (Get-YafpOsc133Sequence -Payload 'A') {
    throw 'disabled OSC 133 generated a sequence'
}

$global:YAFP_REPOS = 0
$global:YAFP_PVENV = 0
$global:YAFP_ERROR = 0
$global:YAFP_CLOCK = 0
$global:YAFP_DEVEL = 0
$global:YAFP_THEME = 'light'
Import-YafpTheme

$global:YAFP_OSC133 = 1
$script:promptRan = $false
$script:prevHistCount = @(Get-History).Count
$firstPrompt = prompt 6>&1 | Out-String
if ($firstPrompt -notmatch [regex]::Escape("$escape]133;A$bell") -or
    $firstPrompt -notmatch [regex]::Escape("$escape]133;B$bell")) {
    throw 'initial prompt did not emit OSC 133 A and B markers'
}
if ($firstPrompt -match [regex]::Escape("$escape]133;D")) {
    throw 'initial prompt emitted an OSC 133 command-finished marker'
}

$secondPrompt = prompt 6>&1 | Out-String
if ($secondPrompt -notmatch [regex]::Escape("$escape]133;D$bell")) {
    throw 'empty input did not emit an OSC 133 D marker without an exit code'
}

$global:YAFP_OSC133 = 0
$script:promptRan = $false
$disabledPrompt = prompt 6>&1 | Out-String
if ($disabledPrompt -match [regex]::Escape("$escape]133;")) {
    throw 'disabled OSC 133 emitted prompt markers'
}

Write-Output 'ok - PowerShell OSC 133 prompt lifecycle'
