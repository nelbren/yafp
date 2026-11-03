$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$env:YAFP_METRICS_DISABLED = '1'
. (Join-Path $PSScriptRoot '../yafp-ps.ps1')
$global:YAFP_CLOCK = 0; $global:YAFP_ERROR = 1
$global:YAFP_REMOTE_CHECK_INTERVAL = 300
$script:YafpRemoteOfflineAcknowledged = $false
$git = [pscustomobject]@{
    Remote = 'remote'; Branch = 'main'; Repository = 'fixture'; LastTimestamp = ''
    DeleteCount = 0; ChangeCount = 0; NewCount = 0; StagedCount = 0
    RemoteStatus = [pscustomobject]@{
        State = 'current'; RefreshIn = 175; Refreshing = $false
        ConnectionAnnouncement = $false; Ahead = 2; Behind = 3; Upstream = 'origin/main'
    }
}
$context = [pscustomobject]@{
    User = 'user'; Computer = 'host'; Path = '~'; IsAdmin = $false; IsDevelopment = $true
    ClockEnabled = $false; Development = $null; Git = $git; Venv = 'env⚠️'
    Resources = $null; Codex = $null; HadError = $false; ExitCode = 0
    PreviousTimestamp = ''; PreviousCommand = 'echo ⚠️'; Timestamp = ''; DaySymbol = ''
}
# Compact presentation is tested separately from existing cursor/banner tests.
function Write-YafpRemoteExpansion {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'Presentation fixture suppresses cursor banners covered by remote-status tests.'
    )]
    param([object]$Remote, [string]$IndicatorText)
}
function Write-YafpStagedExpansion {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'Presentation fixture suppresses the staged banner tested separately.'
    )]
    param([object]$Git)
}
$writer = (Get-Command Write-YafpText).ScriptBlock
$script:frameWrites = [Collections.Generic.List[object]]::new()
try {
    foreach ($dark in @(0, 1)) {
        $global:YAFP_DARKC = $dark
        foreach ($theme in @('default', 'minimal', 'light')) {
            $global:YAFP_THEME = $theme
            Import-YafpTheme
            $foreground = if ($theme -eq 'default') { $script:grayColorForeground } else { 'White' }
            $background = if ($theme -eq 'default') { $script:grayColorBackground } else { $null }
            foreach ($style in @('numeric', 'symbols')) {
                $global:YAFP_REMOTE_COUNTDOWN_STYLE = $style
                $git.RemoteStatus.State = 'current'; $git.RemoteStatus.RefreshIn = 175
                $out = (@(Write-YafpGitRemoteStatus -Git $git 6>&1) | ForEach-Object { "$_" }) -join ''
                $out = $out -replace '\x1b\[[0-?]*[ -/]*[@-~]', ''
                $expected = if ($style -eq 'symbols') { '↦[⣦]' } else { '↦[(175)]' }
                if ($out.TrimEnd() -ne $expected) { throw "Remote frame mismatch: $theme/$style/$out" }
            }
            $git.RemoteStatus.RefreshIn = $null
            $git.RemoteStatus.State = 'current'; $git.RemoteStatus.Refreshing = $true
            $out = (@(Write-YafpGitRemoteStatus -Git $git 6>&1) | ForEach-Object { "$_" }) -join ''
            $out = $out -replace '\x1b\[[0-?]*[ -/]*[@-~]', ''
            if ($out.TrimEnd() -ne '↦[]') { throw "Refresh icon spacing: $theme/$out" }
            $git.RemoteStatus.Refreshing = $false
            foreach ($case in @(
                @('no-commits', '○0'), @('no-upstream', '⇡?'), @('checking', '…'),
                @('ahead', '⇡2'), @('behind', '⇣3'), @('diverged', '⇡2⇣3'), @('error', '')
            )) {
                $git.RemoteStatus.State = $case[0]
                $out = (@(Write-YafpGitRemoteStatus -Git $git 6>&1) | ForEach-Object { "$_" }) -join ''
                $out = $out -replace '\x1b\[[0-?]*[ -/]*[@-~]', ''
                if ($out.TrimEnd() -ne "↦[$($case[1])]") { throw "State frame mismatch: $theme/$($case[0]): [$out]" }
            }
            $git.RemoteStatus.State = ''
            $out = (@(Write-YafpGitRemoteStatus -Git $git 6>&1) | ForEach-Object { "$_" }) -join ''
            $out = $out -replace '\x1b\[[0-?]*[ -/]*[@-~]', ''
            if ($out) { throw 'Empty remote frame' }
            $git.DeleteCount = 0; $git.ChangeCount = 0; $git.NewCount = 0; $git.StagedCount = 0
            $out = (@(Write-YafpGitCounts -Git $git 6>&1) | ForEach-Object { "$_" }) -join ''
            $out = $out -replace '\x1b\[[0-?]*[ -/]*[@-~]', ''
            if ($out) { throw 'Empty counter frame' }
            $git.DeleteCount = 1; $git.ChangeCount = 2; $git.NewCount = 3; $git.StagedCount = 4
            $git.RemoteStatus.State = 'current'; $git.RemoteStatus.RefreshIn = 175
            $out = (@(Write-YafpTheme -Context $context 6>&1) | ForEach-Object { "$_" }) -join ''
            $out = $out -replace '\x1b\[[0-?]*[ -/]*[@-~]', ''
            if (-not $out.Contains('')) { throw "Git logo missing: $theme" }
            if (-not $out.Contains('') -or -not $out.Contains('env⚠️') -or -not $out.Contains('4')) {
                throw "Python/staged glyph missing or environment name changed: $theme"
            }
            if (-not $out.Contains('')) { throw "Success glyph missing: $theme" }
            if ($theme -ne 'light') {
                if (-not $out.Contains('-1') -or -not $out.Contains('±2') -or
                    -not $out.Contains('+3') -or -not $out.Contains('') -or -not $out.Contains('')) {
                    throw "Git counter, remote, or success glyph missing: $theme"
                }
            }
            if ($theme -eq 'default' -and -not $out.Contains('echo ⚠️')) {
                throw 'Command marker must not alter command text'
            }
            if ($theme -eq 'minimal') {
                foreach ($icon in @('', '', '')) {
                    if (-not $out.Contains($icon)) { throw "Minimal glyph missing: $icon" }
                }
                $context.IsAdmin = $true
                $admin = (@(Write-YafpTheme -Context $context 6>&1) | ForEach-Object { "$_" }) -join ''
                if (-not $admin.Contains('')) { throw 'Administrator shield glyph missing' }
                $context.IsAdmin = $false
            }
            $context.HadError = $true; $context.ExitCode = 7
            $errorText = (@(Write-YafpTheme -Context $context 6>&1) | ForEach-Object { "$_" }) -join ''
            $expectedError = switch ($theme) { default { '7' }; minimal { ' 7' }; light { ' 7' } }
            if (-not $errorText.Contains($expectedError)) { throw "Command error glyph/code changed: $theme" }
            $context.HadError = $false; $context.ExitCode = 0
            if ($theme -ne 'default' -and (-not $out.Contains(' ') -or $out.Contains('🪟'))) {
                throw "Windows font glyph missing: $theme"
            }
            $gitIndicator = if ($theme -eq 'default') { 'ᚼ' } else { '' }
            if (-not $out.Contains("$gitIndicator↦[")) { throw "Space between Git marker and remote frame: $theme" }
            if ([regex]::Matches($out, '↦\[').Count -ne 2 -or $out.Contains('↦[↦[')) {
                throw "Missing or nested Git frames: $theme/$out"
            }
            function Write-YafpText {
                param([string]$Text, [object]$ForegroundColor, [object]$BackgroundColor, [switch]$NoNewline)
                $script:frameWrites.Add([pscustomobject]@{
                    Text = $Text; Foreground = $ForegroundColor; Background = $BackgroundColor
                    NoNewline = [bool]$NoNewline
                })
            }
            try {
                $script:frameWrites.Clear()
                $null = Write-YafpGitRemoteStatus -Git $git 6>&1
                $null = Write-YafpGitCounts -Git $git -Plain 6>&1
                $frames = @($script:frameWrites | Where-Object { $_.Text -in @('↦[', ']') })
                if ($frames.Count -ne 4) { throw 'Expected a single frame per block' }
                foreach ($frame in $frames) {
                    if ($frame.Foreground -ne $foreground -or $frame.Background -ne $background -or -not $frame.NoNewline) {
                        throw "Frame color mismatch: $theme/$dark"
                    }
                }
                foreach ($case in @(@('', 'Green'), @('-1', 'Red'), @('±2', 'Yellow'), @('+3', 'Cyan'))) {
                    $token = @($script:frameWrites | Where-Object Text -EQ $case[0])
                    if ($token.Count -ne 1 -or $token[0].Foreground -ne $case[1] -or $null -ne $token[0].Background) {
                        throw "Token color changed: $($case[0])"
                    }
                }
                $script:frameWrites.Clear()
                $git.RemoteStatus.Refreshing = $true
                $null = Write-YafpGitRemoteStatus -Git $git 6>&1
                $marker = @($script:frameWrites | Where-Object Text -EQ '')
                $warning = Get-YafpSeverityStyle -Severity warning
                if ($marker.Count -ne 1 -or $marker[0].Foreground -ne $warning.Foreground -or
                    $marker[0].Background -ne $warning.Background -or -not $marker[0].NoNewline) {
                    throw 'Refresh icon must preserve its existing warning colors'
                }
                $git.RemoteStatus.Refreshing = $false
                $git.RemoteStatus.State = 'error'
                foreach ($acknowledged in @($false, $true)) {
                    $script:YafpRemoteOfflineAcknowledged = $acknowledged
                    $script:frameWrites.Clear()
                    $null = Write-YafpGitRemoteStatus -Git $git 6>&1 | Out-String
                    $icon = $script:frameWrites | Where-Object Text -EQ '' | Select-Object -Last 1
                    $expectedForeground = if ($acknowledged) { 'Red' } else { 'White' }
                    $expectedBackground = if ($acknowledged) { $null } else { 'Red' }
                    if ($icon.Foreground -ne $expectedForeground -or $icon.Background -ne $expectedBackground) {
                        throw "Offline highlight mismatch: $theme/$dark/$acknowledged"
                    }
                }
                $script:YafpRemoteOfflineAcknowledged = $false
                $git.RemoteStatus.State = 'current'
            }
            finally { Set-Item Function:Write-YafpText -Value $writer }
        }
    }
}
finally { Set-Item Function:Write-YafpText -Value $writer }
$report = @(Format-YafpRemoteStatusReport -State current -Refreshing $true -Remaining 0 -Interval 300 -Now 0)
if ($report[0] -ne '       Remote:  Refreshing · last:  Up to date') {
    throw 'Detailed remote status must use the refresh icon'
}
foreach ($remaining in @(175, $null)) {
    $report = @(Format-YafpRemoteStatusReport -State current -Remaining $remaining -Interval 300 -Now 0)
    if (-not $report[2].StartsWith(' Current time: ') -or -not $report[3].StartsWith('   Next check: ')) {
        throw 'Report clock/calendar glyphs are missing'
    }
    foreach ($line in $report) {
        if ($line.IndexOf(':') -ne 14) { throw "Report label alignment: $line" }
    }
}
. (Join-Path $PSScriptRoot '../scripts/windows/preview/lib/frame.ps1')
$statusOutput = (@(Write-YafpStatusReport -State current -Remaining 175 -Interval 300 -Now 0 -Framed 6>&1) |
    ForEach-Object { "$_" }) -join "`n"
if (-not $statusOutput.Contains('┌') -or -not $statusOutput.Contains('┘') -or
    -not $statusOutput.Contains('       Remote: ') -or -not $statusOutput.Contains('   Next check: ')) {
    throw 'Framed status output lost its fields or borders'
}
$script:YafpCommandsTotal = 13; $script:YafpCommandsSucceeded = 11; $script:YafpCommandsFailed = 2
$statsOutput = (@(Show-YafpStats 6>&1) | ForEach-Object { "$_" }) -join "`n"
foreach ($text in @('┌', '┘', ' Succeeded: 11 (085%)', ' Failed:     2 (015%)', '∑ Total:     13 (100%)')) {
    if (-not $statsOutput.Contains($text)) { throw "Framed stats field missing: $text" }
}
foreach ($text in @("$([char]27)[92m", "$([char]27)[91m", "$([char]27)[97m∑")) {
    if (-not $statsOutput.Contains($text)) { throw 'Framed stats severity color changed' }
}
$consoleOutput = [Console]::Out
$helpOutput = (@(Show-YafpHelp 6>&1) | ForEach-Object { "$_" }) -join "`n"
if (-not $helpOutput.Contains('┌') -or -not $helpOutput.Contains('┘') -or
    -not $helpOutput.Contains("$([char]27)[93myafp-status") -or
    -not $helpOutput.Contains('Show the latest RAM, swap, CPU, and disk sample.')) {
    throw 'Framed help lost its entries or command colors'
}
foreach ($dark in @(0, 1)) {
    $global:YAFP_DARKC = $dark
    $messageOutput = (@(Show-YafpMessages 6>&1) | ForEach-Object { "$_" }) -join "`n"
    if (-not $messageOutput.Contains('┌') -or -not $messageOutput.Contains('┘') -or
        -not $messageOutput.Contains("$([char]27)[0;48;2;255;255;0;38;2;0;0;0m(  PUSH PENDING: 1 )")) {
        throw 'Framed message catalog lost its warning colors'
    }
    $plain = $messageOutput -replace '\x1b\[[0-?]*[ -/]*[@-~]', ''
    $last = -1
    foreach ($fixtureLine in Get-Content (Join-Path $PSScriptRoot 'prompt_messages.txt')) {
        $message = $fixtureLine.Split('|', 2)[1]
        $position = $plain.IndexOf("( $message )")
        if ($position -le $last) { throw "Catalog message missing or out of order: $message" }
        $last = $position
    }
}
$capturedConsole = [IO.StringWriter]::new()
try {
    [Console]::SetOut($capturedConsole)
    Show-YafpStats -DirectConsole
}
finally { [Console]::SetOut($consoleOutput) }
$direct = $capturedConsole.ToString()
if (-not $direct.Contains('┌') -or -not $direct.Contains('┘') -or -not $direct.Contains('∑ Total:     13 (100%)')) {
    throw 'Exit statistics must use the same frame through the direct console writer'
}
foreach ($fixture in @(
    "$([char]27)[31m12345678901234567890$([char]27)[0m`n`$ "
    "`nabcdef$([char]27)[s$([char]27)[1A$([char]27)[3D$([char]27)[33mWARN$([char]27)[0m$([char]27)[uXYZ`n`$ "
    "abc$([char]27)[K`nA界e$([char]0x0301)`n`$ "
)) {
    $raw = (@(Write-YafpPreviewFrame -Text $fixture -Columns 20 6>&1) | ForEach-Object { "$_" }) -join "`n"
    if ($raw -match '\x1b\[(?:s|u|1A|K)') { throw 'Preview cursor controls escaped the canvas' }
    $plain = $raw -replace '\x1b\[[0-?]*[ -/]*[@-~]', ''
    foreach ($line in $plain -split "`n") {
        $length = 0
        foreach ($character in $line.ToCharArray()) { $length += Get-YafpPreviewCharacterWidth -CodePoint ([int]$character) }
        if ($length -ne 19) { throw "Preview frame width: $line" }
    }
    if (-not $plain.Contains('┌') -or -not $plain.Contains('┘')) { throw 'Preview borders are missing' }
    if ($fixture.Contains('WARN') -and (-not $plain.Contains('   WARN') -or -not $plain.Contains('abcdefXYZ'))) {
        throw 'Preview banner placement/cursor restore failed'
    }
    if ($fixture.Contains('123') -and (-not $plain.Contains('123456789012345') -or -not $plain.Contains('67890'))) {
        throw 'Preview wrapping lost text'
    }
    if ($fixture.StartsWith('abc') -and -not $plain.Contains('abc')) { throw 'Erase-to-end deleted preceding text' }
}
# Windows has concrete RawUI colors even when no background was requested.
# Reproduce that host state on every platform instead of relying on CI defaults.
$originalHostForeground = $Host.UI.RawUI.ForegroundColor
$originalHostBackground = $Host.UI.RawUI.BackgroundColor
try {
    $Host.UI.RawUI.ForegroundColor = [ConsoleColor]::Gray
    foreach ($hostBackground in @([ConsoleColor]::Black, [ConsoleColor]::DarkBlue)) {
        $Host.UI.RawUI.BackgroundColor = $hostBackground
        $records = @(Write-YafpText -Text 'transparent' -ForegroundColor Red -BackgroundColor $null -NoNewline 6>&1)
        if ($records.Count -ne 1 -or $records[0].MessageData.ForegroundColor -ne [ConsoleColor]::Red -or
            $null -ne $records[0].MessageData.BackgroundColor -or -not $records[0].MessageData.NoNewLine) {
            throw "Host background leaked into transparent text: $hostBackground"
        }
        $text = ConvertTo-YafpPreviewText -Records $records
        if ($text -ne "$([char]27)[91mtransparent$([char]27)[0m") {
            throw 'Transparent text must retain its requested color without inheriting the console background'
        }
        $records = @(Write-YafpText -Text 'explicit' -ForegroundColor Red -BackgroundColor Black 6>&1)
        if ($records.Count -ne 2 -or $records[0].MessageData.BackgroundColor -ne [ConsoleColor]::Black -or
            $records[1].MessageData.NoNewLine -or $null -ne $records[1].MessageData.BackgroundColor) {
            throw 'Explicit backgrounds and separate uncolored newlines must remain intact'
        }
        $statsOutput = (@(Show-YafpStats 6>&1) | ForEach-Object { "$_" }) -join "`n"
        foreach ($token in @("$([char]27)[92m", "$([char]27)[91m", "$([char]27)[97m∑")) {
            if (-not $statsOutput.Contains($token)) { throw "Stats inherited host background: $hostBackground" }
        }
    }
}
finally {
    $Host.UI.RawUI.ForegroundColor = $originalHostForeground
    $Host.UI.RawUI.BackgroundColor = $originalHostBackground
}
$records = @(Write-Host red -ForegroundColor Red -BackgroundColor DarkBlue -NoNewline 6>&1)
$text = ConvertTo-YafpPreviewText -Records $records
if (-not $text.Contains("$([char]27)[91;44mred")) { throw 'Captured preview colors were lost' }
$records = @(Write-YafpText -Text 'transparent' -ForegroundColor Red -BackgroundColor $null -NoNewline 6>&1)
$text = ConvertTo-YafpPreviewText -Records $records
if (-not $text.Contains("$([char]27)[91mtransparent") -or $text.Contains(';40m')) {
    throw 'Capturing a transparent background must not introduce black'
}
$tiny = (@(Write-YafpPreviewFrame -Text tiny -Columns 6 6>&1) | ForEach-Object { "$_" }) -join ''
if ($tiny -ne 'tiny') { throw 'Very narrow preview must fall back to plain rendering' }
Write-Output 'ok - PowerShell frames, compact countdowns, states, and existing colors across all themes'
