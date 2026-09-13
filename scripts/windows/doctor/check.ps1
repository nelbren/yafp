[CmdletBinding()]
param(
    [string]$ConfigPath,

    [switch]$Strict
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$rootDir = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
if (-not $ConfigPath) {
    $ConfigPath = Join-Path $rootDir 'yafp-cfg.ps1'
}
$passCount = 0
$warningCount = 0
$doctorErrorCount = 0
$script:doctorPrefix = ''

function Write-DoctorColor {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][ValidateSet(31, 32, 33)][int]$AnsiColor
    )

    if ($env:NO_COLOR -or [Console]::IsOutputRedirected) {
        Write-Host $Text
        return
    }

    $escape = [char]27
    Write-Host "$escape[$($AnsiColor)m$Text$escape[0m"
}

function Write-DoctorPass {
    param([Parameter(Mandatory)][string]$Message)

    $script:passCount++
    Write-DoctorColor "$($script:doctorPrefix)✅ $Message" 32
}

function Write-DoctorWarning {
    param([Parameter(Mandatory)][string]$Message)

    $script:warningCount++
    Write-DoctorColor "$($script:doctorPrefix)⚠️ $Message" 33
}

function Write-DoctorError {
    param([Parameter(Mandatory)][string]$Message)

    $script:doctorErrorCount++
    Write-DoctorColor "$($script:doctorPrefix)❌ $Message" 31
}

function Test-DoctorCommand {
    param(
        [Parameter(Mandatory)][string]$Name,
        [switch]$Required
    )

    if (Get-Command $Name -ErrorAction Ignore) {
        Write-DoctorPass "Command available: $Name"
    }
    elseif ($Required) {
        Write-DoctorError "Required command missing: $Name"
    }
    else {
        Write-DoctorWarning "Optional quality command missing: $Name"
    }
}

function Test-BinaryOption {
    param(
        [Parameter(Mandatory)][string]$Name,
        [AllowNull()][object]$Value
    )

    if ($Value -in @(0, 1)) {
        Write-DoctorPass "$Name is valid: $Value"
    }
    elseif ($null -eq $Value) {
        Write-DoctorWarning "$Name is not configured"
    }
    else {
        Write-DoctorError "$Name must be 0 or 1; found: $Value"
    }
}

function Get-ConfigurationValues {
    param([Parameter(Mandatory)][string]$Path)

    $tokens = $null
    $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile(
        $Path,
        [ref]$tokens,
        [ref]$parseErrors
    )
    if ($parseErrors.Count -gt 0) {
        Write-DoctorError "Invalid PowerShell configuration syntax: $Path"
        return $null
    }
    Write-DoctorPass 'PowerShell configuration syntax is valid'

    $values = @{}
    $configurationNames = @(
        'YAFP_DARKC',
        'YAFP_CLOCK',
        'YAFP_OSC133',
        'YAFP_REMOTE_CHECK_INTERVAL',
        'YAFP_DEVEL',
        'YAFP_THEME',
        'YAFP_REPOS',
        'YAFP_TITLE',
        'YAFP_ERROR',
        'YAFP_PVENV',
        'DEV',
        'PRO'
    )
    $assignments = $ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.AssignmentStatementAst]
    }, $true)
    foreach ($assignment in $assignments) {
        if ($assignment.Left -isnot
            [Management.Automation.Language.VariableExpressionAst]) {
            continue
        }
        $name = $assignment.Left.VariablePath.UserPath -replace '^global:', ''
        if ($name -notin $configurationNames) {
            continue
        }

        $literal = $assignment.Right.Extent.Text.Trim()
        if ($literal -match '^\d+$') {
            $values[$name] = [int]$literal
        }
        elseif ($literal -match "^'((?:[^']|'')*)'$" ) {
            $values[$name] = $matches[1] -replace "''", "'"
        }
        else {
            Write-DoctorWarning "$name cannot be evaluated statically"
        }
    }

    return $values
}

function Test-Configuration {
    $template = Join-Path $rootDir 'yafp-cfg.ps1.example'
    Write-Output '│   ├── 📄 yafp-cfg.ps1.example'
    $script:doctorPrefix = '│   │   └── '
    if (Test-Path -LiteralPath $template -PathType Leaf) {
        Write-DoctorPass 'Configuration template found'
    }
    else {
        Write-DoctorError 'Configuration template missing: yafp-cfg.ps1.example'
    }

    Write-Output "│   └── 📄 $ConfigPath"
    $script:doctorPrefix = '│       ├── '
    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        Write-DoctorWarning 'Personal configuration missing'
        $script:doctorPrefix = '│       └── '
        Write-DoctorWarning (
            'Create it with: Copy-Item yafp-cfg.ps1.example yafp-cfg.ps1'
        )
        return
    }
    Write-DoctorPass 'Personal configuration found'

    $values = Get-ConfigurationValues $ConfigPath
    if ($null -eq $values) {
        return
    }

    foreach ($name in @(
        'YAFP_DARKC',
        'YAFP_CLOCK',
        'YAFP_OSC133',
        'YAFP_DEVEL',
        'YAFP_REPOS',
        'YAFP_TITLE',
        'YAFP_ERROR',
        'YAFP_PVENV'
    )) {
        Test-BinaryOption $name $values[$name]
    }

    if ($values['DEV'] -is [string] -and $values['DEV'] -and
        $values['PRO'] -is [string] -and $values['PRO']) {
        Write-DoctorPass 'Development and production host prefixes are configured'
    }
    else {
        Write-DoctorError 'DEV and PRO host prefixes must be non-empty strings'
    }

    $interval = $values['YAFP_REMOTE_CHECK_INTERVAL']
    if ($interval -is [int] -and $interval -ge 0) {
        Write-DoctorPass "YAFP_REMOTE_CHECK_INTERVAL is valid: $interval"
    }
    else {
        Write-DoctorError (
            'YAFP_REMOTE_CHECK_INTERVAL must be a non-negative integer'
        )
    }

    $theme = $values['YAFP_THEME']
    $themePath = Join-Path $rootDir "themes/$theme.ps1"
    $script:doctorPrefix = '│       └── '
    if ($theme -and (Test-Path -LiteralPath $themePath -PathType Leaf)) {
        Write-DoctorPass "Configured PowerShell theme exists: $theme"
    }
    else {
        Write-DoctorError "Configured PowerShell theme not found: $theme"
    }
}

function Test-ThemePairs {
    $errorsBefore = $script:doctorErrorCount
    foreach ($file in Get-ChildItem (Join-Path $rootDir 'themes') -Filter '*.bash') {
        $counterpart = Join-Path $file.DirectoryName "$($file.BaseName).ps1"
        if (-not (Test-Path -LiteralPath $counterpart -PathType Leaf)) {
            Write-DoctorError (
                "PowerShell theme counterpart missing: $($file.BaseName).ps1"
            )
        }
    }
    foreach ($file in Get-ChildItem (Join-Path $rootDir 'themes') -Filter '*.ps1') {
        $counterpart = Join-Path $file.DirectoryName "$($file.BaseName).bash"
        if (-not (Test-Path -LiteralPath $counterpart -PathType Leaf)) {
            Write-DoctorError (
                "Bash theme counterpart missing: $($file.BaseName).bash"
            )
        }
    }
    if ($script:doctorErrorCount -eq $errorsBefore) {
        Write-DoctorPass 'Bash and PowerShell theme sets are paired'
    }
}

function Test-PowerShellProfile {
    $profiles = @(
        $PROFILE.CurrentUserAllHosts,
        $PROFILE.CurrentUserCurrentHost
    ) | Select-Object -Unique

    foreach ($profilePath in $profiles) {
        if ((Test-Path -LiteralPath $profilePath -PathType Leaf) -and
            (Select-String -LiteralPath $profilePath -SimpleMatch 'yafp-ps.ps1' -Quiet)) {
            Write-DoctorPass "PowerShell profile loads YAFP: $profilePath"
            return
        }
    }

    Write-DoctorWarning 'No PowerShell profile entry loading yafp-ps.ps1 was found'
}

Write-Output '🩺 YAFP Windows doctor'

Write-Output '├── 🖥️ Runtime'
$script:doctorPrefix = '│   ├── '
if ($IsWindows) {
    Write-DoctorPass 'Supported platform: Windows'
}
else {
    Write-DoctorError 'The PowerShell prompt is supported on Windows only'
}

$script:doctorPrefix = '│   └── '
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Write-DoctorPass "PowerShell version is supported: $($PSVersionTable.PSVersion)"
}
else {
    Write-DoctorError 'PowerShell 7 or newer is required'
}

Write-Output '├── 🔧 Commands'
$script:doctorPrefix = '│   ├── '
Test-DoctorCommand git -Required
Test-DoctorCommand shellcheck
Test-DoctorCommand markdownlint
$script:doctorPrefix = '│   └── '
if (Get-Module -ListAvailable -Name PSScriptAnalyzer) {
    Write-DoctorPass 'PowerShell module available: PSScriptAnalyzer'
}
else {
    Write-DoctorWarning 'Optional quality module missing: PSScriptAnalyzer'
}

Write-Output '├── 🧩 Prompt'
$script:doctorPrefix = '│   └── '
$entryPoint = Join-Path $rootDir 'yafp-ps.ps1'
if (Test-Path -LiteralPath $entryPoint -PathType Leaf) {
    Write-DoctorPass 'PowerShell prompt entry point found'
}
else {
    Write-DoctorError 'PowerShell prompt entry point missing: yafp-ps.ps1'
}

Write-Output '├── ⚙️ Configuration'
Test-Configuration

Write-Output '├── 🔗 Integration'
$script:doctorPrefix = '│   ├── '
Test-ThemePairs
$script:doctorPrefix = '│   └── '
Test-PowerShellProfile

Write-Output (
    "└── 🩺 Summary: $passCount passed, $warningCount warning(s), " +
    "$doctorErrorCount error(s)"
)

if ($doctorErrorCount -gt 0 -or ($Strict -and $warningCount -gt 0)) {
    exit 1
}
