# Light PowerShell theme

. (Join-Path $PSScriptRoot 'default.ps1')

$script:YafpThemeName = 'light'
$script:YafpThemeVersion = '1.0'

$script:greenColorBackground = $null
$script:greenColorForeground = 'Green'
$script:redColorBackground = $null
$script:redColorForeground = 'Red'
$script:cyanColorBackground = $null
$script:cyanColorForeground = 'Cyan'
$script:magentaColorBackground = $null
$script:magentaColorForeground = 'Magenta'
$script:yellowColorBackground = $null
$script:yellowColorForeground = 'Yellow'
$script:grayColorBackground = $null
$script:grayColorForeground = 'White'
$script:blueColorBackground = $null
$script:blueColorForeground = 'Blue'

function script:Write-YafpTheme {
    param([Parameter(Mandatory)][object]$Context)

    Write-YafpRemoteWarning -Context $Context

    Write-YafpText -Text '🪟 ' -ForegroundColor White `
        -BackgroundColor $null -NoNewline
    $userColor = if ($Context.IsAdmin) { 'Red' } else { 'Cyan' }
    Write-YafpText -Text $Context.User -ForegroundColor $userColor `
        -BackgroundColor $null -NoNewline
    Write-Host ' @ ' -ForegroundColor White -NoNewline
    $hostColor = if ($Context.IsDevelopment) { 'Green' } else { 'Magenta' }
    Write-YafpText -Text $Context.Computer -ForegroundColor $hostColor `
        -BackgroundColor $null -NoNewline
    Write-Host ' ⌂ ' -ForegroundColor White -NoNewline
    Write-YafpText -Text $Context.Path -ForegroundColor Yellow `
        -BackgroundColor $null -NoNewline

    if ($Context.Git) {
        $remoteSymbol = if ($Context.Git.Remote -eq 'remote') { '↯' } else { '⇣' }
        Write-Host '  ' -ForegroundColor White -NoNewline
        Write-YafpGitRemoteStatus -Git $Context.Git
        Write-YafpText -Text $Context.Git.Branch -ForegroundColor Blue `
            -BackgroundColor $null -NoNewline
        Write-Host $remoteSymbol -ForegroundColor White -NoNewline
        $hasChanges = (
            $Context.Git.DeleteCount -gt 0 -or
            $Context.Git.ChangeCount -gt 0 -or
            $Context.Git.NewCount -gt 0
        )
        if ($hasChanges) {
            Write-Host '⇢[' -ForegroundColor White -NoNewline
            Write-YafpGitCounts -Git $Context.Git -Plain
            Write-Host ']' -ForegroundColor White -NoNewline
        }
        else {
            Write-YafpText -Text '✓' -ForegroundColor Green `
                -BackgroundColor $null -NoNewline
        }
    }

    if ($Context.Venv) {
        Write-Host ' 🐍 ' -ForegroundColor White -NoNewline
        Write-YafpText -Text $Context.Venv -ForegroundColor Magenta `
            -BackgroundColor $null -NoNewline
    }

    if ($Context.HadError) {
        Write-YafpText -Text " ☒ $($Context.ExitCode)" -ForegroundColor Red `
            -BackgroundColor $null
    }
    else {
        Write-YafpText -Text ' ✓' -ForegroundColor Green `
            -BackgroundColor $null
    }

    if ($Context.IsAdmin) { return '#' }
    return '$'
}
