$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$env:YAFP_METRICS_DISABLED = '1'
. (Join-Path $PSScriptRoot '../yafp-ps.ps1')
$global:YAFP_CLOCK = 0; $global:YAFP_ERROR = 0
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
    ClockEnabled = $false; Development = $null; Git = $git; Venv = $null
    Resources = $null; Codex = $null; HadError = $false; ExitCode = 0
    PreviousTimestamp = ''; PreviousCommand = ''; Timestamp = ''; DaySymbol = ''
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
                $expected = if ($style -eq 'symbols') { '↦[⣦✓🌐︎]' } else { '↦[(175)✓🌐︎]' }
                if ($out.TrimEnd() -ne $expected) { throw "Remote frame mismatch: $theme/$style/$out" }
            }
            $git.RemoteStatus.RefreshIn = $null
            foreach ($case in @(
                @('no-commits', '○0'), @('no-upstream', '⇡?'), @('checking', '…'),
                @('ahead', '⇡2'), @('behind', '⇣3'), @('diverged', '⇡2⇣3'), @('error', '☒🌐︎')
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
            $gitIndicator = if ($theme -eq 'default') { 'ᚼ' } else { '' }
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
                foreach ($case in @(@('✓🌐︎', 'Green'), @('-1', 'Red'), @('±2', 'Yellow'), @('+3', 'Cyan'))) {
                    $token = @($script:frameWrites | Where-Object Text -EQ $case[0])
                    if ($token.Count -ne 1 -or $token[0].Foreground -ne $case[1] -or $null -ne $token[0].Background) {
                        throw "Token color changed: $($case[0])"
                    }
                }
            }
            finally { Set-Item Function:Write-YafpText -Value $writer }
        }
    }
}
finally { Set-Item Function:Write-YafpText -Value $writer }
Write-Output 'ok - PowerShell frames, compact countdowns, states, and existing colors across all themes'
