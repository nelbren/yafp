$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$setup = Join-Path $PSScriptRoot '../scripts/windows/setup/quality.ps1'

function Get-Command {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidOverwritingBuiltInCmdlets', '',
        Justification = 'Mock command discovery in both setup plans.'
    )]
    param([string]$Name)

    switch ($Name) {
        'shellcheck' {}
        { $_ -in 'choco', 'npm' } { $Name }
        default { throw "Unexpected command lookup: $Name" }
    }
}

$plan = & $setup -DryRun -PackageManager choco | Out-String
$powerShellPlan = & $setup -DryRun -PackageManager choco -SkipShellCheck |
    Out-String

if ($plan -notmatch 'choco install shellcheck --yes' -or
    $powerShellPlan -match 'shellcheck' -or
    $powerShellPlan -notmatch 'npm install --global markdownlint-cli@' -or
    $powerShellPlan -notmatch 'PSScriptAnalyzer') {
    throw 'Windows quality plans must include ShellCheck only for the full setup'
}

Write-Output 'ok - Windows quality setup plans for Git Bash and PowerShell'
