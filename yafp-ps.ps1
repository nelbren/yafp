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

if (-not (Get-Variable YAFP_REPOS -Scope Global -ErrorAction Ignore)) {
    $global:YAFP_REPOS = 1
}
if (-not (Get-Variable YAFP_PVENV -Scope Global -ErrorAction Ignore)) {
    $global:YAFP_PVENV = 1
}
if (-not (Get-Variable YAFP_ERROR -Scope Global -ErrorAction Ignore)) {
    $global:YAFP_ERROR = 1
}
if (-not (Get-Variable YAFP_THEME -Scope Global -ErrorAction Ignore)) {
    $global:YAFP_THEME = 'default'
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
    if ($NativeExitCode -ne 0) {
        return [pscustomobject]@{ HadError = $true; Code = $NativeExitCode }
    }

    return [pscustomobject]@{ HadError = $false; Code = 0 }
}

function Get-YafpVenvContext {
    if ($global:YAFP_PVENV -ne 1 -or -not $env:VIRTUAL_ENV) {
        return $null
    }
    return Split-Path $env:VIRTUAL_ENV -Leaf
}

function Get-YafpGitContext {
    if ($global:YAFP_REPOS -ne 1) {
        return $null
    }

    try {
        $null = git rev-parse --is-inside-work-tree 2>$null
        if ($LASTEXITCODE -ne 0) {
            return $null
        }

        $gitRepoUrl = git remote get-url origin 2>$null
        if ([string]::IsNullOrWhiteSpace($gitRepoUrl)) {
            $top = git rev-parse --show-toplevel 2>$null
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

Import-YafpTheme

function prompt {
    $previousSucceeded = $?
    $nativeExitCode = [int](Get-VarSafe 'LASTEXITCODE' 'Global' 0)
    $wasEmpty = Test-LastInputWasEmpty
    $status = Get-LastCommandStatus `
        -PreviousSucceeded $previousSucceeded `
        -NativeExitCode $nativeExitCode `
        -WasEmpty $wasEmpty

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $previousCommand = ''
    if (@(Get-History).Count -gt 0) {
        $previousCommand = (Get-History)[-1].CommandLine
    }

    $computerName = $env:COMPUTERNAME
    $context = [pscustomobject]@{
        User = $env:USERNAME
        Computer = $computerName
        Path = Get-YafpDisplayPath
        IsAdmin = Test-YafpAdministrator
        IsDevelopment = -not $computerName.StartsWith($global:PRO)
        Timestamp = $timestamp
        PreviousTimestamp = $script:previous_timestamp
        PreviousCommand = $previousCommand
        ExitCode = $status.Code
        HadError = $status.HadError
        DaySymbol = Get-YafpDaySymbol -Hour (Get-Date).Hour
        Git = Get-YafpGitContext
        Venv = Get-YafpVenvContext
    }

    $promptMark = Write-YafpTheme -Context $context
    $script:previous_timestamp = $timestamp
    $global:LASTEXITCODE = $nativeExitCode

    return "$promptMark "
}
