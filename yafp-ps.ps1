# Yet Another Fancy Prompt for PowerShell
#
# v0.2.2 - 2025-08-10 - nelbren@nelbren.com
#
# Provides a colored prompt with git and Python virtual environment information.

Set-StrictMode -Version Latest

# Load optional configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$cfg = Join-Path $ScriptDir 'yafp-cfg.ps1'
if (Test-Path $cfg) {
    . $cfg
}

if (-not (Get-Variable YAFP_REPOS -Scope Global -ErrorAction SilentlyContinue)) {
    $global:YAFP_REPOS = 1
}
if (-not (Get-Variable YAFP_PVENV -Scope Global -ErrorAction SilentlyContinue)) {
    $global:YAFP_PVENV = 1
}

# Inicialización segura (solo la primera vez)
if (-not (Get-Variable -Name prevHistCount -Scope Script -ErrorAction SilentlyContinue)) {
    try { $script:prevHistCount = (Get-History).Count } catch { $script:prevHistCount = 0 }
}
if (-not (Get-Variable -Name promptRan -Scope Script -ErrorAction SilentlyContinue)) {
    $script:promptRan = $false
}

# Detectar si PSStyle está disponible (solo en PowerShell 7+)
$script:HasPSStyle = $false
try {
    if ($PSVersionTable.PSEdition -eq 'Core' -and (Get-Variable PSStyle -ErrorAction Stop)) {
        $script:HasPSStyle = $true
    }
} catch {}
function Get-YafpVenv {
    try {
        if ($global:YAFP_PVENV -eq 1 -and $env:VIRTUAL_ENV) {
            return "[🐍$(Split-Path $env:VIRTUAL_ENV -Leaf)]"
        }
        return ""
    }
    catch {
        return ""
    }
}

function Get-YafpGit {
    try {
        # ¿Estamos en un repo git?
        $null = git -C . rev-parse 1>$null 2>$null
        if ($LASTEXITCODE -eq 128) {
            return ""
        }

        # Repo / remoto
        $gitRepoUrl = git remote get-url origin 2>$null
        if ([string]::IsNullOrWhiteSpace($gitRepoUrl)) {
            $top = git rev-parse --show-toplevel 2>$null
            $repo = Split-Path $top -Leaf
            $remo = "⇣"
        }
        else {
            $lastPart = ($gitRepoUrl -split '[\\/]' | Select-Object -Last 1)
            $repo = ($lastPart -replace '\.git$','')
            if (-not $repo) { $repo = "unknown" }
            $remo = "⚡"
        }

        # Branch
        $branch = git symbolic-ref --short HEAD 2>$null
        if (-not $branch) { $branch = git rev-parse --short HEAD 2>$null }

        # Último commit: timestamp
        $lastGitTS = git log -1 `
            --date=format:'%Y-%m-%d %H:%M:%S' `
            --pretty=format:%cd 2>$null

        # Cambios
        $gitstatus = git status --porcelain 2>$null
        if ($LASTEXITCODE -ne 0) { return "" }

        $delete = 0; $change = 0; $new = 0
        foreach ($raw in ($gitstatus -split "`n")) {
            $line = $raw.TrimEnd()
            if ($line.Length -lt 2) { continue }
            if ($line.StartsWith("??")) { $new++; continue }
            $i = $line[0]; $w = $line[1]
            if ($i -eq 'D' -or $w -eq 'D') { $delete++; continue }
            if ($i -eq 'M' -or $w -eq 'M') { $change++; continue }
        }

        # Símbolos
        $symbols = ""
        if ($delete -gt 0) { $symbols += "-$delete🟥" }
        if ($change -gt 0) { $symbols += "±$change🟨" }
        if ($new    -gt 0) { $symbols += "+$new🟦" }
        if ($symbols -eq "") { $symbols = "✅≡" }

        # Segmento final
        return "[🔛$lastGitTS💾${repo}ᚼ$branch💻$remo📁$symbols]"
    }
    catch {
        return ""
    }
}

function Get-VarSafe {
    param($Name, $Scope, $Default)
    if (Get-Variable -Name $Name -Scope $Scope -ErrorAction SilentlyContinue) {
        Get-Variable -Name $Name -Scope $Scope -ValueOnly
    }
    else {
        $Default
    }
}
function Test-LastInputWasEmpty {
    # Devuelve $true si el usuario solo presionó Enter sin comando
    $cur = 0
    try { $cur = (Get-History).Count } catch { $cur = 0 }
    $justEnter = $script:promptRan -and ($cur -eq $script:prevHistCount)
    $script:prevHistCount = $cur
    $script:promptRan = $true
    return $justEnter
}

function Ansi { param([string]$s) "$([char]27)[$s" }
function Get-LastCommandStatus {
    param([int]$defaultInternalCode = 1)
    # Write-Host "001"  -ForegroundColor Black -BackgroundColor Yellow

    # $origLast = if ($null -ne $global:LASTEXITCODE) { $global:LASTEXITCODE } else { 0 }
    #$origLast = Get-VarSafe "LASTEXITCODE" "Global" 0

    $prevOk   = $?
    $hadError = $false
    $code     = 0
    # Write-Host "002"  -ForegroundColor Black -BackgroundColor Yellow

    # Último HistoryId (puede no existir al inicio)
    $lastId = $null
    try {
        $h = Get-History -Count 1 -ErrorAction Stop
        if ($h) { $lastId = $h.Id }
    } catch {
        Write-Host "Catch 1 EX: $($_.Exception.Message)" -ForegroundColor White -BackgroundColor Red
    }

    # Buscar error NO terminante del ÚLTIMO comando
    $errForLastCmd = $null
    if ($lastId -and $Error.Count -gt 0) {
        foreach ($e in @($Error)) {
            if ($e -isnot [System.Management.Automation.ErrorRecord]) { continue }
            $inv = $e.InvocationInfo
            if ($null -eq $inv) { continue }
            # HistoryId puede ser -1 cuando no hay vínculo válido
            # Write-Host "${inv} $lastId"  -ForegroundColor Black -BackgroundColor Yellow
            try {
                if ($inv.HistoryId -ge 0 -and $inv.HistoryId -eq $lastId) {
                    $errForLastCmd = $e
                    break
                }
            } catch {
                Write-Host "Catch 2 EX: $($_.Exception.Message)" -ForegroundColor White -BackgroundColor Red
            }
        }
    }

    # Write-Host "($prevOK) ($errForLastCmd) ($origLast)" -ForegroundColor White -BackgroundColor Red

    if (-not $prevOk -and -not $wasEmpty) {
        # Error terminante (interno o externo)
        # Write-Host "CASO 1"  -ForegroundColor Black -BackgroundColor Yellow
        $hadError = $true
        $code = if ($origLast -ne 0) { $origLast } else { $defaultInternalCode }
    }
    elseif ($errForLastCmd -and -not $wasEmpty) {
        # Error NO terminante del último cmdlet (p.ej. dir noexiste)
        # Write-Host "CASO 2"  -ForegroundColor Black -BackgroundColor Yellow
        $hadError = $true
        $code = $defaultInternalCode
    }
    elseif ($origLast -ne 0) {
        # Error de comando externo
        # Write-Host "CASO 3"  -ForegroundColor Black -BackgroundColor Yellow
        $hadError = $true
        $code = $origLast
    }

    [pscustomobject]@{
        HadError = $hadError
        Code     = $code
        LastCode = $origLast
    }
}

function prompt {
    $wasEmpty = Test-LastInputWasEmpty
    $origLast = Get-VarSafe "LASTEXITCODE" "Global" 0
    if ($wasEmpty) {
        $origLast = 0
    }
    # Write-Host "origLast -> $origLast"  -ForegroundColor Black -BackgroundColor Yellow
    $status = Get-LastCommandStatus
    # Write-Host "status -> $status"  -ForegroundColor Black -BackgroundColor Yellow
    if ($status.HadError) {
        if ($status.Code -eq 0) {
            $last = 1
        } else {
            $last = $status.Code
        }
    } else {
        $last = 0
    }
    $script:previous_timestamp = Get-VarSafe "timestamp" "Script" ""
    $script:timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $hour = (Get-Date).Hour
    $user = $env:USERNAME
    $comp = $env:COMPUTERNAME
    $dev = if ($env:COMPUTERNAME.StartsWith($PRO)) { 0 } else { 1 }
    $path = Get-Location

    $venv = ""
    if ($global:YAFP_PVENV -eq 1 -and $env:VIRTUAL_ENV) {
        $venv = Get-YafpVenv
        if ($venv) { 
            Write-Host "$venv" -ForegroundColor White -BackgroundColor Blue -NoNewline
        }
    }

    $git = ""
    if ($global:YAFP_REPOS -eq 1) {
        $git = Get-YafpGit
        if ($git) { 
            Write-Host "$git" -ForegroundColor Black -BackgroundColor Gray
        }
    }

    $previous_command = ""
    if ((Get-History).Count -gt 0) {
        $previous_command = (Get-History)[-1].CommandLine

    } 

    if ($last -ne 0) {
        Write-Host "[" -ForegroundColor Black -BackgroundColor Red -NoNewline
        Write-Host "🔚${previous_timestamp}🚀" -ForegroundColor Black -BackgroundColor Red -NoNewline
        Write-Host "$previous_command→⚠️" -ForegroundColor Black -BackgroundColor Red -NoNewline
        Write-Host "$last" -ForegroundColor Yellow -BackgroundColor Red -NoNewline
        Write-Host "]" -ForegroundColor Black -BackgroundColor Red -NoNewline
    } else {
        Write-Host "[" -ForegroundColor Black -BackgroundColor Green -NoNewline
        Write-Host "🔚${previous_timestamp}🚀" -ForegroundColor Black -BackgroundColor Green -NoNewline
        Write-Host "$previous_command" -ForegroundColor Black -BackgroundColor Green -NoNewline
        Write-Host "→✅" -ForegroundColor Black -BackgroundColor Green -NoNewline
        Write-Host "]" -ForegroundColor Black -BackgroundColor Green -NoNewline
    }

    if ($hour -gt 6 -and $hour -lt 12) {
        $day = "🌇"
    }
    elseif ($hour -ge 12 -and $hour -lt 18) {
        $day = "🌆"
    }
    else {
        $day = "🌃"
    }

    $isAdmin = ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent() `
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    Write-Host "[🔜$script:timestamp$day]" -ForegroundColor Black -BackgroundColor Cyan # -NoNewline

    Write-Host "[" -ForegroundColor White -NoNewline
    if ($isAdmin) {
        Write-Host "$user" -ForegroundColor White -BackgroundColor Red -NoNewline
        $promptMark='#'
    } else {
        Write-Host "$user" -ForegroundColor Black -BackgroundColor Cyan -NoNewline
        $promptMark='$'
    }
    Write-Host "@" -ForegroundColor White -NoNewline
    if ($dev -eq 1) {
        Write-Host "$comp" -ForegroundColor Black -BackgroundColor Green -NoNewline
    } else {
        Write-Host "$comp" -ForegroundColor Black -BackgroundColor Magenta -NoNewline
    }

    Write-Host ":" -ForegroundColor White -NoNewline
    Write-Host "$path" -ForegroundColor Black -BackgroundColor Yellow -NoNewline
    Write-Host "]" -ForegroundColor White -BackgroundColor Black -NoNewline
    # Fixing color bug in last line
    Write-Host "$(Ansi '106m')$(Ansi '30m')$(Ansi '0m')$(Ansi '0K')" -NoNewline

    $global:LASTEXITCODE = $origLast

    return "$promptMark "
}
