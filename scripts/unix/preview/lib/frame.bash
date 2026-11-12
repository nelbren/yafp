# Static terminal canvas for on-demand diagnostic reports (Bash and zsh).
# Cursor controls are interpreted inside the canvas, never sent outside it.
yafp_preview_character_width() {
    if [ -n "${ZSH_VERSION:-}" ]; then emulate -L zsh -o KSH_ARRAYS; fi
    local char="$1" code byte count offset
    printf -v code '%d' "'$char"
    if [ "$code" -lt 0 ]; then
        # macOS Bash 3.2 printf returns the signed first UTF-8 byte.
        local LC_ALL=C
        byte=$((code + 256))
        if [ "$byte" -ge 240 ]; then count=4; code=$((byte & 7))
        elif [ "$byte" -ge 224 ]; then count=3; code=$((byte & 15))
        else count=2; code=$((byte & 31))
        fi
        for ((offset=1; offset<count; offset++)); do
            printf -v byte '%d' "'${char: $offset:1}"
            code=$(((code << 6) | (byte & 63)))
        done
    fi
    yafp_preview_cell_width=1
    if ((
        (code >= 0x0300 && code <= 0x036f) ||
        (code >= 0x1ab0 && code <= 0x1aff) ||
        (code >= 0x1dc0 && code <= 0x1dff) ||
        (code >= 0x20d0 && code <= 0x20ff) || code == 0x200d ||
        (code >= 0xfe00 && code <= 0xfe0f) ||
        (code >= 0xfe20 && code <= 0xfe2f)
    )); then yafp_preview_cell_width=0
    elif ((
        (code >= 0x1100 && code <= 0x115f) || code == 0x2329 || code == 0x232a ||
        (code >= 0x2e80 && code <= 0xa4cf) || (code >= 0xac00 && code <= 0xd7a3) ||
        (code >= 0xf900 && code <= 0xfaff) || (code >= 0xfe10 && code <= 0xfe19) ||
        (code >= 0xfe30 && code <= 0xfe6f) || (code >= 0xff00 && code <= 0xff60) ||
        (code >= 0xffe0 && code <= 0xffe6) || (code >= 0x1f300 && code <= 0x1faff)
    )); then yafp_preview_cell_width=2
    fi
}

yafp_preview_frame() {
    if [ -n "${ZSH_VERSION:-}" ]; then emulate -L zsh -o KSH_ARRAYS; fi
    local text="$1" columns="${2:-${COLUMNS:-80}}" sizing="${3:-}" title="${4:-}"
    local row=0 column=0 saved_row=0 saved_column=0 last_cell=-1 max_row=0
    local index=0 end char next sequence params final amount target position
    local width frame_width cell_width code offset cell style='' output_style=''
    local border_style=$'\033[90m' reset=$'\033[0m'
    local title_length=-1 title_rows=0 title_style='' row_style horizontal=''
    local title_row_width left_padding
    local cells=() styles=()

    [[ "$columns" =~ ^[0-9]+$ ]] && [ "$columns" -gt 0 ] || columns=80
    if [ "$columns" -lt 7 ]; then
        [ -z "$title" ] || printf '%s\n' "$title"
        printf '%s\n' "$text"
        return
    fi
    width=$((columns - 5))
    [ -z "${NO_COLOR:-}" ] || border_style=''
    while [[ "$text" == *$'\n' ]]; do text=${text%$'\n'}; done
    if [ -n "$title" ]; then
        title_length=${#title}
        text="$title"$'\n'"$text"
        [ -n "${NO_COLOR:-}" ] || title_style=$'\033[30;107m'
    fi
    while [ "$index" -lt "${#text}" ]; do
        if [ "$index" -eq "$title_length" ]; then
            # Body cursor controls are relative to the first body row.
            title_rows=$((row + 1))
            row=$title_rows max_row=$title_rows saved_row=$title_rows
            column=0 last_cell=-1 style=''
            index=$((index + 1))
            continue
        fi
        char=${text:$index:1}
        index=$((index + 1))
        if [ "$char" = $'\033' ]; then
            next=${text:$index:1}
            if [ "$next" = '[' ]; then
                end=$((index + 1))
                while [ "$end" -lt "${#text}" ]; do
                    final=${text:$end:1}
                    case "$final" in [a-zA-Z@\~]) break ;; esac
                    end=$((end + 1))
                done
                sequence=${text:$((index-1)):$((end-index+2))}
                params=${text:$((index+1)):$((end-index-1))}
                index=$((end + 1))
                if [ "$final" = m ]; then
                    case "$params" in ''|0|0\;*) style="$sequence" ;; *) style+="$sequence" ;; esac
                    continue
                fi
                case "$final" in
                    s) saved_row=$row; saved_column=$column; continue ;;
                    u) row=$saved_row; column=$saved_column; continue ;;
                esac
                [[ "$params" =~ ^[0-9]*$ ]] || continue
                amount=1
                [ -z "$params" ] || amount=$((10#$params))
                if [ "$final" = K ]; then
                    [ -n "$params" ] || amount=0
                    target=$((width - 1)); offset=$column
                    case "$amount" in 1) offset=0; target=$column ;; 2) offset=0 ;; esac
                    for ((position=offset; position<=target && position<width; position++)); do
                        cell=$((row * width + position))
                        unset 'cells[cell]' 'styles[cell]'
                    done
                    continue
                fi
                [ "$amount" -gt 0 ] || amount=1
                case "$final" in
                    A) row=$((row - amount)); [ "$row" -ge "$title_rows" ] || row=$title_rows ;;
                    B) row=$((row + amount)) ;;
                    C) column=$((column + amount)); [ "$column" -le "$width" ] || column=$width ;;
                    D) column=$((column - amount)); [ "$column" -ge 0 ] || column=0 ;;
                    G) column=$((amount - 1)); [ "$column" -lt "$width" ] || column=$((width - 1)) ;;
                esac
            elif [ "$next" = ']' ]; then
                # A preview must not emit window titles or OSC lifecycle markers.
                index=$((index + 1))
                while [ "$index" -lt "${#text}" ]; do
                    char=${text:$index:1}; index=$((index + 1))
                    [ "$char" != $'\007' ] || break
                    if [ "$char" = $'\033' ] && [ "${text:$index:1}" = $'\\' ]; then
                        index=$((index + 1)); break
                    fi
                done
            elif [ "$next" = '(' ] || [ "$next" = ')' ]; then
                index=$((index + 2))
            else
                index=$((index + 1))
            fi
            continue
        fi
        case "$char" in
            $'\n') row=$((row + 1)); column=0; continue ;;
            $'\r') column=0; continue ;;
            $'\t') column=$(((column / 8 + 1) * 8)); continue ;;
        esac
        printf -v code '%d' "'$char"
        if [ "$code" -ge 0 ] && [ "$code" -lt 32 ]; then continue; fi
        yafp_preview_character_width "$char"
        cell_width=$yafp_preview_cell_width
        if [ "$cell_width" -eq 0 ]; then
            if [ "$last_cell" -ge 0 ]; then cells[last_cell]+="$char"; fi
            continue
        fi
        if [ $((column + cell_width)) -gt "$width" ]; then
            row=$((row + 1)); column=0
        fi
        cell=$((row * width + column))
        cells[cell]=$char; styles[cell]=$style; last_cell=$cell
        if [ "$cell_width" -eq 2 ]; then cells[cell+1]=$'\001'; fi
        column=$((column + cell_width))
        [ "$row" -le "$max_row" ] || max_row=$row
    done

    frame_width=$width
    if [ "$sizing" = fit-content ]; then
        frame_width=1
        for ((row=0; row<=max_row && frame_width<width; row++)); do
            for ((column=width-1; column>=frame_width; column--)); do
                cell=$((row * width + column))
                if [ -n "${cells[cell]:-}" ]; then
                    frame_width=$((column + 1))
                    break
                fi
            done
        done
    fi
    for ((column=0; column<frame_width+2; column++)); do horizontal+='─'; done
    printf '%s%s┌%s┐%s\n' "$reset" "$border_style" "$horizontal" "$reset"
    for ((row=0; row<=max_row; row++)); do
        row_style=''
        left_padding=0
        if [ "$row" -lt "$title_rows" ]; then
            row_style=$title_style
            for ((title_row_width=frame_width; title_row_width>0; title_row_width--)); do
                cell=$((row * width + title_row_width - 1))
                [ -z "${cells[cell]:-}" ] || break
            done
            left_padding=$(((frame_width - title_row_width) / 2))
        fi
        if [ "$row" -gt 0 ] && [ "$row" -eq "$title_rows" ]; then
            printf '%s├%s┤%s\n' "$border_style" "$horizontal" "$reset"
        fi
        printf '%s│%s%s %*s' "$border_style" "$reset" "$row_style" "$left_padding" ''
        output_style=$row_style
        for ((column=0; column<frame_width-left_padding; column++)); do
            cell=$((row * width + column))
            if [ -n "${cells[cell]:-}" ]; then
                # Distinguish a wide-character continuation from array holes.
                [ "${cells[cell]}" != $'\001' ] || continue
                style=${styles[cell]:-$row_style}
                if [ "$style" != "$output_style" ]; then
                    printf '%s%s' "$reset" "$style"; output_style=$style
                fi
                printf '%s' "${cells[cell]}"
            else
                if [ "$output_style" != "$row_style" ]; then
                    printf '%s%s' "$reset" "$row_style"
                    output_style=$row_style
                fi
                printf ' '
            fi
        done
        if [ "$row" -lt "$title_rows" ]; then
            printf ' %s%s│%s\n' "$reset" "$border_style" "$reset"
        else
            printf '%s %s│%s\n' "$reset" "$border_style" "$reset"
        fi
    done
    printf '%s└%s┘%s\n' "$border_style" "$horizontal" "$reset"
}
