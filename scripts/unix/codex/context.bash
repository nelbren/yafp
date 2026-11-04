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
    yafp_ctx_codex_token='֍dh' yafp_ctx_codex_color=91
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
    local interval="${YAFP_CODEX_CHECK_INTERVAL:-0}" checked state value primary secondary reset extra item valid=1 sampled=0
    yafp_ctx_codex='' yafp_ctx_codex_token='' yafp_ctx_codex_color=90
    yafp_ctx_codex_state=disabled yafp_ctx_codex_remaining='-' yafp_ctx_codex_resets_at='-'
    case "$interval" in ''|*[!0-9]*|0*|??????*) return 0 ;; esac
    [ "$interval" -ge 1 ] && [ "$interval" -le 86400 ] || return 0
    yafp_ctx_codex_state=unavailable
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
            sampled=1
            yafp_ctx_codex_state=$state
            YAFP_CODEX_STATE=$state YAFP_CODEX_SAMPLE_AT=$checked
            YAFP_CODEX_PRIMARY=$primary YAFP_CODEX_SECONDARY=$secondary
            if [ "$state" = ok ]; then
                yafp_ctx_codex_remaining=$value yafp_ctx_codex_resets_at=$reset
                yafp_codex_segment "$value"
                if [ "$value" != - ] && [ "$reset" != - ]; then
                    yafp_codex_format_reset "$((reset - SECONDS))"
                    yafp_ctx_codex_token+="$yafp_ctx_codex_reset_text"
                fi
            fi
        fi
    fi
    if [ -n "${YAFP_CODEX_PID:-}" ] && kill -0 "$YAFP_CODEX_PID" 2>/dev/null; then
        if [ "$sampled" != 1 ]; then
            yafp_ctx_codex_token='֍⟳d⟳h' yafp_ctx_codex_state=pending yafp_ctx_codex_color=90
        fi
        yafp_ctx_codex=$yafp_ctx_codex_token
        return 0
    fi
    YAFP_CODEX_PID=''
    if [ -z "${YAFP_CODEX_ATTEMPT:-}" ] || [ "$((SECONDS - YAFP_CODEX_ATTEMPT))" -ge "$interval" ]; then
        YAFP_CODEX_ATTEMPT=$SECONDS
        # An open session can outlive its temporary directory.
        if [ -z "${YAFP_CODEX_DIR:-}" ] || [ ! -d "$YAFP_CODEX_DIR" ]; then
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
    if [ "$sampled" = 0 ] && [ -n "${YAFP_CODEX_PID:-}" ]; then
        yafp_ctx_codex_token='֍⟳d⟳h' yafp_ctx_codex_state=pending yafp_ctx_codex_color=90
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
    printf '%s%s%s↤[%s%s%s%s%s%s%s]%s%s%s' \
        "$open" "$frame" "$close" "$open" "$color" "$close" "$token" \
        "$open" "$frame" "$close" "$open" $'\033[0m' "$close"
}

yafp-codex() {
    if [ -n "${ZSH_VERSION:-}" ]; then emulate -L zsh -o KSH_ARRAYS; fi
    local report reset_text='' remaining_text='' seconds
    local state_icon state_color reset_color=90
    yafp_codex_context
    case "$yafp_ctx_codex_state" in
        ok) state_icon=''; state_color=92 ;;
        pending) state_icon=''; state_color=93 ;;
        disabled) state_icon=''; state_color=90 ;;
        logged-out) state_icon=''; state_color=91 ;;
        unsupported-auth) state_icon=''; state_color=93 ;;
        missing-cli|missing-python) state_icon=''; state_color=93 ;;
        timeout) state_icon=''; state_color=91 ;;
        *) state_icon=''; state_color=91 ;;
    esac
    if [ "$yafp_ctx_codex_remaining" != - ]; then
        remaining_text="${yafp_ctx_codex_remaining}%"
        if [ "$yafp_ctx_codex_resets_at" != - ]; then
            seconds=$((yafp_ctx_codex_resets_at - SECONDS))
            [ "$seconds" -ge 0 ] || seconds=0
            reset_text="$((seconds / 86400))d$((seconds % 86400 / 3600))h"
            reset_color=93
        fi
    fi
    local remaining_color=90
    [ "$yafp_ctx_codex_remaining" = - ] || remaining_color=$yafp_ctx_codex_color
    printf -v report '        Reset: \033[%sm%s\033[0m\n        State: \033[%sm%s %s\033[0m\n    Remaining: \033[%sm%s\033[0m' \
        "$reset_color" "$reset_text" "$state_color" "$state_icon" "$yafp_ctx_codex_state" \
        "$remaining_color" "$remaining_text"
    . "$YAFP_ROOT/scripts/unix/preview/lib/frame.bash" || return
    yafp_preview_frame "$report"
    if [ "$yafp_ctx_codex_state" = disabled ]; then
        printf '%s\n' 'Codex quota disabled. Set YAFP_CODEX_CHECK_INTERVAL=300.'
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
