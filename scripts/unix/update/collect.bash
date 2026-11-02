#!/usr/bin/env bash
# One private startup check; stdout/stderr are disconnected by the launcher.
root=$1
sample=$2
timeout_seconds=${3:-15}
state=missing-git ahead=0 behind=0 head=- branch=- upstream=- child=''
# Give Git its own process group so timeout/exit cleanup also stops SSH helpers.
set -m
trap '[ -z "$child" ] || kill -- -"$child" 2>/dev/null || true' EXIT
trap 'exit 1' HUP INT TERM

if command -v git >/dev/null 2>&1; then
    state=not-git
    if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        state=unborn
        if git -C "$root" rev-parse --verify HEAD >/dev/null 2>&1; then
            state=detached
            branch=$(git -C "$root" symbolic-ref --quiet HEAD 2>/dev/null) || branch=-
            upstream=$(git -C "$root" rev-parse --symbolic-full-name '@{upstream}' 2>/dev/null) || upstream=-
            remote=$(git -C "$root" config --get "branch.${branch#refs/heads/}.remote" 2>/dev/null) || remote=''
            [ "$branch" = - ] || state=no-upstream
            [ "$upstream" = - ] || state=no-remote
            if [ "$branch" != - ] && [ "$upstream" != - ] && [ -n "$remote" ] && [ "$remote" != . ]; then
                state=error
                # HTTP stalls and SSH connection/authentication are bounded and noninteractive.
                GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=false SSH_ASKPASS=false \
                GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh} -oBatchMode=yes -oConnectTimeout=10" \
                    git -C "$root" -c credential.interactive=never \
                    -c http.lowSpeedLimit=1 -c http.lowSpeedTime=10 \
                    fetch --quiet --no-tags -- "$remote" &
                child=$!
                started=$SECONDS
                timed_out=0
                while kill -0 "$child" 2>/dev/null; do
                    if [ "$((SECONDS - started))" -ge "$timeout_seconds" ]; then
                        kill -KILL -- -"$child" 2>/dev/null || true
                        timed_out=1
                        break
                    fi
                    sleep 0.1
                done
                if wait "$child"; then
                    head=$(git -C "$root" rev-parse --verify HEAD 2>/dev/null) || head=-
                    behind=$(git -C "$root" rev-list --count 'HEAD..@{upstream}' 2>/dev/null) || behind=-
                    ahead=$(git -C "$root" rev-list --count '@{upstream}..HEAD' 2>/dev/null) || ahead=-
                    case "$behind/$ahead" in
                        *[!0-9/]*|/|/*|*/) behind=0 ahead=0 ;;
                        *) if [ "$head" != - ] && [ "$timed_out" = 0 ]; then state=ok; fi ;;
                    esac
                fi
                child=''
        fi
    fi
    fi
fi
printf '%s %s %s %s %s %s\n' "$state" "$behind" "$head" "$branch" "$upstream" "$ahead" > "$sample.tmp" &&
    mv -f -- "$sample.tmp" "$sample"
