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
COLUMNS=200

assert_eq 'transparent/GREEN' \
    "$YAFP_COLOR_REMOTE_OK_BG/$YAFP_COLOR_REMOTE_OK_FG" \
    'current remote color scheme'
assert_eq 'intense-yellow/black' \
    "$YAFP_COLOR_REMOTE_PENDING_BG/$YAFP_COLOR_REMOTE_PENDING_FG" \
    'warning expansion color scheme'
COLUMNS=72
# Separators contain raw terminal colors as well as Readline-wrapped colors.
# Their bytes must not move the measured indicator or wrap it modulo COLUMNS.
printf -v colored_prefix '%49s' ''
colored_prefix=$'\033(B\033[m\033[37m'"$colored_prefix"$'\033[93m'
colored_prefix=$'\033(B\033[m\033[37m\033[93m'"$colored_prefix"$'\033(B\033[m\033[37m\033[93m'
yafp_ctx_host=MBP02
yafp_measure_indicator_column "$YAFP_STAGED_EXPANSION_MARKER" \
    "${colored_prefix}${YAFP_STAGED_EXPANSION_MARKER}"
assert_eq 50 "$yafp_indicator_column" \
    'raw terminal styles do not change the measured staged column'
for test_locale in en_US.UTF-8 es_ES.UTF-8; do
    case "$(locale -a)" in
        *"$test_locale"*) ;;
        *) continue ;;
    esac
    (
        export LC_ALL="$test_locale"
        COLUMNS=119
        yafp_measure_indicator_column "$YAFP_STAGED_EXPANSION_MARKER" \
            "é${colored_prefix}${YAFP_STAGED_EXPANSION_MARKER}"
        assert_eq 51 "$yafp_indicator_column" \
            "ANSI stripping and Unicode width under $test_locale"
        assert_eq "$test_locale" "$LC_ALL" 'ANSI stripping preserves locale'
        yafp_ctx_git_staged=12
        yafp_ctx_git_staged_indicator_column=$yafp_indicator_column
        for COLUMNS in 119 60 119; do
            banner_output="$(theme_render_staged_expansion)"
            if [ "$COLUMNS" -eq 60 ]; then
                assert_eq '' "$banner_output" 'narrow banner stays hidden'
            else
                case "$banner_output" in
                    *'12 staged files are ready to commit'*) ;;
                    *) fail "wide banner missing under $test_locale" ;;
                esac
            fi
        done
    )
done
yafp_ctx_git_staged=12
yafp_ctx_git_delete=0
yafp_ctx_git_change=0
yafp_ctx_git_new=0
yafp_ctx_git_staged_indicator_column=$yafp_indicator_column
case "$(theme_render_staged_expansion)" in
    *'⎝ COMMIT PENDING: 12 ⎠'*) ;;
    *) fail 'colored prompt selected an overflowing detailed staged banner' ;;
esac
yafp_ctx_git_staged_indicator_column=0
for narrow_column in 65 70; do
    yafp_ctx_git_staged_indicator_column=$narrow_column
    assert_eq '' "$(theme_render_staged_expansion)" \
        'staged banner is hidden when even its short form overflows'
    case "$(theme_render_git_counts)" in
        *'📦12'*) ;;
        *) fail 'hiding the staged banner removed the staged indicator' ;;
    esac
done
yafp_ctx_git_staged_indicator_column=0
COLUMNS=15
assert_eq '' "$(theme_render_staged_expansion)" \
    'staged banner is hidden when narrower than the short text'
COLUMNS=72
theme_select_expansion_message \
    'COMMIT PENDING: 12 staged files are ready to commit' \
    'COMMIT PENDING: 12' 50 4
assert_eq 'COMMIT PENDING: 12' "$yafp_expansion_message" \
    'staged expansion accounts for its indicator column'
theme_select_expansion_message \
    'COMMIT PENDING: 12 staged files are ready to commit' \
    'COMMIT PENDING: 12' 30 4
assert_eq 'COMMIT PENDING: 12 staged files are ready to commit' \
    "$yafp_expansion_message" \
    'staged expansion keeps the long message when centered text fits'
COLUMNS=80
theme_select_expansion_message \
    'COMMIT PENDING: 12 staged files are ready to commit' \
    'COMMIT PENDING: 12' 44 4
assert_eq 'COMMIT PENDING: 12' "$yafp_expansion_message" \
    'staged expansion protects against a stale terminal width'
COLUMNS=200

yafp_git_status_counts $'M  staged modification\nA  staged addition\nR  old -> new\n D deleted\n M modified\nMM both\n?? untracked\nUU conflict'
assert_eq 4 "$yafp_ctx_git_staged" 'staged Git count'
assert_eq 2 "$yafp_ctx_git_change" 'unstaged Git change count'
assert_eq 1 "$yafp_ctx_git_delete" 'unstaged Git deletion count'
assert_eq 1 "$yafp_ctx_git_new" 'untracked Git count'

set +u
git_counts="$(theme_render_git_counts)"
staged_expansion="$(theme_render_staged_expansion)"
set -u
case "$git_counts" in
    *'📦4'*) ;;
    *) fail 'staged Git indicator was not rendered' ;;
esac
case "$staged_expansion" in
    *'⎝ COMMIT PENDING: 4 staged files are ready to commit ⎠'*) ;;
    *) fail 'staged Git expansion was not rendered' ;;
esac
case "$git_counts" in
    *"$(ps1_wrap "$cGitStaged")"'📦4'*) ;;
    *) fail 'staged Git indicator does not use the warning color scheme' ;;
esac
yafp_ctx_git_staged=1
set +u
staged_expansion="$(theme_render_staged_expansion)"
set -u
case "$staged_expansion" in
    *'⎝ COMMIT PENDING: 1 staged file is ready to commit ⎠'*) ;;
    *) fail 'singular staged Git expansion was not rendered' ;;
esac
COLUMNS=21
case "$(theme_render_staged_expansion)" in
    *'⎝ COMMIT PENDING: 1 ⎠'*) ;;
    *) fail 'compact staged Git expansion was not rendered' ;;
esac
COLUMNS=200
yafp_ctx_git_remote_state=ahead
case "$(theme_render_staged_expansion)" in
    *$'\033[2A'*) ;;
    *) fail 'staged Git expansion did not preserve the remote expansion row' ;;
esac
yafp_ctx_git_remote_state=current
yafp_ctx_git_staged=0

status_report="$(yafp_remote_status_report current 0 0 0 175 300 0)"
case "$status_report" in
    *'🌐︎       Remote: ✓ Up to date'*) ;;
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
declare -F yafp-ack >/dev/null || fail 'yafp-ack command is unavailable'
declare -F yafp-demo >/dev/null || fail 'yafp-demo command is unavailable'
declare -F yafp-help >/dev/null || fail 'yafp-help command is unavailable'
declare -F yafp-stats >/dev/null || fail 'yafp-stats command is unavailable'
expected_help="$(printf '%s\n' \
    'yafp-status • Show remote status and refresh timer.' \
    'yafp-refresh • Request an immediate remote refresh.' \
    'yafp-ack • Acknowledge the current offline alert.' \
    'yafp-reload • Reload YAFP in the current shell.' \
    'yafp-stats • Show command execution statistics.' \
    'yafp-help • Show available YAFP commands.')"
assert_eq "$expected_help" "$(yafp-help)" 'yafp-help output'

original_remote_context="$(declare -f yafp_remote_context)"
# shellcheck disable=SC2329
yafp_remote_context() {
    yafp_ctx_git_remote_state=error
}
YAFP_REMOTE_OFFLINE_ACKNOWLEDGED=0
yafp-ack > "$TEST_ROOT/yafp-ack-output"
assert_eq 1 "$YAFP_REMOTE_OFFLINE_ACKNOWLEDGED" \
    'yafp-ack acknowledges the current offline alert'
assert_eq 'Offline alert acknowledged.' \
    "$(< "$TEST_ROOT/yafp-ack-output")" 'yafp-ack confirmation'
eval "$original_remote_context"

YAFP_COMMANDS_TOTAL=0
YAFP_COMMANDS_SUCCEEDED=0
YAFP_COMMANDS_FAILED=0
YAFP_COMMAND_STATS_LAST_KEY=''
yafp_record_command_stats 'true' 0
yafp_record_command_stats 'true' 0 || true
yafp_record_command_stats 'false' 1
assert_eq 2 "$YAFP_COMMANDS_TOTAL" 'command total count'
assert_eq 1 "$YAFP_COMMANDS_SUCCEEDED" 'successful command count'
assert_eq 1 "$YAFP_COMMANDS_FAILED" 'failed command count'
printf -v stats_separator_one_digit '%*s' 21 ''
stats_separator_one_digit=${stats_separator_one_digit// /━}
expected_stats="$(printf '%s\n' \
    '✓ Succeeded: 1 (050%)' \
    '☒ Failed:    1 (050%)' \
    "$stats_separator_one_digit" \
    '∑ Total:     2 (100%)')"
assert_eq "$expected_stats" "$(yafp-stats)" 'yafp-stats output'
YAFP_COMMANDS_TOTAL=0
YAFP_COMMANDS_SUCCEEDED=0
YAFP_COMMANDS_FAILED=0
expected_empty_stats="$(printf '%s\n' \
    '✓ Succeeded: 0 (000%)' \
    '☒ Failed:    0 (000%)' \
    "$stats_separator_one_digit" \
    '∑ Total:     0 (100%)')"
assert_eq "$expected_empty_stats" "$(yafp-stats)" 'empty yafp-stats output'
YAFP_COMMANDS_TOTAL=13
YAFP_COMMANDS_SUCCEEDED=11
YAFP_COMMANDS_FAILED=2
printf -v stats_separator_two_digits '%*s' 22 ''
stats_separator_two_digits=${stats_separator_two_digits// /━}
expected_aligned_stats="$(printf '%s\n' \
    '✓ Succeeded: 11 (085%)' \
    '☒ Failed:     2 (015%)' \
    "$stats_separator_two_digits" \
    '∑ Total:     13 (100%)')"
assert_eq "$expected_aligned_stats" "$(yafp-stats)" \
    'aligned yafp-stats output'
YAFP_COMMANDS_TOTAL=2
YAFP_COMMANDS_SUCCEEDED=1
YAFP_COMMANDS_FAILED=1
YAFP_STATS_ON_EXIT=0
YAFP_TEST_PREVIOUS_EXIT=0
YAFP_PREVIOUS_EXIT_TRAP_COMMAND='YAFP_TEST_PREVIOUS_EXIT=1'
yafp_exit_trap
assert_eq 1 "$YAFP_TEST_PREVIOUS_EXIT" 'previous EXIT trap command'
YAFP_PREVIOUS_EXIT_TRAP_COMMAND=''
YAFP_STATS_ON_EXIT=1
assert_eq "$expected_stats" "$(yafp_exit_trap)" 'exit statistics output'
set +u
# Loaded from yafp-ps1.bash above; a later definition is an intentional test double.
# shellcheck disable=SC2218
yafp-reload
set -u
assert_eq 2 "$YAFP_COMMANDS_TOTAL" 'total preserved after reload'
assert_eq 1 "$YAFP_COMMANDS_SUCCEEDED" 'succeeded preserved after reload'
assert_eq 1 "$YAFP_COMMANDS_FAILED" 'failed preserved after reload'
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
    *'\['*|*'\]'*|*'\e'*|*'\u'*|*'\h'*|*'\w'*|*'\$'*)
        fail 'Bash prompt preview exposes PS1 control escapes'
        ;;
esac
case "$preview_output" in
    *$'\033['*) ;;
    *) fail 'Bash prompt preview omitted rendered ANSI sequences' ;;
esac
preview_prompt_symbol='$'
if [ "${EUID:-1}" -eq 0 ]; then
    preview_prompt_symbol='#'
fi
case "$preview_output" in
    *"$preview_prompt_symbol"$'\033[0m\033[K '*) ;;
    *) fail 'Bash prompt preview omitted the rendered prompt mark' ;;
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
warning="$(theme_reserve_remote_expansion_row)"
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
warning="$(theme_reserve_remote_expansion_row)"
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
if ! yafp_is_git_pull_command 'git pull --ff-only'; then
    fail 'git pull was not detected for automatic reload'
fi
if yafp_is_git_pull_command 'git fetch origin'; then
    fail 'git fetch was detected as git pull'
fi

YAFP_AUTO_RELOAD=1
YAFP_LOADED_COMMIT=old-commit
yafp_reload_called=0
yafp_current_commit() {
    printf '%s\n' 'new-commit'
}
yafp-reload() {
    yafp_reload_called=1
    YAFP_LOADED_COMMIT=new-commit
}
yafp_maybe_auto_reload 'git pull --ff-only' 0 ||
    fail 'changed YAFP commit did not trigger automatic reload'
assert_eq 1 "$yafp_reload_called" 'automatic reload invocation'
if yafp_maybe_auto_reload 'git pull --ff-only' 0; then
    fail 'unchanged YAFP commit triggered automatic reload'
fi
YAFP_AUTO_RELOAD=0
YAFP_LOADED_COMMIT=old-commit
if yafp_maybe_auto_reload 'git pull' 0; then
    fail 'disabled automatic reload still ran'
fi

external_prompt_hook() {
    :
}
PROMPT_COMMAND='external_prompt_hook'
YAFP_PREVIOUS_PROMPT_COMMAND=''
yafp_install_prompt_command
yafp_install_prompt_command
assert_eq external_prompt_hook "$YAFP_PREVIOUS_PROMPT_COMMAND" \
    'PROMPT_COMMAND preserved across reloads'
PROMPT_COMMAND=
YAFP_PREVIOUS_PROMPT_COMMAND=

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

YAFP_REMOTE_CONNECTIVITY_STATE=offline
YAFP_SESSION_STARTED_AT=0
yafp_remote_context "$TEST_ROOT/local" main
assert_eq 1 "$yafp_ctx_git_remote_connection_announcement" \
    'first recovered remote check announces internet connection'
yafp_remote_context "$TEST_ROOT/local" main
assert_eq 0 "$yafp_ctx_git_remote_connection_announcement" \
    'internet connection is announced only once per transition'
YAFP_REMOTE_CONNECTIVITY_STATE=offline
yafp_remote_context "$TEST_ROOT/local" main
assert_eq 1 "$yafp_ctx_git_remote_connection_announcement" \
    'a later offline-to-online transition is announced again'

yafp_ctx_git_remote_state=current
yafp_ctx_git_remote_connection_announcement=1
set +u
warning="$(theme_reserve_remote_expansion_row)"
indicator="$(theme_render_git_remote_status)"
set -u
assert_eq '\n' "$warning" 'connection announcement row'
case "$indicator" in
    *'⎝ INTERNET CONNECTION ⎠'*'✓🌐︎'*) ;;
    *) fail 'connection announcement was not rendered' ;;
esac
case "$indicator" in
    *"$cRemoteConnection"'⎝ INTERNET CONNECTION ⎠'*"$(ps1_wrap "$cRemoteConnection")"'✓🌐︎'*) ;;
    *) fail 'connection transition is not intense white on normal green' ;;
esac
yafp_ctx_git_remote_connection_announcement=0
set +u
indicator="$(theme_render_git_remote_status)"
set -u
case "$indicator" in
    *'✓🌐︎'*) ;;
    *) fail 'current indicator was not rendered' ;;
esac
case "$indicator" in
    *"$(ps1_wrap "$cRemoteOk")"✓🌐︎*) ;;
    *) fail 'current indicator is not intense green' ;;
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
warning="$(theme_reserve_remote_expansion_row)"
set -u
case "$warning" in
    '\n') ;;
    *) fail 'ahead warning row was not reserved' ;;
esac
assert_eq '\n' "${warning: -2}" 'ahead warning line break'
case "$indicator" in
    *'⎝ REMOTE NOT UPDATED: 2 local commits have not been pushed to origin/main ⎠'*) ;;
    *) fail 'ahead expansion was not rendered' ;;
esac
COLUMNS=20
case "$(theme_render_git_remote_status)" in
    *'⎝ PUSH PENDING: 2 ⎠'*) ;;
    *) fail 'compact ahead expansion was not rendered' ;;
esac
COLUMNS=200

yafp_ctx_git_remote_state=error
set +u
indicator="$(theme_render_git_remote_status)"
warning="$(theme_reserve_remote_expansion_row)"
set -u
case "$indicator" in
    *'☒🌐︎'*) ;;
    *) fail 'offline indicator was not rendered' ;;
esac
case "$warning" in
    '\n') ;;
    *) fail 'offline warning row was not reserved' ;;
esac
assert_eq '\n' "${warning: -2}" 'offline warning line break'
case "$indicator" in
    *'⎝ NO INTERNET CONNECTION ⎠'*'☒🌐︎'*) ;;
    *) fail 'offline expansion was not rendered' ;;
esac
case "$indicator" in
    *$'\033[s\033[1A\033['*D*'⎝ NO INTERNET CONNECTION ⎠'*$'\033[u'*) ;;
    *) fail 'offline expansion was not centered above its indicator' ;;
esac

YAFP_REMOTE_OFFLINE_ACKNOWLEDGED=1
set +u
warning="$(theme_reserve_remote_expansion_row)"
indicator="$(theme_render_git_remote_status)"
set -u
assert_eq '' "$warning" 'acknowledged offline state reserves no banner row'
case "$indicator" in
    *'⎝ NO INTERNET CONNECTION ⎠'*)
        fail 'acknowledged offline banner was still rendered'
        ;;
    *"$(ps1_wrap "$cRemoteAcknowledged")"'☒🌐︎'*) ;;
    *) fail 'acknowledged offline indicator is not intense red on transparent' ;;
esac
YAFP_REMOTE_OFFLINE_ACKNOWLEDGED=0

yafp_ctx_git_remote_state=behind
yafp_ctx_git_ahead=0

set +u
warning="$(theme_reserve_remote_expansion_row)"
indicator="$(theme_render_git_remote_status)"
set -u
case "$indicator" in
    *'⎝ OUTDATED REPOSITORY'*'1 commit is missing from origin/main ⎠'*) ;;
    *) fail 'behind expansion was not rendered' ;;
esac
COLUMNS=20
case "$(theme_render_git_remote_status)" in
    *'⎝ PULL PENDING: 1 ⎠'*) ;;
    *) fail 'compact behind expansion was not rendered' ;;
esac
COLUMNS=200
assert_eq '\n' "${warning: -2}" 'warning line break'

yafp_ctx_git_remote_state=diverged
yafp_ctx_git_ahead=2
yafp_ctx_git_behind=3
set +u
indicator="$(theme_render_git_remote_status)"
set -u
case "$indicator" in
    *'⎝ DIVERGED REPOSITORY: local +2 / remote +3 relative to origin/main ⎠'*'⇡2⇣3'*) ;;
    *) fail 'diverged expansion was not rendered' ;;
esac
COLUMNS=20
case "$(theme_render_git_remote_status)" in
    *'⎝ DIVERGED: ⇡2 ⇣3 ⎠'*) ;;
    *) fail 'compact diverged expansion was not rendered' ;;
esac
COLUMNS=200

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
