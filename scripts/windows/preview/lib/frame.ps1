# Helpers loaded only by on-demand diagnostic reports, outside interactive rendering.
function ConvertTo-YafpPreviewText {
    param([AllowEmptyCollection()][object[]]$Records)

    $text = [Text.StringBuilder]::new()
    $foreground = @(30, 34, 32, 36, 31, 35, 33, 37, 90, 94, 92, 96, 91, 95, 93, 97)
    foreach ($record in $Records) {
        if ($record -is [Management.Automation.InformationRecord] -and
            $record.MessageData -is [Management.Automation.HostInformationMessage]) {
            $message = $record.MessageData
            $codes = [Collections.Generic.List[int]]::new()
            $fg = if ($null -ne $message.ForegroundColor) { [int]$message.ForegroundColor } else { -1 }
            $bg = if ($null -ne $message.BackgroundColor) { [int]$message.BackgroundColor } else { -1 }
            if ($fg -ge 0 -and $fg -lt 16) { $codes.Add($foreground[$fg]) }
            if ($bg -ge 0 -and $bg -lt 16) { $codes.Add($foreground[$bg] + 10) }
            if ($codes.Count) { $null = $text.Append("$([char]27)[$($codes -join ';')m") }
            $null = $text.Append($message.Message).Append("$([char]27)[0m")
            if (-not $message.NoNewLine) { $null = $text.Append("`n") }
        }
        else { $null = $text.Append("$record").Append("`n") }
    }
    return $text.ToString()
}

function Get-YafpPreviewCharacterWidth {
    param([int]$CodePoint)

    if (($CodePoint -ge 0x0300 -and $CodePoint -le 0x036f) -or
        ($CodePoint -ge 0x1ab0 -and $CodePoint -le 0x1aff) -or
        ($CodePoint -ge 0x1dc0 -and $CodePoint -le 0x1dff) -or
        ($CodePoint -ge 0x20d0 -and $CodePoint -le 0x20ff) -or
        $CodePoint -eq 0x200d -or
        ($CodePoint -ge 0xfe00 -and $CodePoint -le 0xfe0f) -or
        ($CodePoint -ge 0xfe20 -and $CodePoint -le 0xfe2f)) { return 0 }
    if (($CodePoint -ge 0x1100 -and $CodePoint -le 0x115f) -or
        $CodePoint -in @(0x2329, 0x232a) -or
        ($CodePoint -ge 0x2e80 -and $CodePoint -le 0xa4cf) -or
        ($CodePoint -ge 0xac00 -and $CodePoint -le 0xd7a3) -or
        ($CodePoint -ge 0xf900 -and $CodePoint -le 0xfaff) -or
        ($CodePoint -ge 0xfe10 -and $CodePoint -le 0xfe19) -or
        ($CodePoint -ge 0xfe30 -and $CodePoint -le 0xfe6f) -or
        ($CodePoint -ge 0xff00 -and $CodePoint -le 0xff60) -or
        ($CodePoint -ge 0xffe0 -and $CodePoint -le 0xffe6) -or
        ($CodePoint -ge 0x1f300 -and $CodePoint -le 0x1faff)) { return 2 }
    return 1
}

function Write-YafpPreviewFrame {
    param([AllowEmptyString()][string]$Text, [int]$Columns = 0, [switch]$DirectConsole)

    $emit = {
        param([string]$Line, [bool]$UseConsole)
        if ($UseConsole) { [Console]::WriteLine($Line) }
        else { Write-Host $Line }
    }

    if ($Columns -le 0) {
        try { $Columns = $Host.UI.RawUI.WindowSize.Width }
        catch { $Columns = 80 }
    }
    if ($Columns -le 0) { $Columns = 80 }
    if ($Columns -lt 7) { & $emit $Text ([bool]$DirectConsole); return }
    $width = $Columns - 5
    $Text = $Text.TrimEnd("`r", "`n")
    $cells = @{}; $styles = @{}
    $row = 0; $column = 0; $maxRow = 0; $savedRow = 0; $savedColumn = 0
    $lastCell = -1; $style = ''; $index = 0
    $reset = "$([char]27)[0m"
    $borderStyle = if ($env:NO_COLOR) { '' } else { "$([char]27)[90m" }
    while ($index -lt $Text.Length) {
        $character = [string]$Text[$index]
        $index++
        if ($character -eq [string][char]27) {
            $remaining = $Text.Substring($index)
            if ($remaining -match '^\[([0-?]*[ -/]*)([@-~])') {
                $parameters = $Matches[1]; $final = $Matches[2]
                $sequence = "$([char]27)$($Matches[0])"
                $index += $Matches[0].Length
                if ($final -ceq 'm') {
                    if ($parameters -eq '' -or $parameters -match '^0(?:;|$)') { $style = $sequence }
                    else { $style += $sequence }
                    continue
                }
                if ($final -ceq 's') { $savedRow = $row; $savedColumn = $column; continue }
                if ($final -ceq 'u') { $row = $savedRow; $column = $savedColumn; continue }
                if ($parameters -notmatch '^\d*$') { continue }
                $amount = if ($parameters) { [int]$parameters } else { 0 }
                if ($final -eq 'K') {
                    $start = $column; $end = $width - 1
                    if ($amount -eq 1) { $start = 0; $end = $column }
                    elseif ($amount -eq 2) { $start = 0 }
                    for ($position = $start; $position -le $end -and $position -lt $width; $position++) {
                        $cell = $row * $width + $position
                        $cells.Remove($cell); $styles.Remove($cell)
                    }
                    continue
                }
                $amount = [Math]::Max(1, $amount)
                switch -CaseSensitive ($final) {
                    A { $row = [Math]::Max(0, $row - $amount) }
                    B { $row += $amount }
                    C { $column = [Math]::Min($width, $column + $amount) }
                    D { $column = [Math]::Max(0, $column - $amount) }
                    G { $column = [Math]::Min($width - 1, $amount - 1) }
                }
            }
            elseif ($remaining.StartsWith(']')) {
                # Strip titles and lifecycle controls from the static preview.
                $index++
                while ($index -lt $Text.Length) {
                    $character = $Text[$index]; $index++
                    if ($character -eq [char]7) { break }
                    if ($character -eq [char]27 -and $index -lt $Text.Length -and $Text[$index] -eq '\') {
                        $index++; break
                    }
                }
            }
            elseif ($remaining.StartsWith('(') -or $remaining.StartsWith(')')) { $index += 2 }
            else { $index++ }
            continue
        }
        if ($character -eq "`n") { $row++; $column = 0; continue }
        if ($character -eq "`r") { $column = 0; continue }
        if ($character -eq "`t") { $column = ([int][Math]::Floor($column / 8) + 1) * 8; continue }
        $code = [int][char]$character
        if ($code -lt 32) { continue }
        if ([char]::IsHighSurrogate($character[0]) -and $index -lt $Text.Length -and
            [char]::IsLowSurrogate($Text[$index])) {
            $character += $Text[$index]; $index++
            $code = [char]::ConvertToUtf32($character, 0)
        }
        $cellWidth = Get-YafpPreviewCharacterWidth -CodePoint $code
        if ($cellWidth -eq 0) {
            if ($lastCell -ge 0) { $cells[$lastCell] += $character }
            continue
        }
        if ($column + $cellWidth -gt $width) { $row++; $column = 0 }
        $cell = $row * $width + $column
        $cells[$cell] = $character; $styles[$cell] = $style; $lastCell = $cell
        if ($cellWidth -eq 2) { $cells[$cell + 1] = '' }
        $column += $cellWidth
        $maxRow = [Math]::Max($maxRow, $row)
    }
    $horizontal = '─' * ($width + 2)
    & $emit "${reset}${borderStyle}┌${horizontal}┐${reset}" ([bool]$DirectConsole)
    for ($row = 0; $row -le $maxRow; $row++) {
        $line = [Text.StringBuilder]::new()
        $null = $line.Append("${borderStyle}│${reset} ")
        $outputStyle = ''
        for ($column = 0; $column -lt $width; $column++) {
            $cell = $row * $width + $column
            if ($cells.ContainsKey($cell)) {
                if ($cells[$cell] -eq '') { continue }
                $style = $styles[$cell]
                if ($style -ne $outputStyle) {
                    $null = $line.Append($reset).Append($style); $outputStyle = $style
                }
                $null = $line.Append($cells[$cell])
            }
            else {
                if ($outputStyle) { $null = $line.Append($reset); $outputStyle = '' }
                $null = $line.Append(' ')
            }
        }
        $null = $line.Append("${reset} ${borderStyle}│${reset}")
        & $emit $line.ToString() ([bool]$DirectConsole)
    }
    & $emit "${borderStyle}└${horizontal}┘${reset}" ([bool]$DirectConsole)
}
