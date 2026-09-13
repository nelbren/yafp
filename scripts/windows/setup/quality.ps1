[CmdletBinding()]
param(
    [switch]$DryRun,

    [ValidateSet('auto', 'scoop', 'winget', 'choco')]
    [string]$PackageManager = 'auto'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$markdownlintVersion = '0.49.1'
$script:resolvedPackageManager = $null

function Invoke-SetupCommand {
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter()][string[]]$Arguments = @()
    )

    if ($DryRun) {
        $displayArguments = $Arguments -join ' '
        Write-Output "  + $Command $displayArguments".TrimEnd()
        return
    }

    & $Command @Arguments
    $exitCode = Get-Variable LASTEXITCODE -Scope Global -ErrorAction Ignore
    if ($exitCode -and $exitCode.Value -ne 0) {
        throw "$Command failed with exit code $($exitCode.Value)"
    }
}

function Get-SetupPackageManager {
    if ($script:resolvedPackageManager) {
        return $script:resolvedPackageManager
    }

    if ($PackageManager -ne 'auto') {
        if (-not (Get-Command $PackageManager -ErrorAction Ignore)) {
            throw "Requested package manager not found: $PackageManager"
        }
        $script:resolvedPackageManager = $PackageManager
        return $PackageManager
    }

    foreach ($candidate in @('scoop', 'winget', 'choco')) {
        if (Get-Command $candidate -ErrorAction Ignore) {
            $script:resolvedPackageManager = $candidate
            return $candidate
        }
    }

    throw 'Install Scoop, WinGet, or Chocolatey before running this script.'
}

function Install-SetupPackage {
    param(
        [Parameter(Mandatory)][ValidateSet('shellcheck', 'node')]
        [string]$Package
    )

    $manager = Get-SetupPackageManager
    $packageNames = @{
        scoop = @{ shellcheck = 'shellcheck'; node = 'nodejs-lts' }
        winget = @{ shellcheck = 'koalaman.shellcheck'; node = 'OpenJS.NodeJS.LTS' }
        choco = @{ shellcheck = 'shellcheck'; node = 'nodejs-lts' }
    }

    switch ($manager) {
        'scoop' {
            Invoke-SetupCommand scoop @('install', $packageNames.scoop[$Package])
        }
        'winget' {
            Invoke-SetupCommand winget @(
                'install', '--exact', '--id', $packageNames.winget[$Package],
                '--accept-package-agreements', '--accept-source-agreements'
            )
        }
        'choco' {
            Invoke-SetupCommand choco @(
                'install', $packageNames.choco[$Package], '--yes'
            )
        }
    }
}

function Update-ProcessPath {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machinePath;$userPath"
}

Write-Output '🔧 Preparing Windows quality tools'

if (-not (Get-Command shellcheck -ErrorAction Ignore)) {
    Install-SetupPackage shellcheck
}
if (-not (Get-Command npm -ErrorAction Ignore)) {
    Install-SetupPackage node
}

if (-not $DryRun) {
    Update-ProcessPath
}

if ($DryRun -or (Get-Command npm -ErrorAction Ignore)) {
    Invoke-SetupCommand npm @(
        'install', '--global', "markdownlint-cli@$markdownlintVersion"
    )
}
else {
    throw 'npm is unavailable. Restart PowerShell and run this script again.'
}

$analyzer = Get-Module -ListAvailable -Name PSScriptAnalyzer |
    Where-Object Version -EQ ([version]'1.25.0')
if (-not $analyzer) {
    if ($DryRun) {
        Write-Output (
            '  + Install-Module PSScriptAnalyzer -RequiredVersion 1.25.0 ' +
            '-Scope CurrentUser -Force'
        )
    }
    else {
        $repository = Get-PSRepository -Name PSGallery
        $originalPolicy = $repository.InstallationPolicy
        try {
            if ($originalPolicy -ne 'Trusted') {
                Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
            }
            Install-Module PSScriptAnalyzer -RequiredVersion 1.25.0 `
                -Scope CurrentUser -Force
        }
        finally {
            if ($originalPolicy -ne 'Trusted') {
                Set-PSRepository -Name PSGallery `
                    -InstallationPolicy $originalPolicy
            }
        }
    }
}

if (-not $DryRun) {
    foreach ($command in @('shellcheck', 'markdownlint')) {
        if (-not (Get-Command $command -ErrorAction Ignore)) {
            throw "Required command not found after installation: $command"
        }
    }
}

Write-Output '✅ Windows quality tools are ready'
