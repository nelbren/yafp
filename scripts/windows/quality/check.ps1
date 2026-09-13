$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$rootDir = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$requireLinters = $env:YAFP_REQUIRE_LINTERS -eq '1'

function Write-QualityLine {
    param([AllowNull()][object]$Line)

    $text = "$Line"
    if ($text.StartsWith('ok - ')) {
        Write-Host "✅ $($text.Substring(5))" -ForegroundColor Green
        return
    }
    if ($text.StartsWith('not ok - ')) {
        Write-Host "❌ $($text.Substring(9))" -ForegroundColor Red
        return
    }
    if ($text.StartsWith('error - ')) {
        Write-Host "❌ $($text.Substring(8))" -ForegroundColor Red
        return
    }

    Write-Output $Line
}

function Write-QualityWarning {
    param([Parameter(Mandatory)][string]$Message)

    Write-Host "⚠️ $Message" -ForegroundColor Yellow
}

function Write-QualityError {
    param([Parameter(Mandatory)][string]$Message)

    Write-Host "❌ $Message" -ForegroundColor Red
}

Push-Location $rootDir
try {
    & pwsh -NoProfile -File scripts/windows/setup/quality.ps1 -DryRun |
        Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Windows quality setup plan failed'
    }
    Write-QualityLine 'ok - Windows quality setup plan'

    & pwsh -NoProfile -File scripts/windows/doctor/check.ps1 `
        -ConfigPath yafp-cfg.ps1.example | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Windows environment doctor failed'
    }
    Write-QualityLine 'ok - Windows environment doctor'

    $files = @(
        Get-ChildItem -File -Recurse |
            Where-Object Extension -In @('.ps1', '.psd1')
    )
    foreach ($file in $files) {
        $tokens = $null
        $errors = $null
        $null = [Management.Automation.Language.Parser]::ParseFile(
            $file.FullName,
            [ref]$tokens,
            [ref]$errors
        )
        if ($errors.Count -gt 0) {
            $messages = $errors.Message -join [Environment]::NewLine
            throw "$($file.FullName):$([Environment]::NewLine)$messages"
        }
    }
    Write-QualityLine "ok - parsed $($files.Count) PowerShell files"

    foreach ($test in @(
        'tests/powershell_status_test.ps1'
        'tests/powershell_devel_test.ps1'
        'tests/powershell_theme_loading_test.ps1'
        'tests/osc133_test.ps1'
        'tests/remote_status_test.ps1'
    )) {
        & pwsh -NoProfile -File $test 2>&1 | ForEach-Object {
            Write-QualityLine $_
        }
        if ($LASTEXITCODE -ne 0) {
            throw "PowerShell test failed: $test"
        }
    }

    if (Get-Command Invoke-ScriptAnalyzer -ErrorAction Ignore) {
        $settings = Join-Path $rootDir '.PSScriptAnalyzerSettings.psd1'
        $issues = @(
            Invoke-ScriptAnalyzer -Path . -Recurse -Settings $settings
        )
        $errors = @($issues | Where-Object Severity -EQ 'Error')
        $warnings = @($issues | Where-Object Severity -EQ 'Warning')
        if ($warnings.Count -gt 0) {
            Write-QualityWarning (
                "PSScriptAnalyzer reported $($warnings.Count) warning(s):"
            )
            $warnings |
                Group-Object RuleName |
                Sort-Object Name |
                ForEach-Object {
                    Write-QualityWarning "$($_.Name): $($_.Count)"
                }
        }
        if ($errors.Count -gt 0) {
            $errors | Format-Table -AutoSize | Out-String | Write-Error
            throw "PSScriptAnalyzer reported $($errors.Count) error(s)"
        }
    }
    elseif ($requireLinters) {
        throw 'Required linter not found: PSScriptAnalyzer'
    }
    else {
        Write-QualityWarning 'Optional linter not found: PSScriptAnalyzer'
    }

    if (Get-Command markdownlint -ErrorAction Ignore) {
        & markdownlint '**/*.md'
        if ($LASTEXITCODE -ne 0) {
            throw 'markdownlint reported errors'
        }
    }
    elseif ($requireLinters) {
        throw 'Required linter not found: markdownlint'
    }
    else {
        Write-QualityWarning 'Optional linter not found: markdownlint'
    }

    Write-QualityLine 'ok - Windows quality checks'
}
catch {
    Write-QualityError $_.Exception.Message
    throw
}
finally {
    Pop-Location
}
