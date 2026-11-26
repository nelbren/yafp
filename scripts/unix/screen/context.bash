# On-demand terminal screen; the prompt never loads or runs the art renderer.
yafp-screen() {
    if [ -n "${ZSH_VERSION:-}" ]; then emulate -L zsh -o KSH_ARRAYS; fi
    local view=${1:-all} key old_tty screen_status=0 codex='֍dh' codex_color=90 args=() rendered
    local frames=() frame delay step=0 shine=${YAFP_SCREEN_SHINE:-off} sweep_state=:0
    local legacy_bash=0 tty_timeout=10 next_timeout
    if [ -z "${ZSH_VERSION:-}" ] && [ "${BASH_VERSINFO[0]}" -lt 4 ]; then legacy_bash=1; fi
    case "$#:$view" in 0:all|1:all|1:resources|1:codex) ;; *)
        printf '%s\n' 'Usage: yafp-screen [resources|codex]' >&2
        return 2 ;;
    esac
    if [ ! -t 0 ] || [ ! -t 1 ]; then
        printf '%s\n' 'yafp-screen requires an interactive terminal.' >&2
        return 1
    fi
    case "${TERM:-dumb}" in dumb|'')
        printf '%s\n' 'yafp-screen requires a terminal that supports the alternate screen.' >&2
        return 1 ;;
    esac
    if ! command -v python3 >/dev/null 2>&1; then
        printf '%s\n' 'yafp-screen requires Python 3.' >&2
        return 1
    fi
    old_tty=$(stty -g) || return 1
    yafp_screen_restore() {
        stty "$old_tty" 2>/dev/null || true
        printf '\033[0m\033[?25h\033[?1049l\0338'
    }
    trap 'yafp_screen_restore; trap - INT TERM HUP; return 130' INT
    trap 'yafp_screen_restore; trap - INT TERM HUP; return 143' TERM HUP
    stty -echo -icanon min 0 time 10 || { trap - INT TERM HUP; return 1; }
    printf '\0337\033[?1049h\033[?25l\033[H'
    while :; do
        args=(--view "$view" --columns "${COLUMNS:-80}" --lines "${LINES:-24}")
        if [ "$view" != resources ]; then
            yafp_codex_context
            codex=${yafp_ctx_codex_token:-֍dh}
            codex_color=${yafp_ctx_codex_color:-90}
            if [ "${yafp_ctx_codex_state:-}" = disabled ]; then
                codex='֍OFF'
                codex_color=90
            fi
            args+=(--codex "$codex")
        fi
        if [ "$view" != codex ]; then
            yafp_resources_context
            args+=(--resources)
            local i
            if [ "${yafp_ctx_resource_state:-}" = disabled ]; then
                args+=(OFF OFF OFF OFF)
            else
                for i in 0 1 2 3; do args+=("${yafp_ctx_resource_tokens[$i]:-}"); done
            fi
            args+=(--colors "$codex_color")
            if [ "${yafp_ctx_resource_state:-}" = disabled ]; then
                args+=(90 90 90 90)
            else
                for i in 0 1 2 3; do args+=("${yafp_ctx_resource_colors[$i]:-90}"); done
            fi
        else
            args+=(--colors "$codex_color" 90 90 90 90)
        fi
        rendered=$(PYTHONIOENCODING=utf-8 python3 "$YAFP_ROOT/scripts/unix/screen/render.py" "${args[@]}" \
            --frames lines --shine="$shine" --step "$step" --sweep-state="$sweep_state" \
            --background="${YAFP_SCREEN_BACKGROUND:-off}" \
            --matrix-density="${YAFP_SCREEN_MATRIX_DENSITY:-low}" \
            --matrix-speed="${YAFP_SCREEN_MATRIX_SPEED:-normal}" \
            --matrix-color="${YAFP_SCREEN_MATRIX_COLOR:-green}" \
            --matrix-text="${YAFP_SCREEN_MATRIX_TEXT:-random}") || {
            screen_status=$?; break;
        }
        if [ "$shine" = random ]; then
            sweep_state=${rendered%%$'\n'*}
            sweep_state=${sweep_state%$'\r'}
            rendered=${rendered#*$'\n'}
        fi
        frames=()
        while IFS= read -r frame; do frames+=("$frame"); done <<< "$rendered"
        delay=1
        if [ "${#frames[@]}" -gt 1 ]; then delay=0.1; fi
        if [ "$legacy_bash" = 1 ]; then
            next_timeout=10
            if [ "$delay" != 1 ]; then next_timeout=1; fi
            if [ "$tty_timeout" != "$next_timeout" ]; then
                stty time "$next_timeout" || { screen_status=1; break; }
                tty_timeout=$next_timeout
            fi
        fi
        for frame in "${frames[@]}"; do
            printf '%s' "$frame"
            key=''
            if [ -n "${ZSH_VERSION:-}" ]; then
                IFS= read -r -s -k 1 -t "$delay" key || true
            elif [ "$legacy_bash" = 1 ]; then
                # VTIME sets the frame delay. Read once so a readiness probe
                # cannot consume the exit key on macOS Bash 3.2.
                key=$(dd bs=1 count=1 2>/dev/null) || true
            else
                IFS= read -r -s -n 1 -t "$delay" key || true
            fi
            case "$key" in q|Q|$'\033'|$'\003') break 2 ;; esac
            step=$((step + 1))
        done
    done
    yafp_screen_restore
    trap - INT TERM HUP
    return "$screen_status"
}

yafp-screen-codex() {
    yafp-screen codex "$@"
}

yafp-screen-resources() {
    yafp-screen resources "$@"
}
