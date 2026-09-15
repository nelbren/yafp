#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/yafp-remote-test.XXXXXX")"
export TERM="${TERM:-xterm-256color}"
export YAFP_NO_INSTALL_HOOKS=1

cleanup() {
    rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
    printf 'not ok - %s\n' "$1" >&2
    exit 1
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local label="$3"

    [ "$expected" = "$actual" ] || \
        fail "$label: expected [$expected], got [$actual]"
}

assert_git_sync_command() {
    local command_text="$1"
    local expected="$2"
    local actual

    if yafp_is_git_sync_command "$command_text"; then
        actual=1
    else
        actual=0
    fi
    assert_eq "$expected" "$actual" "sync command: $command_text"
}

git init --quiet --bare --initial-branch=main "$TEST_ROOT/origin.git"
git init --quiet --initial-branch=main "$TEST_ROOT/writer"
git -C "$TEST_ROOT/writer" config user.name 'YAFP Test'
git -C "$TEST_ROOT/writer" config user.email 'yafp@example.invalid'
git -C "$TEST_ROOT/writer" config maintenance.auto false
git -C "$TEST_ROOT/writer" remote add origin "$TEST_ROOT/origin.git"
printf 'initial\n' > "$TEST_ROOT/writer/file.txt"
git -C "$TEST_ROOT/writer" add file.txt
git -C "$TEST_ROOT/writer" commit --quiet -m initial
git -C "$TEST_ROOT/writer" push --quiet --set-upstream origin main

git clone --quiet "$TEST_ROOT/origin.git" "$TEST_ROOT/local"
git -C "$TEST_ROOT/local" config maintenance.auto false
printf 'remote change\n' >> "$TEST_ROOT/writer/file.txt"
git -C "$TEST_ROOT/writer" commit --quiet -am remote-change
git -C "$TEST_ROOT/writer" push --quiet origin main

YAFP_RUNTIME="$TEST_ROOT/runtime"
mkdir -p "$YAFP_RUNTIME"
cp "$ROOT_DIR/yafp-ps1.bash" "$YAFP_RUNTIME/yafp-ps1.bash"
cp "$ROOT_DIR/yafp-cfg.bash.example" "$YAFP_RUNTIME/yafp-cfg.bash"
cp -R "$ROOT_DIR/themes" "$YAFP_RUNTIME/themes"

# shellcheck source=../yafp-ps1.bash
set +u
. "$YAFP_RUNTIME/yafp-ps1.bash"
set -u
trap - DEBUG
PROMPT_COMMAND=

cache_file="$TEST_ROOT/local/.git/yafp-remote-status"
YAFP_REMOTE_CHECK_INTERVAL=300
YAFP_REMOTE_COUNTDOWN_STYLE=numeric
YAFP_STATUS_PROGRESS_STYLE=blocks

yafp_git_status_counts $'M  staged modification\nA  staged addition\nR  old -> new\n D deleted\n M modified\nMM both\n?? untracked\nUU conflict'
assert_eq 4 "$yafp_ctx_git_staged" 'staged Git count'
assert_eq 2 "$yafp_ctx_git_change" 'unstaged Git change count'
assert_eq 1 "$yafp_ctx_git_delete" 'unstaged Git deletion count'
assert_eq 1 "$yafp_ctx_git_new" 'untracked Git count'

set +u
git_counts="$(theme_render_git_counts)"
staged_warning="$(theme_render_staged_warning)"
set -u
case "$git_counts" in
    *'📦4'*) ;;
    *) fail 'staged Git indicator was not rendered' ;;
esac
case "$staged_warning" in
    *'⚠️ COMMIT PENDING: 4 staged files are ready to commit ⚠️'*) ;;
    *) fail 'staged Git warning was not rendered' ;;
esac
case "$staged_warning" in
    "$(ps1_wrap "$cRemotePending")"*) ;;
    *) fail 'staged Git warning is not yellow' ;;
esac
yafp_ctx_git_staged=1
set +u
staged_warning="$(theme_render_staged_warning)"
set -u
case "$staged_warning" in
    *'⚠️ COMMIT PENDING: 1 staged file is ready to commit ⚠️'*) ;;
    *) fail 'singular staged Git warning was not rendered' ;;
esac
yafp_ctx_git_staged=0

status_report="$(yafp_remote_status_report current 0 0 0 175 300 0)"
case "$status_report" in
    *'🌐       Remote: ✓ Up to date'*) ;;
    *) fail 'detailed status omitted the remote state' ;;
esac
case "$status_report" in
    *'🟡        Timer: ████░░░░░░ 42% · 125/300s elapsed · 175s remaining'*) ;;
    *) fail 'detailed status omitted the timer progress' ;;
esac
case "$status_report" in
    *'🕘 Current time: '*) ;;
    *) fail 'detailed status omitted the current time' ;;
esac
assert_eq GREEN "$(yafp_remote_state_tone current)" \
    'current state intense green tone'
assert_eq YELLOW "$(yafp_remote_state_tone ahead)" \
    'ahead state intense yellow tone'
assert_eq YELLOW "$(yafp_remote_state_tone checking)" \
    'checking state intense yellow tone'
assert_eq YELLOW "$(yafp_remote_state_tone current 1)" \
    'refreshing state intense yellow tone'
assert_eq RED "$(yafp_remote_state_tone behind)" \
    'behind state intense red tone'
assert_eq RED "$(yafp_remote_state_tone diverged)" \
    'diverged state intense red tone'
assert_eq RED "$(yafp_remote_state_tone error)" \
    'offline state intense red tone'
assert_eq WHITE "$(yafp_current_time_tone)" \
    'current time intense white tone'
assert_eq YELLOW "$(yafp_next_check_tone)" \
    'next check intense yellow tone'
yafp_remote_timer_style 198 300
assert_eq '🟢|GREEN' \
    "$yafp_status_timer_emoji|$yafp_status_timer_tone" \
    'timer green threshold'
yafp_remote_timer_style 99 300
assert_eq '🟡|YELLOW' \
    "$yafp_status_timer_emoji|$yafp_status_timer_tone" \
    'timer yellow threshold'
yafp_remote_timer_style 98 300
assert_eq '🔴|RED' \
    "$yafp_status_timer_emoji|$yafp_status_timer_tone" \
    'timer red threshold'
YAFP_STATUS_PROGRESS_STYLE=symbols
status_report="$(yafp_remote_status_report current 0 0 0 175 300 0)"
case "$status_report" in
    *'🟡        Timer: ⣿⣿⣿⣿⣀      42% · 125/300s elapsed · 175s remaining'*) ;;
    *) fail 'Braille status progress was not rendered' ;;
esac
YAFP_STATUS_PROGRESS_STYLE=blocks
declare -F yafp-status >/dev/null || fail 'yafp-status command is unavailable'
declare -F yafp-refresh >/dev/null || fail 'yafp-refresh command is unavailable'
declare -F yafp-demo >/dev/null || fail 'yafp-demo command is unavailable'
case "$(declare -f yafp-demo)" in
    *'Control+C to break this ♾️  loop 🔁 (%ss)'*) ;;
    *) fail 'yafp-demo interruption hint is unavailable' ;;
esac
case "$(declare -f yafp-demo)" in
    *"sleep \"\$sleep_segs\""*) ;;
    *) fail 'yafp-demo does not reuse its configured sleep interval' ;;
esac
case "$(declare -f yafp-demo)" in
    *'yafp_prompt_preview'*) ;;
    *) fail 'yafp-demo does not render a prompt preview' ;;
esac
preview_user="${USER:-yafp-test-user}"
preview_host="${HOSTNAME:-yafp-test-host}"
preview_output="$(
    USER="$preview_user"
    HOSTNAME="$preview_host"
    SSH_CLIENT="${SSH_CLIENT:-}"
    YAFP_REPOS=0
    YAFP_PVENV=0
    YAFP_ERROR=0
    YAFP_CLOCK=0
    yafp_prompt_preview
)"
case "$preview_output" in
    *'\['*|*'\]'*|*'\u'*|*'\h'*|*'\w'*)
        fail 'Bash prompt preview exposes PS1 control escapes'
        ;;
esac
case "$preview_output" in
    *"${preview_user}"*) ;;
    *) fail 'Bash prompt preview omitted the current user' ;;
esac
case "$preview_output" in
    *"${preview_host%%.*}"*) ;;
    *) fail 'Bash prompt preview omitted the current host' ;;
esac

refresh_args="$TEST_ROOT/refresh-args"
(
    # shellcheck disable=SC2317,SC2329
    yafp_remote_context() {
        printf '%s|%s|%s' "$1" "$2" "$3" > "$refresh_args"
    }
    cd "$TEST_ROOT/local"
    yafp-refresh
)
case "$(< "$refresh_args")" in
    *'/local|main|1') ;;
    *) fail 'manual refresh command did not force the cached context' ;;
esac

yafp_remote_countdown_indicator 300
assert_eq '(300)' "$yafp_remote_countdown_text" 'numeric countdown indicator'
YAFP_REMOTE_COUNTDOWN_STYLE=symbols
yafp_remote_countdown_color_index=0
yafp_remote_countdown_indicator 300
assert_eq '⣿' "$yafp_remote_countdown_text" \
    'full symbolic countdown indicator'
assert_eq 'bright' "$yafp_remote_countdown_tone" \
    'initial symbolic countdown tone'
yafp_remote_countdown_advance_color 300
assert_eq 1 "$yafp_remote_countdown_color_index" \
    'symbolic countdown color advances outside renderer subshell'
yafp_remote_countdown_indicator 280
assert_eq '⣿' "$yafp_remote_countdown_text" \
    'stable symbolic countdown indicator during color change'
assert_eq 'normal' "$yafp_remote_countdown_tone" \
    'middle symbolic countdown tone'
yafp_remote_countdown_advance_color 280
yafp_remote_countdown_indicator 270
assert_eq '⣿' "$yafp_remote_countdown_text" \
    'stable symbolic countdown indicator before next level'
assert_eq 'dim' "$yafp_remote_countdown_tone" \
    'last symbolic countdown tone'
yafp_remote_countdown_advance_color 270
yafp_remote_countdown_indicator 250
assert_eq '⣷' "$yafp_remote_countdown_text" \
    'decreasing symbolic countdown indicator'
yafp_remote_countdown_indicator 1
assert_eq '⡀' "$yafp_remote_countdown_text" \
    'last symbolic countdown indicator'
yafp_remote_countdown_indicator 0
assert_eq '' "$yafp_remote_countdown_text" \
    'expired symbolic countdown indicator'
YAFP_REMOTE_COUNTDOWN_STYLE=invalid
yafp_remote_countdown_indicator 250
assert_eq '(250)' "$yafp_remote_countdown_text" 'invalid countdown style fallback'
YAFP_REMOTE_COUNTDOWN_STYLE=numeric

yafp_remote_context "$TEST_ROOT/local" main
assert_eq checking "$yafp_ctx_git_remote_state" 'initial asynchronous state'
set +u
indicator="$(theme_render_git_remote_status)"
set -u
case "$indicator" in
    *'…'*) ;;
    *) fail 'checking indicator was not rendered' ;;
esac

for _ in {1..100}; do
    [ -r "$cache_file" ] && break
    sleep 0.05
done
[ -r "$cache_file" ] || fail 'background check did not create its cache'

yafp_remote_context "$TEST_ROOT/local" main
assert_eq behind "$yafp_ctx_git_remote_state" 'remote state'
assert_eq 1 "$yafp_ctx_git_behind" 'behind count'
assert_eq origin/main "$yafp_ctx_git_upstream" 'upstream name'
[[ "$yafp_ctx_git_remote_refresh_in" =~ ^[0-9]+$ ]] ||
    fail 'refresh countdown was not calculated'
[ "$yafp_ctx_git_remote_refresh_in" -le 300 ] ||
    fail 'refresh countdown exceeds the configured interval'
IFS=$'\t' read -r _ _ _ _ _ _ cached_local_oid cached_upstream_oid \
    < "$cache_file"
assert_eq "$(git -C "$TEST_ROOT/local" rev-parse HEAD)" \
    "$cached_local_oid" 'cached local object ID'
assert_eq "$(git -C "$TEST_ROOT/local" rev-parse origin/main)" \
    "$cached_upstream_oid" 'cached upstream object ID'
set +u
indicator="$(theme_render_git_remote_status)"
set -u
case "$indicator" in
    *'('*') '*'⇣1'*) ;;
    *) fail 'behind indicator was not rendered' ;;
esac

mkdir "${cache_file}.lock"
printf '%s\n' "$$" > "${cache_file}.lock/pid"
yafp_remote_context "$TEST_ROOT/local" main
assert_eq 1 "$yafp_ctx_git_remote_refreshing" \
    'active remote worker remains visible across renders'
assert_eq 0 "$yafp_ctx_git_remote_refresh_in" \
    'active remote worker hides the cached countdown'
rm -f "${cache_file}.lock/pid"
rmdir "${cache_file}.lock"

git -C "$TEST_ROOT/local" update-ref refs/remotes/origin/main HEAD
yafp_remote_context "$TEST_ROOT/local" main
assert_eq checking "$yafp_ctx_git_remote_state" \
    'upstream object ID change invalidated the cached state'
set +u
warning="$(theme_render_remote_warning)"
set -u
assert_eq '' "$warning" \
    'invalidated ahead or behind state does not render a stale warning'
for _ in {1..100}; do
    [ ! -d "${cache_file}.lock" ] && break
    sleep 0.05
done
[ ! -d "${cache_file}.lock" ] ||
    fail 'upstream-change refresh did not complete'
yafp_remote_context "$TEST_ROOT/local" main
assert_eq behind "$yafp_ctx_git_remote_state" \
    'upstream-change refresh restored the remote state'

original_dir="$PWD"
YAFP_INITIAL_REMOTE_CHECK_PENDING=1
cd "$TEST_ROOT"
set +e
set +u
yafp_git_context 0
set -u
set -e
assert_eq 1 "$YAFP_INITIAL_REMOTE_CHECK_PENDING" \
    'non-repository prompt preserved initial refresh'
assert_eq '' "$yafp_ctx_git_remote_state" \
    'non-repository prompt cleared remote state'
set +u
warning="$(theme_render_remote_warning)"
set -u
assert_eq '' "$warning" \
    'non-repository prompt cleared remote warning'

cd "$TEST_ROOT/local"
this_command=''
set +e
set +u
yafp_git_context 0
set -u
set -e
assert_eq 0 "$YAFP_INITIAL_REMOTE_CHECK_PENDING" \
    'repository prompt consumed initial refresh'
assert_eq 1 "$yafp_ctx_git_remote_refreshing" \
    'repository startup forced a remote refresh'
assert_eq 0 "$yafp_ctx_git_remote_refresh_in" \
    'repository startup bypassed the cached countdown'
cd "$original_dir"
for _ in {1..100}; do
    [ ! -d "${cache_file}.lock" ] && break
    sleep 0.05
done
[ ! -d "${cache_file}.lock" ] ||
    fail 'repository startup refresh did not complete'

assert_git_sync_command 'git push' 1
assert_git_sync_command 'git fetch origin' 1
assert_git_sync_command 'git pull --ff-only' 1
assert_git_sync_command 'git -C other-repo push' 1
assert_git_sync_command 'command git fetch' 1
assert_git_sync_command 'git status' 0
assert_git_sync_command 'echo "git push"' 0

YAFP_GIT_SYNC_LAST_COMMAND_KEY=""
yafp_should_force_remote_refresh 'git push' 0 ||
    fail 'successful push did not request a refresh'
if yafp_should_force_remote_refresh 'git push' 0; then
    fail 'the same push requested a second refresh'
fi
YAFP_GIT_SYNC_LAST_COMMAND_KEY=""
if yafp_should_force_remote_refresh 'git pull' 1; then
    fail 'failed pull requested a refresh'
fi
if yafp_should_force_remote_refresh 'git pull' 0; then
    fail 'failed pull was refreshed later by an empty prompt'
fi

mkdir "${cache_file}.lock"
yafp_remote_context "$TEST_ROOT/local" main 1
for _ in {1..100}; do
    [ ! -d "${cache_file}.lock" ] && break
    sleep 0.05
done
[ ! -d "${cache_file}.lock" ] ||
    fail 'legacy lock without a worker PID was not recovered'

mkdir "${cache_file}.lock"
printf '99999999\n' > "${cache_file}.lock/pid"
yafp_remote_context "$TEST_ROOT/local" main 1
assert_eq 1 "$yafp_ctx_git_remote_refreshing" 'forced refresh state'
assert_eq 0 "$yafp_ctx_git_remote_refresh_in" 'forced refresh countdown'
for _ in {1..100}; do
    [ ! -d "${cache_file}.lock" ] && break
    sleep 0.05
done
[ ! -d "${cache_file}.lock" ] || fail 'forced refresh did not complete'
yafp_remote_context "$TEST_ROOT/local" main
[ "$yafp_ctx_git_remote_refresh_in" -gt 0 ] ||
    fail 'forced refresh did not reset the countdown'

yafp_ctx_git_remote_state=current
set +u
indicator="$(theme_render_git_remote_status)"
set -u
case "$indicator" in
    *'✓'*) ;;
    *) fail 'current indicator was not rendered' ;;
esac

yafp_ctx_git_remote_state=ahead
yafp_ctx_git_ahead=2
set +u
indicator="$(theme_render_git_remote_status)"
set -u
case "$indicator" in
    *'⇡2'*) ;;
    *) fail 'ahead indicator was not rendered' ;;
esac
case "$indicator" in
    *"$(ps1_wrap "$cRemotePending")"⇡2*) ;;
    *) fail 'ahead indicator is not intense yellow' ;;
esac

set +u
warning="$(theme_render_remote_warning)"
set -u
case "$warning" in
    *'⚠️ REMOTE NOT UPDATED: 2 local commits have not been pushed to origin/main ⚠️'*) ;;
    *) fail 'ahead warning was not rendered' ;;
esac
assert_eq '\n' "${warning: -2}" 'ahead warning line break'

yafp_ctx_git_remote_state=error
set +u
indicator="$(theme_render_git_remote_status)"
warning="$(theme_render_remote_warning)"
set -u
case "$indicator" in
    *'❕'*) ;;
    *) fail 'offline indicator was not rendered' ;;
esac
case "$warning" in
    *'⚡️ No internet connection.'*) ;;
    *) fail 'offline warning was not rendered' ;;
esac
assert_eq '\n' "${warning: -2}" 'offline warning line break'

yafp_ctx_git_remote_state=behind
yafp_ctx_git_ahead=0

set +u
warning="$(theme_render_remote_warning)"
set -u
case "$warning" in
    *'OUTDATED REPOSITORY'*'1 commit is missing from origin/main'*) ;;
    *) fail 'behind warning was not rendered' ;;
esac
assert_eq '\n' "${warning: -2}" 'warning line break'

git -C "$TEST_ROOT/local" config user.name 'YAFP Test'
git -C "$TEST_ROOT/local" config user.email 'yafp@example.invalid'
printf 'local change\n' > "$TEST_ROOT/local/local.txt"
git -C "$TEST_ROOT/local" add local.txt
git -C "$TEST_ROOT/local" commit --quiet -m local-change
(
    yafp_remote_check_worker \
        "$TEST_ROOT/local" refs/heads/main origin/main origin \
        "$cache_file" "${cache_file}.lock"
)
yafp_remote_context "$TEST_ROOT/local" main
assert_eq diverged "$yafp_ctx_git_remote_state" 'diverged state'
assert_eq 1 "$yafp_ctx_git_ahead" 'ahead count'
assert_eq 1 "$yafp_ctx_git_behind" 'diverged behind count'
set +u
indicator="$(theme_render_git_remote_status)"
set -u
case "$indicator" in
    *'⇡1⇣1'*) ;;
    *) fail 'diverged indicator was not rendered' ;;
esac

YAFP_REMOTE_COUNTDOWN_STYLE=symbols
yafp_remote_countdown_color_index=0
YAFP_OSC133=0
YAFP_TITLE=0
cd "$TEST_ROOT/local"
set +e
set +u
yafp_prompt_command
set -u
set -e
assert_eq 1 "$yafp_remote_countdown_color_index" \
    'first prompt render persisted the symbolic countdown color'
set +e
set +u
yafp_prompt_command
set -u
set -e
assert_eq 2 "$yafp_remote_countdown_color_index" \
    'second prompt render persisted the next symbolic countdown color'

YAFP_REMOTE_COUNTDOWN_STYLE=numeric
YAFP_REMOTE_CHECK_INTERVAL=0
yafp_remote_context "$TEST_ROOT/local" main
assert_eq '' "$yafp_ctx_git_remote_state" 'disabled state'

printf 'ok - asynchronous remote status and disabled interval\n'
