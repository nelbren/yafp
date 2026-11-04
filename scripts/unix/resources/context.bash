#!/usr/bin/env bash
# New context shared by Bash and zsh; existing behavior stays in place.
YAFP_RESOURCE_LABEL_STYLE=${YAFP_RESOURCE_LABEL_STYLE:-letters}
YAFP_RESOURCE_VALUE_STYLE=${YAFP_RESOURCE_VALUE_STYLE:-percent}

yafp_resources_context() {
    if [ -n "${ZSH_VERSION:-}" ]; then emulate -L zsh -o KSH_ARRAYS; fi
    local interval="${YAFP_RESOURCE_CHECK_INTERVAL:-0}" item valid=1
    local checked ram_used ram_total swap_used swap_total cpu disk_used disk_total extra
    yafp_ctx_resources=''
    yafp_ctx_resource_tokens=() yafp_ctx_resource_colors=()
    yafp_ctx_resource_values=() yafp_ctx_resource_has_sample=0
    yafp_ctx_resource_state=disabled yafp_ctx_resource_age=''
    yafp_ctx_resource_separator=' '
    case "$interval" in ''|*[!0-9]*|0*|??????*) return 0 ;; esac
    [ "$interval" -le 86400 ] && [ "$interval" -ge 1 ] || return 0
    yafp_ctx_resource_state=unavailable

    if [ -n "${YAFP_RESOURCE_DIR:-}" ] && [ -r "$YAFP_RESOURCE_DIR/sample" ]; then
        IFS=' ' read -r checked ram_used ram_total swap_used swap_total cpu \
            disk_used disk_total extra < "$YAFP_RESOURCE_DIR/sample" || valid=0
        for item in "$checked" "$ram_used" "$ram_total" "$swap_used" \
            "$swap_total" "$cpu" "$disk_used" "$disk_total"; do
            case "$item" in -) ;; ''|*[!0-9]*|?????????????*) valid=0 ;; esac
            case "$item" in 0?*) valid=0 ;; esac
        done
        case "$checked" in ''|*[!0-9]*) valid=0 ;; esac
        [ -z "$extra" ] || valid=0
        if [ "$valid" = 1 ] && [ "$cpu" != - ] && [ "$cpu" -gt 100 ]; then valid=0; fi
        if [ "$valid" = 1 ] && [ "$checked" -le "$SECONDS" ]; then
            yafp_ctx_resource_has_sample=1 yafp_ctx_resource_state=ok
            YAFP_RESOURCE_SAMPLE_AT=$checked
            YAFP_RESOURCE_RAM_USED=$ram_used YAFP_RESOURCE_RAM_TOTAL=$ram_total
            YAFP_RESOURCE_SWAP_USED=$swap_used YAFP_RESOURCE_SWAP_TOTAL=$swap_total
            YAFP_RESOURCE_CPU=$cpu
            YAFP_RESOURCE_DISK_USED=$disk_used YAFP_RESOURCE_DISK_TOTAL=$disk_total
            yafp_resources_summary
        fi
    fi

    if [ -n "${YAFP_RESOURCE_PID:-}" ] && kill -0 "$YAFP_RESOURCE_PID" 2>/dev/null; then
        yafp_ctx_resource_state=pending
        [ "$yafp_ctx_resource_has_sample" != 1 ] || yafp_ctx_resource_state=refreshing
        yafp_ctx_resources="${yafp_ctx_resources:-Resources: waiting for sample}"
        yafp_resources_pending
        return 0
    fi
    YAFP_RESOURCE_PID=''
    if [ -z "${YAFP_RESOURCE_ATTEMPT:-}" ] ||
       [ "$((SECONDS - YAFP_RESOURCE_ATTEMPT))" -ge "$interval" ]; then
        YAFP_RESOURCE_ATTEMPT=$SECONDS
        # An open session can outlive its temporary directory.
        if [ -z "${YAFP_RESOURCE_DIR:-}" ] || [ ! -d "$YAFP_RESOURCE_DIR" ]; then
            YAFP_RESOURCE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/yafp-resources.XXXXXXXX") || return 0
        fi
        # One worker per session, with stdin/stdout/stderr disconnected.
        {
            if [ -n "${ZSH_VERSION:-}" ]; then
                yafp_zsh_resources_start_worker
            else
                bash "$YAFP_ROOT/scripts/unix/resources/collect.bash" \
                    "$YAFP_RESOURCE_DIR/sample" "$SECONDS" "$HOME" </dev/null &
                YAFP_RESOURCE_PID=$!
                disown "$YAFP_RESOURCE_PID" 2>/dev/null || true
            fi
        } >/dev/null 2>&1
        yafp_ctx_resources="${yafp_ctx_resources:-Resources: waiting for sample}"
        yafp_ctx_resource_state=pending
        [ "$yafp_ctx_resource_has_sample" != 1 ] || yafp_ctx_resource_state=refreshing
    fi
    yafp_ctx_resources=${yafp_ctx_resources:-Resources: no valid sample}
    yafp_resources_pending
    return 0
}

yafp_resources_pending() {
    if [ -n "${ZSH_VERSION:-}" ]; then emulate -L zsh -o KSH_ARRAYS; fi
    local index placeholder color
    case "$yafp_ctx_resources" in
        'Resources: waiting for sample') placeholder='⟳'; color=90 ;;
        'Resources: no valid sample') placeholder=''; color=91 ;;
        *) return 0 ;;
    esac
    yafp_ctx_resource_separator=' '
    if [ "${YAFP_RESOURCE_LABEL_STYLE:-letters}" = unicode ] &&
       [ "${YAFP_RESOURCE_VALUE_STYLE:-percent}" = symbols ]; then
        yafp_ctx_resource_separator=''
    fi
    for index in 0 1 2 3; do
        yafp_resource_segment "$index" -
        yafp_ctx_resource_tokens+=("${yafp_resource_token%}$placeholder")
        yafp_ctx_resource_colors+=("$color")
    done
}

yafp_resource_segment() {
    if [ -n "${ZSH_VERSION:-}" ]; then emulate -L zsh -o KSH_ARRAYS; fi
    local index="$1" value="$2" label level warning=85 critical=95
    # Anterior: unicode_labels=('⚙' '▦' '⇄' '◉')
    local labels=(C R S D) unicode_labels=('' '▦' '' '')
    local cells=('⡀' '⣀' '⣄' '⣤' '⣦' '⣶' '⣷' '⣿')
    label="${labels[$index]}"
    if [ "${YAFP_RESOURCE_LABEL_STYLE:-letters}" = unicode ]; then
        label="${unicode_labels[$index]}"
    fi
    yafp_resource_token="${label}" yafp_resource_color=91
    case "$value" in ''|*[!0-9]*) return 0 ;; esac
    [ "$value" -le 100 ] || return 0
    [ "$index" -ne 2 ] || { warning=10; critical=30; }
    yafp_resource_color=92
    if [ "$value" -gt "$critical" ]; then yafp_resource_color=91
    elif [ "$value" -gt "$warning" ]; then yafp_resource_color=93
    fi
    if [ "${YAFP_RESOURCE_VALUE_STYLE:-percent}" = symbols ]; then
        level=$((value * 8 / 100))
        [ "$level" -lt 8 ] || level=7
        yafp_resource_token="${label}${cells[$level]}"
    else
        yafp_resource_token="${label}${value}%"
    fi
}

yafp_resources_summary() {
    if [ -n "${ZSH_VERSION:-}" ]; then emulate -L zsh -o KSH_ARRAYS; fi
    local ram='N/A' cpu='N/A' disk='N/A' swap='N/A' age index=0 value
    if [ "$YAFP_RESOURCE_RAM_USED" != - ] && [ "$YAFP_RESOURCE_RAM_TOTAL" != - ] &&
       [ "$YAFP_RESOURCE_RAM_TOTAL" -gt 0 ]; then
        ram="$((100 * YAFP_RESOURCE_RAM_USED / YAFP_RESOURCE_RAM_TOTAL))%"
    fi
    [ "$YAFP_RESOURCE_CPU" = - ] || cpu="${YAFP_RESOURCE_CPU}%"
    if [ "$YAFP_RESOURCE_SWAP_USED" != - ] && [ "$YAFP_RESOURCE_SWAP_TOTAL" != - ]; then
        if [ "$YAFP_RESOURCE_SWAP_TOTAL" -gt 0 ]; then
            swap="$((100 * YAFP_RESOURCE_SWAP_USED / YAFP_RESOURCE_SWAP_TOTAL))%"
        elif [ "$YAFP_RESOURCE_SWAP_USED" -eq 0 ]; then
            swap='0%'
        fi
    fi
    if [ "$YAFP_RESOURCE_DISK_USED" != - ] && [ "$YAFP_RESOURCE_DISK_TOTAL" != - ] &&
       [ "$YAFP_RESOURCE_DISK_TOTAL" -gt 0 ]; then
        disk="$((100 * YAFP_RESOURCE_DISK_USED / YAFP_RESOURCE_DISK_TOTAL))%"
    fi
    age=$((SECONDS - YAFP_RESOURCE_SAMPLE_AT))
    yafp_ctx_resources=''
    yafp_ctx_resource_tokens=() yafp_ctx_resource_colors=()
    yafp_ctx_resource_values=()
    yafp_ctx_resource_separator=' '
    if [ "${YAFP_RESOURCE_LABEL_STYLE:-letters}" = unicode ] &&
       [ "${YAFP_RESOURCE_VALUE_STYLE:-percent}" = symbols ]; then
        yafp_ctx_resource_separator=''
    fi
    for value in "${cpu%\%}" "${ram%\%}" "${swap%\%}" "${disk%\%}"; do
        yafp_ctx_resource_values+=("$value")
        yafp_resource_segment "$index" "$value"
        yafp_ctx_resource_tokens+=("$yafp_resource_token")
        yafp_ctx_resource_colors+=("$yafp_resource_color")
        [ "$index" -eq 0 ] || yafp_ctx_resources+="$yafp_ctx_resource_separator"
        yafp_ctx_resources+="$yafp_resource_token"
        index=$((index + 1))
    done
    yafp_ctx_resource_age=$age
    yafp_ctx_resources+=" ${age}s"
}

theme_render_resources() {
    if [ -n "${ZSH_VERSION:-}" ]; then emulate -L zsh -o KSH_ARRAYS; fi
    local text="${yafp_ctx_resources:-}" token color index=0
    local separator='' frame="$cSeparator"
    local open='\[' close='\]'
    [ -n "${yafp_ctx_resources:-}" ] || return 0
    if [ -n "${ZSH_VERSION:-}" ]; then open='%{'; close='%}'; fi
    [ "${YAFP_THEME_NAME:-}" != default ] || frame=$cGit
    printf '%s%s%s↦[' "$open" "$frame" "$close"
    if [ "${#yafp_ctx_resource_tokens[@]}" -gt 0 ]; then
        for token in "${yafp_ctx_resource_tokens[@]}"; do
            printf -v color '\033[0;%sm' "${yafp_ctx_resource_colors[$index]}"
            if [ -n "${ZSH_VERSION:-}" ]; then token=${token//\%/%%}; fi
            printf '%s%s%s%s%s' "$separator" "$open" "$color" "$close" "$token"
            separator=$yafp_ctx_resource_separator
            index=$((index + 1))
        done
        case "$yafp_ctx_resources" in
            'Resources: waiting for sample') ;;
            *'') printf '%s%s%s' "$open" $'\033[0;90m' "$close" ;;
        esac
    else
        printf '%s%s%s%s' "$open" $'\033[0;90m' "$close" "$text"
    fi
    printf '%s%s%s]%s%s%s' "$open" "$frame" "$close" \
        "$open" $'\033[0m' "$close"
}

yafp-demo-resources() {
    if [ -n "${ZSH_VERSION:-}" ]; then emulate -L zsh -o KSH_ARRAYS; fi
    local resource="${1:-CPU}" selected load index rendered
    local values=(20 40 5 50) loads=(20 90 98)
    local usage='Usage: yafp-demo-resources [CPU|MEMORY|SWAP|DISK|ALL]'
    if [ "$#" -gt 1 ]; then
        printf '%s\n' "$usage" >&2
        return 2
    fi
    case "$resource" in
        ALL|all)
            for resource in CPU MEMORY SWAP DISK; do
                [ "$resource" = CPU ] || printf '\n'
                yafp-demo-resources "$resource"
            done
            return
            ;;
        CPU|cpu) resource=CPU; selected=0 ;;
        MEMORY|memory|MEMORIA|memoria|RAM|ram) resource=MEMORY; selected=1 ;;
        SWAP|swap) resource=SWAP; selected=2; loads=(5 20 40) ;;
        DISK|disk|DISCO|disco) resource=DISK; selected=3 ;;
        *) printf '%s\n' "$usage" >&2; return 2 ;;
    esac

    local yafp_ctx_resources='demo' yafp_ctx_resource_separator=' '
    local yafp_ctx_resource_tokens=() yafp_ctx_resource_colors=()
    local yafp_resource_token yafp_resource_color
    if [ "$YAFP_RESOURCE_LABEL_STYLE" = unicode ] && [ "$YAFP_RESOURCE_VALUE_STYLE" = symbols ]; then
        yafp_ctx_resource_separator=''
    fi
    for load in "${loads[@]}"; do
        values[selected]=$load
        yafp_ctx_resource_tokens=() yafp_ctx_resource_colors=()
        for index in 0 1 2 3; do
            yafp_resource_segment "$index" "${values[$index]}"
            yafp_ctx_resource_tokens+=("$yafp_resource_token")
            yafp_ctx_resource_colors+=("$yafp_resource_color")
        done
        rendered="$(theme_render_os_icon) $(theme_render_resources)"
        printf '%-10s  ' "$resource $load%"
        if [ -n "${ZSH_VERSION:-}" ]; then
            print -Pr -- "$rendered"
        else
            rendered=${rendered//\\[/}
            rendered=${rendered//\\]/}
            printf '%s\n' "$rendered"
        fi
    done
}

yafp-resources() {
    if [ -n "${ZSH_VERSION:-}" ]; then emulate -L zsh -o KSH_ARRAYS; fi
    local report line state_icon state_color age='' age_color=90
    local index value color detail item used_text total_text unit
    local labels=('          CPU:' '          RAM:' '         SWAP:' '  Disk (HOME):')
    local used=('-' '-' '-') totals=('-' '-' '-')
    yafp_resources_context
    case "$yafp_ctx_resource_state" in
        ok) state_icon=''; state_color=92 ;;
        refreshing) state_icon=''; state_color=90 ;;
        pending) state_icon=''; state_color=93 ;;
        disabled) state_icon=''; state_color=90 ;;
        *) state_icon=''; state_color=91 ;;
    esac
    if [ "$yafp_ctx_resource_has_sample" = 1 ]; then
        age="${yafp_ctx_resource_age}s" age_color=37
        used=("$YAFP_RESOURCE_RAM_USED" "$YAFP_RESOURCE_SWAP_USED" "$YAFP_RESOURCE_DISK_USED")
        totals=("$YAFP_RESOURCE_RAM_TOTAL" "$YAFP_RESOURCE_SWAP_TOTAL" "$YAFP_RESOURCE_DISK_TOTAL")
    fi
    printf -v report '        State: \033[%sm%s %s\033[0m\n   Sample age: \033[%sm%s\033[0m' \
        "$state_color" "$state_icon" "$yafp_ctx_resource_state" "$age_color" "$age"
    for index in 0 1 2 3; do
        value='' color=90 detail=''
        item="${yafp_ctx_resource_values[$index]:-}"
        case "$item" in
            ''|*[!0-9]*) ;;
            *) if [ "$item" -le 100 ]; then value="${item}%"; color=${yafp_ctx_resource_colors[$index]}; fi ;;
        esac
        if [ "$index" -gt 0 ]; then
            used_text=${used[$((index - 1))]} total_text=${totals[$((index - 1))]}
            if [ "$used_text" != - ] || [ "$total_text" != - ]; then
                [ "$used_text" != - ] || used_text=''
                [ "$total_text" != - ] || total_text=''
                unit=MiB; [ "$index" -ne 3 ] || unit=KiB
                detail=" · ${used_text}/${total_text} ${unit}"
            fi
        fi
        printf -v line '%s \033[%sm%s%s\033[0m' "${labels[$index]}" "$color" "$value" "$detail"
        report+=$'\n'"$line"
    done
    . "$YAFP_ROOT/scripts/unix/preview/lib/frame.bash" || return
    yafp_preview_frame "$report"
    if [ "$yafp_ctx_resource_state" = disabled ]; then
        printf '%s\n' 'Resources disabled. Set YAFP_RESOURCE_CHECK_INTERVAL=30.'
    fi
}

yafp_resources_cleanup() {
    if [ -n "${ZSH_VERSION:-}" ]; then emulate -L zsh -o KSH_ARRAYS; fi
    [ -z "${YAFP_RESOURCE_PID:-}" ] || kill "$YAFP_RESOURCE_PID" 2>/dev/null || true
    if [ -n "${YAFP_RESOURCE_DIR:-}" ]; then
        rm -f -- "$YAFP_RESOURCE_DIR/sample" "$YAFP_RESOURCE_DIR/sample.tmp" 2>/dev/null
        rmdir -- "$YAFP_RESOURCE_DIR" 2>/dev/null || true
    fi
    YAFP_RESOURCE_DIR='' YAFP_RESOURCE_PID='' YAFP_RESOURCE_ATTEMPT=''
    YAFP_RESOURCE_SAMPLE_AT=''
}
