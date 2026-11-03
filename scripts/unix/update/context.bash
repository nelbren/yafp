#!/usr/bin/env bash
# Synchronous startup check, separate from normal repository prompt monitoring.
yafp_update_start() {
    if [ -n "${ZSH_VERSION:-}" ]; then emulate -L zsh -o KSH_ARRAYS; fi
    [ "${YAFP_UPDATE_CHECK:-1}" != 0 ] || return 0
    if [ -n "${YAFP_UPDATE_ROOT:-}" ] && [ "$YAFP_UPDATE_ROOT" != "$YAFP_ROOT" ]; then
        yafp_update_cleanup
    fi
    if [ -n "${YAFP_UPDATE_DIR:-}" ] && [ -r "$YAFP_UPDATE_DIR/sample" ]; then return 0; fi
    yafp_update_cleanup
    YAFP_UPDATE_ROOT=$YAFP_ROOT
    YAFP_UPDATE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/yafp-update.XXXXXXXX") || return 0
    bash "$YAFP_UPDATE_ROOT/scripts/unix/update/collect.bash" \
        "$YAFP_UPDATE_ROOT" "$YAFP_UPDATE_DIR/sample" </dev/null >/dev/null 2>&1 || true
    return 0
}

yafp_update_notice() {
    if [ -n "${ZSH_VERSION:-}" ]; then emulate -L zsh -o KSH_ARRAYS; fi
    [ -n "${YAFP_UPDATE_DIR:-}" ] || return 0
    local state behind head branch upstream ahead extra answer='' root=$YAFP_UPDATE_ROOT
    if [ ! -r "$YAFP_UPDATE_DIR/sample" ]; then
        yafp_update_cleanup
        yafp_update_message info "YAFP startup check: $root"
        yafp_update_message error '🌐 REMOTE CHECK FAILED'
        return 0
    fi
    IFS=' ' read -r state behind head branch upstream ahead extra < "$YAFP_UPDATE_DIR/sample" || state=error
    yafp_update_cleanup
    case "$state" in
        missing-git|not-git|unborn|detached|no-upstream|no-remote)
            yafp_update_message info "YAFP startup check: $root" ;;
    esac
    case "$state" in
        missing-git) yafp_update_message warning ' GIT NOT AVAILABLE: YAFP startup check skipped'; return 0 ;;
        not-git) yafp_update_message warning ' NOT A GIT REPOSITORY: YAFP installation'; return 0 ;;
        unborn) yafp_update_message warning ' NO COMMITS: YAFP installation'; return 0 ;;
        detached) yafp_update_message warning ' DETACHED HEAD: YAFP startup update unavailable'; return 0 ;;
        no-upstream) yafp_update_message warning ' NO UPSTREAM: YAFP startup update unavailable'; return 0 ;;
        no-remote) yafp_update_message warning ' NO REMOTE: YAFP startup update unavailable'; return 0 ;;
    esac
    case "$behind/$ahead" in *[!0-9/]*|/|/*|*/) state=error ;; esac
    if [ "$state" != ok ] || [ -n "$extra" ]; then
        yafp_update_message info "YAFP startup check: $root"
        yafp_update_message error '🌐 REMOTE CHECK FAILED'
        return 0
    fi
    # Discard a result if the user switched branches or changed HEAD while checking.
    [ "$(git -C "$root" rev-parse --verify HEAD 2>/dev/null)" = "$head" ] || return 0
    [ "$(git -C "$root" symbolic-ref --quiet HEAD 2>/dev/null)" = "$branch" ] || return 0
    [ "$(git -C "$root" rev-parse --symbolic-full-name '@{upstream}' 2>/dev/null)" = "$upstream" ] || return 0
    [ "$ahead" -ne 0 ] || [ "$behind" -ne 0 ] || return 0
    yafp_update_message info "YAFP startup check: $root"
    local target=${upstream#refs/remotes/} unit=commits verb=have
    if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
        yafp_update_message error " DIVERGED REPOSITORY: $ahead local commit(s), $behind remote commit(s) from $target"
        return 0
    fi
    if [ "$ahead" -gt 0 ]; then
        [ "$ahead" -ne 1 ] || { unit=commit; verb=has; }
        yafp_update_message warning " REMOTE NOT UPDATED: $ahead local $unit $verb not been pushed to $target"
        return 0
    fi
    yafp_update_message error " OUTDATED REPOSITORY: YAFP is $behind commit(s) behind its upstream."
    printf 'Update YAFP now? [y/N] '
    IFS= read -r answer || answer=''
    case "$answer" in y|Y) ;; *) return 0 ;; esac
    local saved_this_command="${this_command:-}" saved_previous_command="${previous_command:-}"
    local saved_previous_timestamp="${previous_timestamp:-}"
    if GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=false SSH_ASKPASS=false \
       GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh} -oBatchMode=yes -oConnectTimeout=10" \
       git -C "$root" -c credential.interactive=never \
           -c http.lowSpeedLimit=1 -c http.lowSpeedTime=10 pull --ff-only; then
        if ! yafp-reload; then
            yafp_update_message error ' RELOAD FAILED: restart YAFP after fixing its configuration.'
        fi
        this_command=$saved_this_command previous_command=$saved_previous_command
        previous_timestamp=$saved_previous_timestamp
    else
        yafp_update_message error ' UPDATE FAILED: YAFP was not reloaded.'
    fi
    return 0
}

yafp_update_cleanup() {
    if [ -n "${ZSH_VERSION:-}" ]; then emulate -L zsh -o KSH_ARRAYS; fi
    if [ -n "${YAFP_UPDATE_DIR:-}" ]; then
        rm -f -- "$YAFP_UPDATE_DIR/sample" "$YAFP_UPDATE_DIR/sample.tmp" 2>/dev/null
        rmdir -- "$YAFP_UPDATE_DIR" 2>/dev/null || true
    fi
    YAFP_UPDATE_DIR=''
}

yafp_update_on_load() {
    [ "${YAFP_UPDATE_CHECK:-1}" != 0 ] || return 0
    [ "${YAFP_UPDATE_SESSION_PID:-}" != "$$" ] || return 0
    YAFP_UPDATE_SESSION_PID=$$
    yafp_update_start
    yafp_update_notice
}

# These are complete terminal lines, not Readline/zsh prompt fragments.
yafp_update_message() {
    local severity="$1" text="$2" color=''
    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
        case "$severity" in
            info) color=$'\033[0;97m' ;;
            warning) color=${cRemotePending:-$'\033[0;48;2;255;255;0;38;2;0;0;0m'} ;;
            error)
                color=${cRemoteProblem:-$'\033[0;97;41m'}
                if [ -z "${cRemoteProblem:-}" ] && [ "${YAFP_DARKC:-1}" = 0 ]; then color=$'\033[0;97;101m'; fi ;;
            success) color=${cRemoteConnection:-$'\033[0;97;42m'} ;;
        esac
        printf '%s%s\033[0m\n' "$color" "$text"
    else
        printf '%s\n' "$text"
    fi
}
