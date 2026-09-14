# Yet Another Fancy Prompt for PowerShell
#
# v0.3.1 - 2026-09-12 - nelbren@nelbren.com
#
# Provides a themed prompt with Git and Python virtual environment information.

Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$cfg = Join-Path $ScriptDir 'yafp-cfg.ps1'
if (Test-Path -LiteralPath $cfg -PathType Leaf) {
    . $cfg
}

if (-not (Get-Variable DEV -Scope Global -ErrorAction Ignore)) {
    $global:DEV = 'ndev-'
}
if (-not (Get-Variable PRO -Scope Global -ErrorAction Ignore)) {
    $global:PRO = 'npro-'
}
if (-not (Get-Variable YAFP_REPOS -Scope Global -ErrorAction Ignore)) {
    $global:YAFP_REPOS = 1
}
if (-not (Get-Variable YAFP_PVENV -Scope Global -ErrorAction Ignore)) {
    $global:YAFP_PVENV = 1
}
if (-not (Get-Variable YAFP_ERROR -Scope Global -ErrorAction Ignore)) {
    $global:YAFP_ERROR = 1
}
if (-not (Get-Variable YAFP_TITLE -Scope Global -ErrorAction Ignore)) {
    $global:YAFP_TITLE = 1
}
if (-not (Get-Variable YAFP_DARKC -Scope Global -ErrorAction Ignore)) {
    $global:YAFP_DARKC = 1
}
if (-not (Get-Variable YAFP_CLOCK -Scope Global -ErrorAction Ignore)) {
    $global:YAFP_CLOCK = 1
}
if (-not (Get-Variable YAFP_OSC133 -Scope Global -ErrorAction Ignore)) {
    $global:YAFP_OSC133 = 1
}
if (-not (Get-Variable YAFP_THEME -Scope Global -ErrorAction Ignore)) {
    $global:YAFP_THEME = 'default'
}
if (-not (Get-Variable YAFP_REMOTE_CHECK_INTERVAL -Scope Global -ErrorAction Ignore)) {
    $global:YAFP_REMOTE_CHECK_INTERVAL = 300
}
if (-not (Get-Variable YAFP_REMOTE_COUNTDOWN_STYLE -Scope Global -ErrorAction Ignore)) {
    $global:YAFP_REMOTE_COUNTDOWN_STYLE = 'numeric'
}
if (-not (Get-Variable YAFP_STATUS_PROGRESS_STYLE -Scope Global -ErrorAction Ignore)) {
    $global:YAFP_STATUS_PROGRESS_STYLE = 'blocks'
}
if (-not (Get-Variable YAFP_DEVEL -Scope Global -ErrorAction Ignore)) {
    $global:YAFP_DEVEL = 0
}

function Write-YafpText {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text,
        [Parameter(Mandatory)]
        [string]$ForegroundColor,
        [AllowNull()]
        [object]$BackgroundColor,
        [switch]$NoNewline
    )

    $writeHostParams = @{
        Object = $Text
        ForegroundColor = $ForegroundColor
        NoNewline = $true
    }
    if (-not [string]::IsNullOrEmpty($BackgroundColor)) {
        $writeHostParams.BackgroundColor = $BackgroundColor
    }
    Write-Host @writeHostParams
    if (-not $NoNewline) {
        # Reset the colors before scrolling creates a new terminal row.
        Write-Host
    }
}

function Get-YafpOsc133Sequence {
    param([Parameter(Mandatory)][string]$Payload)

    if ($global:YAFP_OSC133 -ne 1) {
        return ''
    }

    return "$([char]27)]133;$Payload$([char]7)"
}

function Write-YafpOsc133Sequence {
    param([Parameter(Mandatory)][string]$Payload)

    $sequence = Get-YafpOsc133Sequence -Payload $Payload
    if ($sequence) {
        Write-Host $sequence -NoNewline
    }
}

function Get-YafpDisplayPath {
    $currentPath = "$(Get-Location)"
    $homePath = "$HOME".TrimEnd('\', '/')
    $comparison = [StringComparison]::OrdinalIgnoreCase

    if ($currentPath.Equals($homePath, $comparison)) {
        return '~'
    }

    if ($currentPath.Length -gt $homePath.Length -and
        $currentPath.StartsWith($homePath, $comparison)) {
        $separator = $currentPath[$homePath.Length]
        if ($separator -eq '\' -or $separator -eq '/') {
            return "~$($currentPath.Substring($homePath.Length))"
        }
    }

    return $currentPath
}

function Import-YafpTheme {
    $themeFile = Join-Path $ScriptDir "themes/$($global:YAFP_THEME).ps1"
    if (-not (Test-Path -LiteralPath $themeFile -PathType Leaf)) {
        $themeFile = Join-Path $ScriptDir 'themes/default.ps1'
    }
    if (-not (Test-Path -LiteralPath $themeFile -PathType Leaf)) {
        throw "YAFP theme file not found: $themeFile"
    }

    . $themeFile
}

if (-not (Get-Variable prevHistCount -Scope Script -ErrorAction Ignore)) {
    try {
        $script:prevHistCount = @(Get-History).Count
    }
    catch {
        $script:prevHistCount = 0
    }
}
if (-not (Get-Variable promptRan -Scope Script -ErrorAction Ignore)) {
    $script:promptRan = $false
}
if (-not (Get-Variable previous_timestamp -Scope Script -ErrorAction Ignore)) {
    $script:previous_timestamp = ''
}
if (-not (Get-Variable YafpInitialRemoteCheckPending `
        -Scope Script -ErrorAction Ignore)) {
    $script:YafpInitialRemoteCheckPending = $true
}

function Write-YafpDevelopmentMetrics {
    param(
        [Parameter(Mandatory)]
        [object]$Development
    )

    if ($Development.Total -lt 50) {
        $icon = '🚀'
        $color = 'Green'
    }
    elseif ($Development.Total -lt 200) {
        $icon = '⏱️'
        $color = 'Yellow'
    }
    else {
        $icon = '🐢'
        $color = 'Red'
    }

    $text = "$icon$($Development.Total)ms | " +
        "⚙️$($Development.General) " +
        "🌱$($Development.Git) " +
        "🐍$($Development.Venv) " +
        "❌$($Development.Error) " +
        "⚡$($Development.Timer)"
    Write-YafpText -Text $text -ForegroundColor $color -BackgroundColor $null
}
if (-not (Get-Variable YafpRemoteJobs -Scope Script -ErrorAction Ignore)) {
    $script:YafpRemoteJobs = @{}
}
if (-not (Get-Variable YafpRemoteCountdownColorIndex `
        -Scope Script -ErrorAction Ignore)) {
    $script:YafpRemoteCountdownColorIndex = 0
}

function Get-VarSafe {
    param($Name, $Scope, $Default)

    $variable = Get-Variable -Name $Name -Scope $Scope -ErrorAction Ignore
    if ($variable) {
        return $variable.Value
    }
    return $Default
}

function Test-LastInputWasEmpty {
    $cur = 0
    try {
        $cur = @(Get-History).Count
    }
    catch {
        $cur = 0
    }

    $justEnter = $script:promptRan -and ($cur -eq $script:prevHistCount)
    $script:prevHistCount = $cur
    $script:promptRan = $true
    return $justEnter
}

function Get-LastCommandStatus {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingEmptyCatchBlock',
        '',
        Justification = 'YAFP is an interactive prompt: unavailable history is optional context and must degrade silently instead of interrupting or adding noise to the console.'
    )]
    param(
        [bool]$PreviousSucceeded,
        [int]$NativeExitCode,
        [bool]$WasEmpty,
        [int]$DefaultInternalCode = 1
    )

    if ($WasEmpty) {
        return [pscustomobject]@{ HadError = $false; Code = 0 }
    }

    $lastId = $null
    try {
        $history = Get-History -Count 1 -ErrorAction Stop
        if ($history) {
            $lastId = $history.Id
        }
    }
    catch {}

    $errorForLastCommand = $null
    if ($lastId -and $Error.Count -gt 0) {
        foreach ($record in @($Error)) {
            if ($record -isnot [System.Management.Automation.ErrorRecord]) {
                continue
            }
            if ($record.InvocationInfo -and
                $record.InvocationInfo.HistoryId -ge 0 -and
                $record.InvocationInfo.HistoryId -eq $lastId) {
                $errorForLastCommand = $record
                break
            }
        }
    }

    if (-not $PreviousSucceeded) {
        $code = if ($NativeExitCode -ne 0) {
            $NativeExitCode
        }
        else {
            $DefaultInternalCode
        }
        return [pscustomobject]@{ HadError = $true; Code = $code }
    }
    if ($errorForLastCommand) {
        return [pscustomobject]@{ HadError = $true; Code = $DefaultInternalCode }
    }

    return [pscustomobject]@{ HadError = $false; Code = 0 }
}

function Get-YafpVenvContext {
    if ($global:YAFP_PVENV -ne 1 -or -not $env:VIRTUAL_ENV) {
        return $null
    }
    return Split-Path $env:VIRTUAL_ENV -Leaf
}

function Clear-YafpRemoteJobs {
    foreach ($key in @($script:YafpRemoteJobs.Keys)) {
        $knownJob = $script:YafpRemoteJobs[$key]
        if ($knownJob.State -in @('Completed', 'Failed', 'Stopped')) {
            Remove-Job -Job $knownJob -Force -ErrorAction Ignore
            $script:YafpRemoteJobs.Remove($key)
        }
    }
}

function Start-YafpRemoteCheck {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingEmptyCatchBlock',
        '',
        Justification = 'YAFP remote status is a best-effort background feature by design; worker failures must not block or write into the interactive prompt, and cleanup is handled by finally.'
    )]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$LocalRef,
        [Parameter(Mandatory)][string]$Upstream,
        [Parameter(Mandatory)][string]$RemoteName,
        [Parameter(Mandatory)][string]$CacheFile
    )

    Clear-YafpRemoteJobs

    if ($script:YafpRemoteJobs.ContainsKey($CacheFile)) {
        return
    }

    $lockDir = "$CacheFile.lock"
    if (Test-Path -LiteralPath $lockDir -PathType Container) {
        $staleAfter = [Math]::Max(
            [int]$global:YAFP_REMOTE_CHECK_INTERVAL * 2,
            600
        )
        $lockAge = ([DateTime]::UtcNow -
            (Get-Item -LiteralPath $lockDir).LastWriteTimeUtc).TotalSeconds
        if ($lockAge -lt $staleAfter) {
            return
        }
        Remove-Item -LiteralPath $lockDir -Force -ErrorAction Ignore
        if (Test-Path -LiteralPath $lockDir) {
            return
        }
    }

    $job = Start-Job -ScriptBlock {
        param($repoRoot, $localRef, $upstream, $remoteName, $cacheFile)

        $lockDir = "$cacheFile.lock"
        $hasLock = $false
        $tempFile = $null
        try {
            $null = New-Item -ItemType Directory -Path $lockDir `
                -ErrorAction Stop
            $hasLock = $true

            $env:GIT_TERMINAL_PROMPT = '0'
            $env:GIT_ASKPASS = ''
            $null = & git -C $repoRoot -c credential.interactive=never `
                fetch --quiet --no-tags -- $remoteName 2>$null
            $fetchSucceeded = $LASTEXITCODE -eq 0

            $ahead = 0
            $behind = 0
            $state = 'error'
            if ($fetchSucceeded) {
                $rawCounts = & git -C $repoRoot rev-list --left-right `
                    --count "$localRef...$upstream" 2>$null
                if ($LASTEXITCODE -eq 0 -and
                    "$rawCounts" -match '^\s*(\d+)\s+(\d+)\s*$') {
                    $ahead = [int]$Matches[1]
                    $behind = [int]$Matches[2]
                    if ($ahead -gt 0 -and $behind -gt 0) {
                        $state = 'diverged'
                    }
                    elseif ($behind -gt 0) {
                        $state = 'behind'
                    }
                    elseif ($ahead -gt 0) {
                        $state = 'ahead'
                    }
                    else {
                        $state = 'current'
                    }
                }
            }

            $currentOid = & git -C $repoRoot rev-parse $localRef 2>$null
            $checkedAt = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $line = @(
                $checkedAt
                $state
                $ahead
                $behind
                $localRef
                $upstream
                "$currentOid"
            ) -join "`t"

            $tempFile = "$cacheFile.$([guid]::NewGuid().ToString('N')).tmp"
            $encoding = [Text.UTF8Encoding]::new($false)
            [IO.File]::WriteAllText($tempFile, "$line`n", $encoding)
            Move-Item -LiteralPath $tempFile -Destination $cacheFile -Force
            $tempFile = $null
        }
        catch {}
        finally {
            if ($tempFile -and (Test-Path -LiteralPath $tempFile)) {
                Remove-Item -LiteralPath $tempFile -Force -ErrorAction Ignore
            }
            if ($hasLock) {
                Remove-Item -LiteralPath $lockDir -Force -ErrorAction Ignore
            }
        }
    } -ArgumentList $RepoRoot, $LocalRef, $Upstream, $RemoteName, $CacheFile

    $script:YafpRemoteJobs[$CacheFile] = $job
}

function Test-YafpGitSyncCommand {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingEmptyCatchBlock',
        '',
        Justification = 'YAFP treats command-history text that PowerShell cannot parse as a non-Git command by design, without surfacing parser noise in the prompt.'
    )]
    param([AllowEmptyString()][string]$CommandLine)

    if ([string]::IsNullOrWhiteSpace($CommandLine)) {
        return $false
    }

    try {
        $tokens = $null
        $parseErrors = $null
        $ast = [Management.Automation.Language.Parser]::ParseInput(
            $CommandLine,
            [ref]$tokens,
            [ref]$parseErrors
        )
        if ($parseErrors.Count -gt 0) {
            return $false
        }

        $commands = $ast.FindAll({
            param($node)
            $node -is [Management.Automation.Language.CommandAst]
        }, $true)

        foreach ($command in $commands) {
            if ($command.GetCommandName() -notin @('git', 'git.exe')) {
                continue
            }

            $elements = @($command.CommandElements | Select-Object -Skip 1)
            for ($index = 0; $index -lt $elements.Count; $index++) {
                $argument = $elements[$index].Extent.Text.Trim("'`"")
                if ($argument -in @(
                    '-C', '-c', '--git-dir', '--work-tree',
                    '--namespace', '--exec-path'
                )) {
                    $index++
                    continue
                }
                if ($argument.StartsWith('-')) {
                    continue
                }
                return $argument -in @('push', 'fetch', 'pull')
            }
        }
    }
    catch {}

    return $false
}

function Get-YafpRemoteContext {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingEmptyCatchBlock',
        '',
        Justification = 'YAFP is designed to keep rendering when optional remote cache reads or background checks fail; the remote state falls back to unavailable or error without polluting the console.'
    )]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Branch,
        [switch]$ForceRefresh
    )

    Clear-YafpRemoteJobs

    $interval = 0
    if (-not [int]::TryParse(
        "$global:YAFP_REMOTE_CHECK_INTERVAL",
        [ref]$interval
    ) -or $interval -le 0) {
        return $null
    }

    $localRef = git -C $RepoRoot symbolic-ref -q HEAD 2>$null
    $upstream = git -C $RepoRoot rev-parse --abbrev-ref `
        --symbolic-full-name '@{upstream}' 2>$null
    $remoteName = git -C $RepoRoot config --get `
        "branch.$Branch.remote" 2>$null
    if (-not $localRef -or -not $upstream -or
        -not $remoteName -or $remoteName -eq '.') {
        return $null
    }

    $gitDir = git -C $RepoRoot rev-parse --absolute-git-dir 2>$null
    $currentOid = git -C $RepoRoot rev-parse $localRef 2>$null
    if (-not $gitDir -or -not $currentOid) {
        return $null
    }

    $cacheFile = Join-Path "$gitDir" 'yafp-remote-status'
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $checkedAt = 0L
    $remoteContext = $null

    if (Test-Path -LiteralPath $cacheFile -PathType Leaf) {
        try {
            $fields = ([IO.File]::ReadAllText($cacheFile).TrimEnd()) -split "`t", 7
            if ($fields.Count -eq 7 -and
                [long]::TryParse($fields[0], [ref]$checkedAt) -and
                $fields[2] -match '^\d+$' -and $fields[3] -match '^\d+$' -and
                $fields[4] -eq "$localRef" -and
                $fields[5] -eq "$upstream" -and
                $fields[6] -eq "$currentOid") {
                $cacheAge = [Math]::Max(0L, $now - $checkedAt)
                $remoteContext = [pscustomobject]@{
                    State = $fields[1]
                    Ahead = [int]$fields[2]
                    Behind = [int]$fields[3]
                    Upstream = $fields[5]
                    CheckedAt = $checkedAt
                    Refreshing = $false
                    RefreshIn = [Math]::Max(
                        0L,
                        [long]$interval - $cacheAge
                    )
                }
            }
        }
        catch {}
    }

    if ($ForceRefresh -or -not $remoteContext -or
        ($now - $checkedAt) -ge $interval) {
        $checkRequested = $false
        try {
            Start-YafpRemoteCheck -RepoRoot $RepoRoot -LocalRef "$localRef" `
                -Upstream "$upstream" -RemoteName "$remoteName" `
                -CacheFile $cacheFile
            $checkRequested = $true
        }
        catch {}

        if (-not $remoteContext) {
            $remoteContext = [pscustomobject]@{
                State = if ($checkRequested) { 'checking' } else { 'error' }
                Ahead = 0
                Behind = 0
                Upstream = "$upstream"
                CheckedAt = 0L
                Refreshing = $false
                RefreshIn = $null
            }
        }
        elseif ($checkRequested) {
            $remoteContext.Refreshing = $true
            $remoteContext.RefreshIn = 0L
        }
    }

    return $remoteContext
}

function Format-YafpRemoteStateLabel {
    param(
        [AllowEmptyString()][string]$State,
        [int]$Ahead = 0,
        [int]$Behind = 0
    )

    switch ($State) {
        'current' { '✓ Up to date' }
        'ahead' { "⇡$Ahead Ahead" }
        'behind' { "⇣$Behind Behind" }
        'diverged' { "⇡$Ahead⇣$Behind Diverged" }
        'checking' { '… Checking' }
        'error' { '❕ No internet connection' }
        default { '— unavailable' }
    }
}

function Get-YafpRemoteStateColor {
    param([AllowEmptyString()][string]$State)

    switch ($State) {
        'current' { 'Green' }
        'error' { 'Red' }
        default { $null }
    }
}

function Get-YafpRemoteTimerStyle {
    param(
        [Parameter(Mandatory)][long]$Remaining,
        [Parameter(Mandatory)][int]$Interval
    )

    $remainingPercent = ([double]$Remaining * 100) / $Interval
    if ($remainingPercent -ge 66) {
        return [pscustomobject]@{ Emoji = '🟢'; Color = 'Green' }
    }
    if ($remainingPercent -ge 33) {
        return [pscustomobject]@{ Emoji = '🟡'; Color = 'Yellow' }
    }
    return [pscustomobject]@{ Emoji = '🔴'; Color = 'Red' }
}

function Get-YafpBrailleProgressSymbol {
    param([ValidateRange(1, 8)][int]$Level)

    return @('', '⡀', '⣀', '⣄', '⣤', '⣦', '⣶', '⣷', '⣿')[$Level]
}

function Get-YafpNextCheckColor {
    return 'Yellow'
}

function Get-YafpCurrentTimeColor {
    return 'White'
}

function Format-YafpRemoteStatusReport {
    param(
        [AllowEmptyString()][string]$State,
        [int]$Ahead = 0,
        [int]$Behind = 0,
        [bool]$Refreshing = $false,
        [AllowNull()][object]$Remaining,
        [int]$Interval,
        [long]$Now
    )

    $stateLabel = Format-YafpRemoteStateLabel -State $State `
        -Ahead $Ahead -Behind $Behind
    if ($Refreshing) {
        $stateLabel = "⟳ Refreshing · last: $stateLabel"
    }
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add("🌐       Remote: $stateLabel")

    $remainingSeconds = 0L
    if ($Interval -le 0 -or $null -eq $Remaining -or
        -not [long]::TryParse("$Remaining", [ref]$remainingSeconds) -or
        $remainingSeconds -lt 0 -or $Now -lt 0) {
        $lines.Add('⏱        Timer: unavailable')
        $lines.Add('🕘 Current time: unavailable')
        $lines.Add('🕒   Next check: unavailable')
        return $lines.ToArray()
    }

    $remainingSeconds = [Math]::Min($remainingSeconds, [long]$Interval)
    $timerStyle = Get-YafpRemoteTimerStyle `
        -Remaining $remainingSeconds -Interval $Interval
    $elapsed = [long]$Interval - $remainingSeconds
    $percent = [int][Math]::Round(
        ([double]$elapsed * 100) / $Interval,
        [MidpointRounding]::AwayFromZero
    )
    if ($global:YAFP_STATUS_PROGRESS_STYLE -eq 'symbols') {
        $progressUnits = [int][Math]::Round(
            ([double]$percent * 80) / 100,
            [MidpointRounding]::AwayFromZero
        )
        $filled = [Math]::Floor($progressUnits / 8)
        $partial = $progressUnits % 8
        $progress = '⣿' * $filled
        if ($partial -gt 0) {
            $progress += Get-YafpBrailleProgressSymbol -Level $partial
        }
        $progress += ' ' * (10 - $filled - [int]($partial -gt 0))
    }
    else {
        $filled = [int][Math]::Round(
            ([double]$percent * 10) / 100,
            [MidpointRounding]::AwayFromZero
        )
        $progress = ('█' * $filled) + ('░' * (10 - $filled))
    }
    $nextCheck = [DateTimeOffset]::FromUnixTimeSeconds(
        $Now + $remainingSeconds
    ).ToLocalTime().ToString('HH:mm:ss')
    $currentTime = [DateTimeOffset]::FromUnixTimeSeconds(
        $Now
    ).ToLocalTime().ToString('HH:mm:ss')

    $lines.Add(
        "$($timerStyle.Emoji)        Timer: $progress $percent% · " +
        "$elapsed/$($Interval)s elapsed · " +
        "$($remainingSeconds)s remaining"
    )
    $lines.Add("🕘 Current time: $currentTime")
    $lines.Add("🕒   Next check: $nextCheck")
    return $lines.ToArray()
}

function Write-YafpStatusReport {
    param(
        [AllowEmptyString()][string]$State,
        [int]$Ahead = 0,
        [int]$Behind = 0,
        [bool]$Refreshing = $false,
        [AllowNull()][object]$Remaining,
        [int]$Interval,
        [long]$Now
    )

    $report = @(Format-YafpRemoteStatusReport -State $State `
        -Ahead $Ahead -Behind $Behind -Refreshing $Refreshing `
        -Remaining $Remaining -Interval $Interval -Now $Now)
    $stateLabel = Format-YafpRemoteStateLabel -State $State `
        -Ahead $Ahead -Behind $Behind
    if ($Refreshing) {
        $stateLabel = "⟳ Refreshing · last: $stateLabel"
    }
    $stateColor = Get-YafpRemoteStateColor -State $State

    Write-Host '🌐       Remote: ' -NoNewline
    if ($stateColor) {
        Write-Host $stateLabel -ForegroundColor $stateColor
    }
    else {
        Write-Host $stateLabel
    }

    if ($report.Count -lt 4 -or $report[1] -notmatch '^(.+? Timer: )(.*)$') {
        $report | Select-Object -Skip 1 | Write-Host
        return
    }

    $timerPrefix = $Matches[1]
    $timerDetails = $Matches[2]
    Write-Host $timerPrefix -NoNewline
    $remainingSeconds = 0L
    if ($Interval -gt 0 -and $null -ne $Remaining -and
        [long]::TryParse("$Remaining", [ref]$remainingSeconds) -and
        $remainingSeconds -ge 0) {
        $remainingSeconds = [Math]::Min($remainingSeconds, [long]$Interval)
        $timerStyle = Get-YafpRemoteTimerStyle `
            -Remaining $remainingSeconds -Interval $Interval
        Write-Host $timerDetails -ForegroundColor $timerStyle.Color
    }
    else {
        Write-Host $timerDetails
    }
    if ($report[2] -match '^(🕘 Current time: )(\d{2}:\d{2}:\d{2})$') {
        Write-Host $Matches[1] -NoNewline
        Write-Host $Matches[2] -ForegroundColor (Get-YafpCurrentTimeColor)
    }
    else {
        Write-Host $report[2]
    }
    if ($report[3] -match '^(🕒   Next check: )(\d{2}:\d{2}:\d{2})$') {
        Write-Host $Matches[1] -NoNewline
        Write-Host $Matches[2] -ForegroundColor (Get-YafpNextCheckColor)
    }
    else {
        Write-Host $report[3]
    }
}

function Show-YafpStatus {
    $interval = 0
    $null = [int]::TryParse(
        "$global:YAFP_REMOTE_CHECK_INTERVAL",
        [ref]$interval
    )
    if (-not (Get-Command git -ErrorAction Ignore)) {
        Write-YafpStatusReport -State '' -Remaining $null `
            -Interval $interval -Now 0
        return
    }

    $top = git rev-parse --show-toplevel 2>$null
    $branch = git symbolic-ref --short HEAD 2>$null
    if (-not $top -or -not $branch) {
        Write-YafpStatusReport -State '' -Remaining $null `
            -Interval $interval -Now 0
        return
    }

    $remote = Get-YafpRemoteContext -RepoRoot "$top" -Branch "$branch"
    if (-not $remote) {
        Write-YafpStatusReport -State '' -Remaining $null `
            -Interval $interval -Now 0
        return
    }

    Write-YafpStatusReport -State $remote.State `
        -Ahead $remote.Ahead -Behind $remote.Behind `
        -Refreshing $remote.Refreshing -Remaining $remote.RefreshIn `
        -Interval $interval `
        -Now ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
}

function Invoke-YafpRefresh {
    if (-not (Get-Command git -ErrorAction Ignore)) {
        return
    }

    $top = git rev-parse --show-toplevel 2>$null
    $branch = git symbolic-ref --short HEAD 2>$null
    if (-not $top -or -not $branch) {
        return
    }

    $null = Get-YafpRemoteContext -RepoRoot "$top" -Branch "$branch" `
        -ForceRefresh
}

function Show-YafpDemo {
    $sleepSecs = 4
    while ($true) {
        Show-YafpStatus
        Write-Host "`nControl+C to break this ♾️  loop 🔁 ($($sleepSecs)s)`n"
        Start-Sleep -Seconds $sleepSecs
    }
}

function Write-YafpGitRemoteStatus {
    param([Parameter(Mandatory)][object]$Git)

    $remote = $Git.RemoteStatus
    if (-not $remote) {
        return
    }

    Write-Host ' ' -NoNewline

    if ($null -ne $remote.RefreshIn) {
        $countdown = Get-YafpRemoteCountdownIndicator `
            -Remaining $remote.RefreshIn
        if ($countdown) {
            Write-YafpText -Text "$countdown " `
                -ForegroundColor $script:YafpRemoteCountdownColor `
                -BackgroundColor $null -NoNewline
        }
    }

    if ($remote.Refreshing) {
        Write-YafpText -Text '⟳' -ForegroundColor Yellow `
            -BackgroundColor $null -NoNewline
    }

    $text = switch ($remote.State) {
        'current' { '✓' }
        'ahead' { "⇡$($remote.Ahead)" }
        'behind' { "⇣$($remote.Behind)" }
        'diverged' { "⇡$($remote.Ahead)⇣$($remote.Behind)" }
        'checking' { '…' }
        'error' { '❕' }
        default { '' }
    }
    if (-not $text) {
        return
    }

    if ($remote.State -in @('current', 'ahead')) {
        Write-YafpText -Text $text -ForegroundColor Green `
            -BackgroundColor $null -NoNewline
    }
    elseif ($remote.State -eq 'checking') {
        Write-YafpText -Text $text -ForegroundColor Yellow `
            -BackgroundColor $null -NoNewline
    }
    else {
        Write-YafpText -Text $text -ForegroundColor White `
            -BackgroundColor Red -NoNewline
    }
    Write-Host ' ' -NoNewline
}

function Get-YafpRemoteCountdownIndicator {
    param([Parameter(Mandatory)][long]$Remaining)

    $script:YafpRemoteCountdownColor = 'DarkGray'

    if ($global:YAFP_REMOTE_COUNTDOWN_STYLE -ne 'symbols') {
        return "($Remaining)"
    }

    $interval = 0
    if ($Remaining -lt 0 -or -not [int]::TryParse(
        "$global:YAFP_REMOTE_CHECK_INTERVAL",
        [ref]$interval
    ) -or $interval -le 0) {
        return "($Remaining)"
    }

    if ($Remaining -eq 0) {
        return ''
    }

    $level = [int][Math]::Min(
        8,
        [Math]::Ceiling(([double]$Remaining * 8) / $interval)
    )
    $script:YafpRemoteCountdownColor = switch (
        $script:YafpRemoteCountdownColorIndex
    ) {
        0 { 'White' }
        1 { 'Gray' }
        default { 'DarkGray' }
    }
    $script:YafpRemoteCountdownColorIndex = (
        $script:YafpRemoteCountdownColorIndex + 1
    ) % 3
    return @('', '⡀', '⣀', '⣄', '⣤', '⣦', '⣶', '⣷', '⣿')[$level]
}

function Write-YafpRemoteWarning {
    param([Parameter(Mandatory)][object]$Context)

    if (-not $Context.Git -or -not $Context.Git.RemoteStatus) {
        return
    }

    $remote = $Context.Git.RemoteStatus
    $symbol = '🚨'
    $trailingSymbol = '🚨'
    $foreground = 'White'
    $background = 'DarkRed'
    if ($remote.State -eq 'ahead') {
        $unit = if ($remote.Ahead -eq 1) { 'commit' } else { 'commits' }
        $verb = if ($remote.Ahead -eq 1) { 'has' } else { 'have' }
        $message = "REMOTE NOT UPDATED: $($remote.Ahead) local $unit $verb not been pushed to $($remote.Upstream)"
        $symbol = '⚠️'
        $trailingSymbol = '⚠️'
        $foreground = 'Yellow'
        $background = $null
    }
    elseif ($remote.State -eq 'behind') {
        $unit = if ($remote.Behind -eq 1) { 'commit' } else { 'commits' }
        $verb = if ($remote.Behind -eq 1) { 'is missing' } else { 'are missing' }
        $message = "OUTDATED REPOSITORY: $($remote.Behind) $unit $verb from $($remote.Upstream)"
    }
    elseif ($remote.State -eq 'diverged') {
        $message = "DIVERGED REPOSITORY: local +$($remote.Ahead) / remote +$($remote.Behind) relative to $($remote.Upstream)"
    }
    elseif ($remote.State -eq 'error') {
        $message = 'No internet connection.'
        $symbol = '⚡️'
        $trailingSymbol = ''
    }
    else {
        return
    }

    $suffix = if ($trailingSymbol) { " $trailingSymbol" } else { '' }
    Write-YafpText -Text "$symbol $message$suffix" `
        -ForegroundColor $foreground -BackgroundColor $background
}

function Get-YafpGitContext {
    param([switch]$ForceRemoteRefresh)

    if ($global:YAFP_REPOS -ne 1) {
        return $null
    }

    try {
        $null = git rev-parse --is-inside-work-tree 2>$null
        if ($LASTEXITCODE -ne 0) {
            return $null
        }

        $effectiveForceRefresh = (
            $ForceRemoteRefresh -or $script:YafpInitialRemoteCheckPending
        )
        $script:YafpInitialRemoteCheckPending = $false

        $top = git rev-parse --show-toplevel 2>$null
        $gitRepoUrl = git remote get-url origin 2>$null
        if ([string]::IsNullOrWhiteSpace($gitRepoUrl)) {
            $repo = Split-Path $top -Leaf
            $remote = 'local'
        }
        else {
            $lastPart = $gitRepoUrl -split '[\\/]' | Select-Object -Last 1
            $repo = $lastPart -replace '\.git$', ''
            if (-not $repo) {
                $repo = 'unknown'
            }
            $remote = 'remote'
        }

        $branch = git symbolic-ref --short HEAD 2>$null
        if (-not $branch) {
            $branch = git rev-parse --short HEAD 2>$null
        }

        $lastGitTimestamp = git log -1 `
            --date=format:'%Y-%m-%d %H:%M:%S' `
            --pretty=format:%cd 2>$null

        $gitStatus = git status --porcelain 2>$null
        if ($LASTEXITCODE -ne 0) {
            return $null
        }

        $remoteStatus = Get-YafpRemoteContext -RepoRoot "$top" `
            -Branch "$branch" -ForceRefresh:$effectiveForceRefresh

        $delete = 0
        $change = 0
        $new = 0
        foreach ($raw in @($gitStatus)) {
            $line = "$raw".TrimEnd()
            if ($line.Length -lt 2) {
                continue
            }
            if ($line.StartsWith('??')) {
                $new++
                continue
            }

            $indexState = $line[0]
            $workTreeState = $line[1]
            if ($indexState -eq 'D' -or $workTreeState -eq 'D') {
                $delete++
                continue
            }
            if ($indexState -eq 'M' -or $workTreeState -eq 'M') {
                $change++
            }
        }

        return [pscustomobject]@{
            Repository = $repo
            Branch = $branch
            Remote = $remote
            LastTimestamp = $lastGitTimestamp
            DeleteCount = $delete
            ChangeCount = $change
            NewCount = $new
            RemoteStatus = $remoteStatus
        }
    }
    catch {
        return $null
    }
}

function Get-YafpDaySymbol {
    param([int]$Hour)

    if ($Hour -gt 6 -and $Hour -lt 12) {
        return '🌅'
    }
    if ($Hour -ge 12 -and $Hour -lt 18) {
        return '🌇'
    }
    return '🌃'
}

function Test-YafpAdministrator {
    return ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent() `
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

Set-Alias -Name yafp-status -Value Show-YafpStatus -Scope Global -Force
Set-Alias -Name yafp-refresh -Value Invoke-YafpRefresh -Scope Global -Force
Set-Alias -Name yafp-demo -Value Show-YafpDemo -Scope Global -Force

Import-YafpTheme

function prompt {
    $previousSucceeded = $?
    $nativeExitCode = [int](Get-VarSafe 'LASTEXITCODE' 'Global' 0)
    $hadPreviousPrompt = $script:promptRan

    $developmentEnabled = $global:YAFP_DEVEL -eq 1
    if ($developmentEnabled) {
        $totalTimer = [Diagnostics.Stopwatch]::StartNew()
        $errorTimer = [Diagnostics.Stopwatch]::StartNew()
    }
    $wasEmpty = Test-LastInputWasEmpty
    $status = Get-LastCommandStatus `
        -PreviousSucceeded $previousSucceeded `
        -NativeExitCode $nativeExitCode `
        -WasEmpty $wasEmpty
    if ($developmentEnabled) {
        $errorTimer.Stop()
        $generalTimer = [Diagnostics.Stopwatch]::StartNew()
    }

    $clockEnabled = $global:YAFP_CLOCK -eq 1
    if ($clockEnabled) {
        $now = Get-Date
        $timestamp = $now.ToString('yyyy-MM-dd HH:mm:ss')
        $daySymbol = Get-YafpDaySymbol -Hour $now.Hour
    }
    else {
        $timestamp = ''
        $daySymbol = ''
    }
    $previousCommand = ''
    if (@(Get-History).Count -gt 0) {
        $previousCommand = (Get-History)[-1].CommandLine
    }
    $forceRemoteRefresh = (
        -not $wasEmpty -and
        -not $status.HadError -and
        (Test-YafpGitSyncCommand -CommandLine $previousCommand)
    )

    $computerName = $env:COMPUTERNAME
    $displayPath = Get-YafpDisplayPath
    $isAdmin = Test-YafpAdministrator
    if ($developmentEnabled) {
        $generalTimer.Stop()
        $gitTimer = [Diagnostics.Stopwatch]::StartNew()
    }
    $gitContext = Get-YafpGitContext -ForceRemoteRefresh:$forceRemoteRefresh
    if ($developmentEnabled) {
        $gitTimer.Stop()
        $venvTimer = [Diagnostics.Stopwatch]::StartNew()
    }
    $venvContext = Get-YafpVenvContext
    if ($developmentEnabled) {
        $venvTimer.Stop()
        $totalTimer.Stop()

        $totalMilliseconds = [int]$totalTimer.Elapsed.TotalMilliseconds
        $generalMilliseconds = [int]$generalTimer.Elapsed.TotalMilliseconds
        $gitMilliseconds = [int]$gitTimer.Elapsed.TotalMilliseconds
        $venvMilliseconds = [int]$venvTimer.Elapsed.TotalMilliseconds
        $errorMilliseconds = [int]$errorTimer.Elapsed.TotalMilliseconds
        $timerMilliseconds = [Math]::Max(
            0,
            $totalMilliseconds - $generalMilliseconds - $gitMilliseconds -
                $venvMilliseconds - $errorMilliseconds
        )
        $development = [pscustomobject]@{
            Total = $totalMilliseconds
            General = $generalMilliseconds
            Git = $gitMilliseconds
            Venv = $venvMilliseconds
            Error = $errorMilliseconds
            Timer = $timerMilliseconds
        }
    }
    else {
        $development = $null
    }

    $context = [pscustomobject]@{
        User = $env:USERNAME
        Computer = $computerName
        Path = $displayPath
        IsAdmin = $isAdmin
        IsDevelopment = -not $computerName.StartsWith($global:PRO)
        Timestamp = $timestamp
        PreviousTimestamp = $script:previous_timestamp
        PreviousCommand = $previousCommand
        ExitCode = $status.Code
        HadError = $status.HadError
        ClockEnabled = $clockEnabled
        DaySymbol = $daySymbol
        Git = $gitContext
        Venv = $venvContext
        Development = $development
    }

    if ($global:YAFP_OSC133 -eq 1) {
        if ($hadPreviousPrompt) {
            if ($wasEmpty) {
                Write-YafpOsc133Sequence -Payload 'D'
            }
            else {
                Write-YafpOsc133Sequence -Payload "D;$($status.Code)"
            }
        }
        Write-YafpOsc133Sequence -Payload 'A'
    }

    $promptMark = Write-YafpTheme -Context $context
    $script:previous_timestamp = if ($clockEnabled) { $timestamp } else { '' }
    $global:LASTEXITCODE = $nativeExitCode

    $promptEnd = Get-YafpOsc133Sequence -Payload 'B'
    return "$promptMark $promptEnd"
}
