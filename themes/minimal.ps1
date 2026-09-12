# Minimal PowerShell theme

. (Join-Path $PSScriptRoot 'default.ps1')

$script:YafpThemeName = 'minimal'
$script:YafpThemeVersion = '2.2'

function script:Write-YafpTheme {
    param([Parameter(Mandatory)][object]$Context)

    Write-YafpRemoteWarning -Context $Context

    $userIcon = if ($Context.IsAdmin) { '💀' } else { '👤' }
    Write-Host "🪟 $userIcon " -ForegroundColor White -NoNewline
    $userColor = if ($Context.IsAdmin) { $redColorForeground } else { $cyanColorForeground }
    $userBackground = if ($Context.IsAdmin) { $redColorBackground } else { $cyanColorBackground }
    Write-YafpText -Text $Context.User -ForegroundColor $userColor `
        -BackgroundColor $userBackground -NoNewline
    Write-Host ' @ ' -ForegroundColor White -NoNewline
    $hostColor = if ($Context.IsDevelopment) { $greenColorForeground } else { $magentaColorForeground }
    $hostBackground = if ($Context.IsDevelopment) { $greenColorBackground } else { $magentaColorBackground }
    Write-YafpText -Text $Context.Computer -ForegroundColor $hostColor `
        -BackgroundColor $hostBackground -NoNewline
    Write-Host ' ← 🖥️ LOCAL ◎ 🏠 ⌂ ' -ForegroundColor White -NoNewline
    Write-YafpText -Text $Context.Path -ForegroundColor $yellowColorForeground `
        -BackgroundColor $yellowColorBackground -NoNewline

    if ($Context.Git) {
        $remoteSymbol = if ($Context.Git.Remote -eq 'remote') { '⚡' } else { '⇣' }
        Write-Host ' on ' -ForegroundColor White -NoNewline
        Write-YafpText -Text '' `
            -ForegroundColor $blueColorForeground `
            -BackgroundColor $blueColorBackground -NoNewline
        Write-YafpGitRemoteStatus -Git $Context.Git
        Write-YafpText -Text "$($Context.Git.Branch)💻$remoteSymbol" `
            -ForegroundColor $blueColorForeground `
            -BackgroundColor $blueColorBackground -NoNewline
        $hasChanges = (
            $Context.Git.DeleteCount -gt 0 -or
            $Context.Git.ChangeCount -gt 0 -or
            $Context.Git.NewCount -gt 0
        )
        if ($hasChanges) {
            Write-Host ' with ' -ForegroundColor White -NoNewline
            Write-YafpGitCounts -Git $Context.Git
        }
    }

    if ($Context.Venv) {
        Write-Host ' 🐍 ' -ForegroundColor White -NoNewline
        Write-YafpText -Text $Context.Venv -ForegroundColor $magentaColorForeground `
            -BackgroundColor $magentaColorBackground -NoNewline
    }

    Write-Host ' ⧖ ' -ForegroundColor White -NoNewline
    Write-YafpText -Text $Context.Timestamp -ForegroundColor White `
        -BackgroundColor $null -NoNewline
    Write-Host " $($Context.DaySymbol)" -ForegroundColor White -NoNewline
    if ($Context.HadError) {
        Write-YafpText -Text " → ❌ $($Context.ExitCode)" -ForegroundColor Red `
            -BackgroundColor $null
    }
    else {
        Write-YafpText -Text ' → ✅ 0' -ForegroundColor Green `
            -BackgroundColor $null
    }

    if ($Context.IsAdmin) { return '#' }
    return '$'
}
