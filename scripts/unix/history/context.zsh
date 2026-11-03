#!/usr/bin/env zsh
# History redraw mitigation; command text and ZLE key bindings stay unchanged.
YAFP_ZSH_HISTORY_REDRAW=${YAFP_ZSH_HISTORY_REDRAW:-1}

yafp_zsh_history_has_width_risk() {
    emulate -L zsh -o KSH_ARRAYS
    local text="$1" char code index
    # Most history entries need no Unicode scan.
    [[ "$text" == *[![:ascii:]]* ]] || return 1
    for (( index = 0; index < ${#text}; index++ )); do
        char="${text: index:1}"
        printf -v code '%d' "'$char"
        # Conservative candidates: symbols/ZWJ, emoji, flags, and selectors.
        if (( code == 0x00a9 || code == 0x00ae ||
              (code >= 0x2000 && code <= 0x2bff) ||
              code == 0xfe0e || code == 0xfe0f ||
              (code >= 0x1f000 && code <= 0x1faff) )); then
            return 0
        fi
    done
    return 1
}

yafp_zsh_history_line_init() {
    emulate -L zsh -o KSH_ARRAYS
    YAFP_ZSH_HISTORY_UNICODE=0
    if [[ "${YAFP_ZSH_HISTORY_REDRAW:-1}" == 1 ]] &&
       yafp_zsh_history_has_width_risk "${BUFFER:-}"; then
        YAFP_ZSH_HISTORY_UNICODE=1
    fi
    return 0
}

yafp_zsh_history_line_set() {
    emulate -L zsh -o KSH_ARRAYS
    local previous="${YAFP_ZSH_HISTORY_UNICODE:-0}" current=0
    if [[ "${YAFP_ZSH_HISTORY_REDRAW:-1}" != 1 ]]; then
        YAFP_ZSH_HISTORY_UNICODE=0
        return 0
    fi
    yafp_zsh_history_has_width_risk "${BUFFER:-}" && current=1
    YAFP_ZSH_HISTORY_UNICODE=$current
    if [[ "$current" == 1 || "$previous" == 1 ]]; then
        # Builtin redisplay resets the physical column and clears stale cells.
        # Reuse the cached prompt; do not collect context or execute the buffer.
        zle .redisplay
    fi
    return 0
}

yafp_zsh_install_history_redraw() {
    emulate -L zsh -o KSH_ARRAYS
    autoload -Uz add-zle-hook-widget
    # The native helper preserves other hooks and deduplicates repeated loads.
    add-zle-hook-widget line-init yafp_zsh_history_line_init
    add-zle-hook-widget history-line-set yafp_zsh_history_line_set
}
