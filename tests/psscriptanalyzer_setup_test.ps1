$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$setup = Join-Path $PSScriptRoot '../scripts/windows/setup/psscriptanalyzer.ps1'
$state = @{
    installedVersion = $null
    installCalls = 0
    importCalls = 0
    commandChecks = 0
    failInstall = $false
    failImport = $false
}

function Get-Module {
    param([switch]$ListAvailable, [string]$Name)
    if (-not $ListAvailable -or $Name -ne 'PSScriptAnalyzer') {
        throw 'Unexpected module lookup'
    }
    if ($state.installedVersion) {
        [pscustomobject]@{ Version = [version]$state.installedVersion }
    }
}

function Install-Module {
    [CmdletBinding()]
    param(
        [string]$Name, [string]$RequiredVersion, [string]$Scope,
        [string]$Repository, [switch]$Force
    )
    if ($Name -ne 'PSScriptAnalyzer' -or $RequiredVersion -ne '1.25.0' -or
        $Scope -ne 'CurrentUser' -or $Repository -ne 'PSGallery' -or -not $Force) {
        throw 'Unexpected installation parameters'
    }
    $state.installCalls++
    if ($state.failInstall) { throw 'Simulated installation failure' }
    $state.installedVersion = $RequiredVersion
}

function Import-Module {
    [CmdletBinding()]
    param([string]$Name, [string]$RequiredVersion, [switch]$Force)
    if ($Name -ne 'PSScriptAnalyzer' -or $RequiredVersion -ne '1.25.0' -or
        -not $Force) {
        throw 'Unexpected import parameters'
    }
    $state.importCalls++
    if ($state.failImport) { throw 'Simulated import failure' }
}

function Get-Command {
    [CmdletBinding()]
    param([string]$Name, [string]$Module)
    if ($Name -ne 'Invoke-ScriptAnalyzer' -or $Module -ne 'PSScriptAnalyzer') {
        throw 'Unexpected command verification'
    }
    $state.commandChecks++
}

$plan = & $setup -DryRun | Out-String
if ($plan -notmatch 'Install-Module PSScriptAnalyzer -RequiredVersion 1.25.0' -or
    $state.installCalls -ne 0 -or $state.importCalls -ne 0) {
    throw 'Dry run must describe installation without modifying modules'
}

# An older version must not satisfy the pinned dependency.
$state.installedVersion = '1.24.0'
$null = & $setup
if ($state.installCalls -ne 1 -or $state.importCalls -ne 1 -or
    $state.commandChecks -ne 1) {
    throw 'Installation did not verify the pinned module and command'
}
$null = & $setup
if ($state.installCalls -ne 1 -or $state.importCalls -ne 2) {
    throw 'Repeated setup must verify the module without reinstalling'
}
$plan = & $setup -DryRun | Out-String
if ($plan -notmatch 'already installed' -or $state.importCalls -ne 2) {
    throw 'Installed-module dry run changed modules or produced an incorrect plan'
}

$state.installedVersion = $null
$state.failInstall = $true
$failure = $null
try { $null = & $setup } catch { $failure = $_.Exception.Message }
if ($failure -ne 'Simulated installation failure' -or
    $state.importCalls -ne 2) {
    throw 'Installation failure was not propagated'
}
$state.installedVersion = '1.25.0'
$state.failImport = $true
$failure = $null
try { $null = & $setup } catch { $failure = $_.Exception.Message }
if ($failure -ne 'Simulated import failure' -or $state.commandChecks -ne 2) {
    throw 'Import failure was not propagated'
}

Write-Output 'ok - PSScriptAnalyzer setup plan, installation, reuse, and failures'
