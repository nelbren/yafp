#requires -Version 7.2
[CmdletBinding()]
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($PSVersionTable.PSVersion -lt [version]'7.2.11') {
    throw 'PowerShell 7.2.11 or later is required.'
}

# Shared by the Windows installer and the Unix Bash entry point.
$analyzerVersion = '1.25.0'
$analyzer = Get-Module -ListAvailable -Name PSScriptAnalyzer |
    Where-Object Version -EQ ([version]$analyzerVersion)

if ($DryRun) {
    if ($analyzer) {
        Write-Output "✅ PSScriptAnalyzer $analyzerVersion is already installed"
    }
    else {
        Write-Output (
            "  + Install-Module PSScriptAnalyzer -RequiredVersion $analyzerVersion " +
            '-Scope CurrentUser -Repository PSGallery -Force'
        )
    }
    return
}

if (-not $analyzer) {
    Install-Module PSScriptAnalyzer -RequiredVersion $analyzerVersion `
        -Scope CurrentUser -Repository PSGallery -Force -ErrorAction Stop
}

Import-Module PSScriptAnalyzer -RequiredVersion $analyzerVersion `
    -Force -ErrorAction Stop
$null = Get-Command Invoke-ScriptAnalyzer -Module PSScriptAnalyzer `
    -ErrorAction Stop
Write-Output "✅ PSScriptAnalyzer $analyzerVersion is ready"
