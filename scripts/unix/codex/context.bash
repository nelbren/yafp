#!/usr/bin/env bash
# Shared Bash/zsh cache and rendering; authentication and HTTP stay in the worker.
YAFP_CODEX_VALUE_STYLE=${YAFP_CODEX_VALUE_STYLE:-percent}

yafp_codex_format_reset() {
    local remaining="$1"
    [ "$remaining" -ge 0 ] || remaining=0
    if [ "$remaining" -ge 86400 ]; then
        yafp_ctx_codex_reset_text="$((remaining / 86400))d$((remaining % 86400 / 3600))h"
    elif [ "$remaining" -ge 3600 ]; then
        yafp_ctx_codex_reset_text="$((remaining / 3600))h$((remaining % 3600 / 60))m"
    elif [ "$remaining" -ge 60 ]; then
        yafp_ctx_codex_reset_text="$((remaining / 60))m$((remaining % 60))s"
    else
        yafp_ctx_codex_reset_text="${remaining}s"
    fi
}

yafp_codex_segment() {
    if [ -n "${ZSH_VERSION:-}" ]; then emulate -L zsh -o KSH_ARRAYS; fi
    local value="$1" level
    local cells=('⡀' '⣀' '⣄' '⣤' '⣦' '⣶' '⣷' '⣿')
    yafp_ctx_codex_token='֍N/D' yafp_ctx_codex_color=90
    case "$value" in ''|*[!0-9]*|0?*|????*) return 0 ;; esac
    [ "$value" -le 100 ] || return 0
    yafp_ctx_codex_color=91
    if [ "$value" -ge 50 ]; then yafp_ctx_codex_color=92
    elif [ "$value" -ge 25 ]; then yafp_ctx_codex_color=93
    fi
    yafp_ctx_codex_token="֍${value}%"
    if [ "${YAFP_CODEX_VALUE_STYLE:-percent}" = symbols ]; then
        level=$((value * 8 / 100))
        [ "$level" -lt 8 ] || level=7
        yafp_ctx_codex_token="֍${cells[$level]}"
    fi
}

yafp_codex_context() {
    if [ -n "${ZSH_VERSION:-}" ]; then emulate -L zsh -o KSH_ARRAYS; fi
    local interval="${YAFP_CODEX_CHECK_INTERVAL:-0}" checked state value primary secondary reset extra item valid=1
    yafp_ctx_codex='' yafp_ctx_codex_token='' yafp_ctx_codex_color=90
    case "$interval" in ''|*[!0-9]*|0*|??????*) return 0 ;; esac
    [ "$interval" -ge 1 ] && [ "$interval" -le 86400 ] || return 0
    yafp_codex_segment -
    if [ -n "${YAFP_CODEX_DIR:-}" ] && [ -r "$YAFP_CODEX_DIR/sample" ]; then
        IFS=' ' read -r checked state value primary secondary reset extra < "$YAFP_CODEX_DIR/sample" || valid=0
        # Accept samples from a worker started before the reset-time upgrade.
        reset=${reset:--}
        case "$reset" in -) ;; ''|*[!0-9]*|0?*|???????????*) valid=0 ;; esac
        case "$checked" in ''|*[!0-9]*|0?*|??????????*) valid=0 ;; esac
        case "$state" in
            ok|missing-cli|missing-python|logged-out|unsupported-auth|timeout|unavailable) ;;
            *) valid=0 ;;
        esac
        for item in "$value" "$primary" "$secondary"; do
            case "$item" in
                -) ;;
                ''|*[!0-9]*|0?*|????*) valid=0 ;;
                *) [ "$item" -le 100 ] || valid=0 ;;
            esac
        done
        [ -z "$extra" ] || valid=0
        if [ "$valid" = 1 ] && [ "$checked" -le "$SECONDS" ]; then
            YAFP_CODEX_STATE=$state YAFP_CODEX_SAMPLE_AT=$checked
            YAFP_CODEX_PRIMARY=$primary YAFP_CODEX_SECONDARY=$secondary
            if [ "$state" = ok ]; then
                yafp_codex_segment "$value"
                if [ "$value" != - ] && [ "$reset" != - ]; then
                    yafp_codex_format_reset "$((reset - SECONDS))"
                    yafp_ctx_codex_token+="$yafp_ctx_codex_reset_text"
                fi
            fi
        fi
    fi
    if [ -n "${YAFP_CODEX_PID:-}" ] && kill -0 "$YAFP_CODEX_PID" 2>/dev/null; then
        yafp_ctx_codex=$yafp_ctx_codex_token
        return 0
    fi
    YAFP_CODEX_PID=''
    if [ -z "${YAFP_CODEX_ATTEMPT:-}" ] || [ "$((SECONDS - YAFP_CODEX_ATTEMPT))" -ge "$interval" ]; then
        YAFP_CODEX_ATTEMPT=$SECONDS
        if [ -z "${YAFP_CODEX_DIR:-}" ]; then
            YAFP_CODEX_DIR=$(mktemp -d "${TMPDIR:-/tmp}/yafp-codex.XXXXXXXX") || return 0
        fi
        {
            if [ -n "${ZSH_VERSION:-}" ]; then
                yafp_zsh_codex_start_worker
            else
                bash "$YAFP_ROOT/scripts/unix/codex/collect.bash" \
                    "$YAFP_CODEX_DIR/sample" "$SECONDS" </dev/null &
                YAFP_CODEX_PID=$!
                disown "$YAFP_CODEX_PID" 2>/dev/null || true
            fi
        } >/dev/null 2>&1
    fi
    yafp_ctx_codex=$yafp_ctx_codex_token
    return 0
}

theme_render_codex() {
    if [ -n "${ZSH_VERSION:-}" ]; then emulate -L zsh -o KSH_ARRAYS; fi
    [ -n "${yafp_ctx_codex:-}" ] || return 0
    local open='\[' close='\]' frame="$cSeparator" color token="$yafp_ctx_codex_token"
    if [ -n "${ZSH_VERSION:-}" ]; then open='%{'; close='%}'; token=${token//\%/%%}; fi
    [ "${YAFP_THEME_NAME:-}" != default ] || frame=$cGit
    printf -v color '\033[0;%sm' "$yafp_ctx_codex_color"
    printf '%s%s%s↦[%s%s%s%s%s%s%s]%s%s%s' \
        "$open" "$frame" "$close" "$open" "$color" "$close" "$token" \
        "$open" "$frame" "$close" "$open" $'\033[0m' "$close"
}

yafp-codex() {
    yafp_codex_context
    if [ -z "$yafp_ctx_codex" ]; then
        printf '%s\n' 'Codex quota disabled. Set YAFP_CODEX_CHECK_INTERVAL=300.'
        return 0
    fi
    printf '%s\n' "$yafp_ctx_codex"
    printf 'State: %s\n' "${YAFP_CODEX_STATE:-pending}"
    if [ -n "${YAFP_CODEX_SAMPLE_AT:-}" ]; then
        local primary='N/D' secondary='N/D'
        [ "$YAFP_CODEX_PRIMARY" = - ] || primary="${YAFP_CODEX_PRIMARY}%"
        [ "$YAFP_CODEX_SECONDARY" = - ] || secondary="${YAFP_CODEX_SECONDARY}%"
        printf 'Remaining: primary %s; secondary %s; sample age %ss\n' \
            "$primary" "$secondary" "$((SECONDS - YAFP_CODEX_SAMPLE_AT))"
    fi
}

yafp_codex_cleanup() {
    if [ -n "${ZSH_VERSION:-}" ]; then emulate -L zsh -o KSH_ARRAYS; fi
    # The collector handles SIGTERM and terminates its private app-server.
    [ -z "${YAFP_CODEX_PID:-}" ] || kill "$YAFP_CODEX_PID" 2>/dev/null || true
    if [ -n "${YAFP_CODEX_DIR:-}" ]; then
        rm -f -- "$YAFP_CODEX_DIR/sample" "$YAFP_CODEX_DIR/sample.tmp" 2>/dev/null
        rmdir -- "$YAFP_CODEX_DIR" 2>/dev/null || true
    fi
    YAFP_CODEX_DIR='' YAFP_CODEX_PID='' YAFP_CODEX_ATTEMPT=''
    YAFP_CODEX_SAMPLE_AT='' YAFP_CODEX_STATE=''
}
