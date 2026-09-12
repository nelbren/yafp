# Default PowerShell theme

$script:YafpThemeName = 'default'
$script:YafpThemeVersion = '2.2'

$useDarkColors = (
    (Get-Variable YAFP_DARKC -Scope Global -ErrorAction Ignore) -and
    $global:YAFP_DARKC -eq 1
)

if ($useDarkColors) {
    $script:greenColorBackground = 'DarkGreen'
    $script:greenColorForeground = 'Black'
    $script:redColorBackground = 'DarkRed'
    $script:redColorForeground = 'White'
    $script:cyanColorBackground = 'DarkCyan'
    $script:cyanColorForeground = 'Black'
    $script:magentaColorBackground = 'DarkMagenta'
    $script:magentaColorForeground = 'Black'
    $script:yellowColorBackground = 'DarkYellow'
    $script:yellowColorForeground = 'Black'
    $script:grayColorBackground = 'Gray'
    $script:grayColorForeground = 'Black'
    $script:blueColorBackground = 'DarkBlue'
    $script:blueColorForeground = 'White'
}
else {
    $script:greenColorBackground = 'Green'
    $script:greenColorForeground = 'Black'
    $script:redColorBackground = 'Red'
    $script:redColorForeground = 'White'
    $script:cyanColorBackground = 'Cyan'
    $script:cyanColorForeground = 'Black'
    $script:magentaColorBackground = 'Magenta'
    $script:magentaColorForeground = 'Black'
    $script:yellowColorBackground = 'Yellow'
    $script:yellowColorForeground = 'Black'
    $script:grayColorBackground = 'White'
    $script:grayColorForeground = 'Black'
    $script:blueColorBackground = 'Blue'
    $script:blueColorForeground = 'White'
}

function script:Write-YafpGitCounts {
    param(
        [Parameter(Mandatory)]
        [object]$Git,
        [switch]$Plain
    )

    if ($Git.DeleteCount -gt 0) {
        $prefix = if ($Plain) { '' } else { '🗑️' }
        Write-YafpText -Text "$prefix-$($Git.DeleteCount)" `
            -ForegroundColor Red -BackgroundColor $null -NoNewline
    }
    if ($Git.ChangeCount -gt 0) {
        $prefix = if ($Plain) { '' } else { '📝' }
        Write-YafpText -Text "$prefix±$($Git.ChangeCount)" `
            -ForegroundColor Yellow -BackgroundColor $null -NoNewline
    }
    if ($Git.NewCount -gt 0) {
        $prefix = if ($Plain) { '' } else { '🆕' }
        Write-YafpText -Text "$prefix+$($Git.NewCount)" `
            -ForegroundColor Cyan -BackgroundColor $null -NoNewline
    }
}

function script:Write-YafpTheme {
    param([Parameter(Mandatory)][object]$Context)

    Write-YafpRemoteWarning -Context $Context

    if ($Context.Git) {
        $remoteSymbol = if ($Context.Git.Remote -eq 'remote') { '⚡' } else { '⇣' }
        Write-YafpText -Text "[🔛$($Context.Git.LastTimestamp)💾$($Context.Git.Repository)ᚼ" `
            -ForegroundColor $grayColorForeground `
            -BackgroundColor $grayColorBackground -NoNewline
        Write-YafpGitRemoteStatus -Git $Context.Git
        Write-YafpText -Text "$($Context.Git.Branch)💻$remoteSymbol" `
            -ForegroundColor $grayColorForeground `
            -BackgroundColor $grayColorBackground -NoNewline
        Write-YafpGitCounts -Git $Context.Git
        Write-YafpText -Text ']' -ForegroundColor $grayColorForeground `
            -BackgroundColor $grayColorBackground -NoNewline
    }
    if ($Context.Venv) {
        Write-YafpText -Text "[🐍$($Context.Venv)]" `
            -ForegroundColor $blueColorForeground `
            -BackgroundColor $blueColorBackground -NoNewline
    }
    if ($Context.Git -or $Context.Venv) {
        Write-Host
    }

    if ($global:YAFP_ERROR -eq 1) {
        $statusSymbol = if ($Context.HadError) { '⚠️' } else { '✅' }
        $foreground = if ($Context.HadError) { $redColorForeground } else { $greenColorForeground }
        $background = if ($Context.HadError) { $redColorBackground } else { $greenColorBackground }
        Write-YafpText -Text "[🔚$($Context.PreviousTimestamp)🚀$($Context.PreviousCommand)→$statusSymbol$($Context.ExitCode)]" `
            -ForegroundColor $foreground -BackgroundColor $background -NoNewline
    }

    Write-YafpText -Text "[🔜$($Context.Timestamp)$($Context.DaySymbol)]" `
        -ForegroundColor $cyanColorForeground `
        -BackgroundColor $cyanColorBackground

    Write-Host '[' -ForegroundColor White -NoNewline
    $userForeground = if ($Context.IsAdmin) { 'White' } else { $cyanColorForeground }
    $userBackground = if ($Context.IsAdmin) { $redColorBackground } else { $cyanColorBackground }
    Write-YafpText -Text $Context.User -ForegroundColor $userForeground `
        -BackgroundColor $userBackground -NoNewline
    Write-Host '@' -ForegroundColor White -NoNewline
    $hostForeground = if ($Context.IsDevelopment) { $greenColorForeground } else { $magentaColorForeground }
    $hostBackground = if ($Context.IsDevelopment) { $greenColorBackground } else { $magentaColorBackground }
    Write-YafpText -Text $Context.Computer -ForegroundColor $hostForeground `
        -BackgroundColor $hostBackground -NoNewline
    Write-Host ':' -ForegroundColor White -NoNewline
    Write-YafpText -Text $Context.Path -ForegroundColor $yellowColorForeground `
        -BackgroundColor $yellowColorBackground -NoNewline
    Write-Host ']' -ForegroundColor White -NoNewline

    if ($Context.IsAdmin) { return '#' }
    return '$'
}
