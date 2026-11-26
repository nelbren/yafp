# On-demand terminal screen; the prompt never loads or runs the art renderer.
yafp-screen() {
    if [ -n "${ZSH_VERSION:-}" ]; then emulate -L zsh -o KSH_ARRAYS; fi
    local view=${1:-all} key old_tty screen_status=0 codex='֍dh' codex_color=90 args=() rendered
    case "$#:$view" in 0:all|1:all|1:resources|1:codex) ;; *)
        printf '%s\n' 'Usage: yafp-screen [resources|codex]' >&2
        return 2 ;;
    esac
    if [ ! -t 0 ] || [ ! -t 1 ]; then
        printf '%s\n' 'yafp-screen requiere una terminal interactiva.' >&2
        return 1
    fi
    case "${TERM:-dumb}" in dumb|'')
        printf '%s\n' 'yafp-screen requiere una terminal compatible con pantalla alternativa.' >&2
        return 1 ;;
    esac
    if ! command -v python3 >/dev/null 2>&1; then
        printf '%s\n' 'yafp-screen requiere Python 3.' >&2
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
        rendered=$(python3 "$YAFP_ROOT/scripts/unix/screen/render.py" "${args[@]}" --plain) || {
            screen_status=$?; break;
        }
        printf '\033[H'
        while IFS= read -r key; do printf '\033[2K%s\n' "$key"; done <<< "$rendered"
        printf '\033[J'
        key=''
        if [ -n "${ZSH_VERSION:-}" ]; then
            IFS= read -r -s -k 1 -t 1 key || true
        else
            IFS= read -r -s -n 1 -t 1 key || true
        fi
        case "$key" in q|Q|$'\033'|$'\003') break ;; esac
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
