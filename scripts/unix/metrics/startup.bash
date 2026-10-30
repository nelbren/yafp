#!/usr/bin/env bash
# Invoked only after prompt loading, never during rendering.
yafp_record_startup() {
    case "$-" in *i*) ;; *) return 0 ;; esac
    [ "${YAFP_METRICS_DISABLED:-0}" != 1 ] || return 0
    [ "${YAFP_NO_INSTALL_HOOKS:-0}" != 1 ] || return 0
    [ "${YAFP_STARTUP_METRICS_PID:-}" != "$$" ] || return 0
    local root="$1" shell="$2" tools python recorder
    tools="${AI_DEV_TOOLS_ROOT:-${HOME}/ai-dev-tools}"
    python="${tools}/.venv/bin/python"
    recorder="${tools}/bin/application-startup"
    [ -x "$python" ] && [ -f "$recorder" ] || return 0
    YAFP_STARTUP_METRICS_PID=$$
    # One local task; it neither holds the terminal nor contacts the network.
    {
        "$python" "$recorder" --path "$root" --shell "$shell" </dev/null &
        disown 2>/dev/null || :
    } >/dev/null 2>&1
    return 0
}
