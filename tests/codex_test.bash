#!/usr/bin/env bash
# Exercise the shared context under Bash and native zsh without network access.
if [ -n "${ZSH_VERSION:-}" ]; then emulate -LR zsh -o KSH_ARRAYS; fi
set -eo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_ROOT=$(mktemp -d)
export TERM=xterm-256color YAFP_NO_INSTALL_HOOKS=1 YAFP_METRICS_DISABLED=1
cleanup() { yafp_codex_cleanup; rm -rf -- "$TEST_ROOT"; }
trap cleanup EXIT
fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }
contains() { case "$1" in *"$2"*) ;; *) fail "$3: $1" ;; esac; }
plain_prompt() {
    if [ -n "${ZSH_VERSION:-}" ]; then out="$(print -Pr -- "$out")"
    else out=${out//\\[/}; out=${out//\\]/}; out=${out//\\e/$'\033'}
    fi
    yafp_strip_terminal_styles "$out"
    out=$yafp_plain_text
}
cp "$ROOT_DIR/yafp-ps1.bash" "$ROOT_DIR/yafp-ps1.zsh" "$TEST_ROOT/"
cp -R "$ROOT_DIR/themes" "$ROOT_DIR/scripts" "$TEST_ROOT/"
sed '/^YAFP_THEME=/d' "$ROOT_DIR/yafp-cfg.bash.example" > "$TEST_ROOT/yafp-cfg.bash"
sed '/^YAFP_THEME=/d' "$ROOT_DIR/yafp-cfg.zsh.example" > "$TEST_ROOT/yafp-cfg.zsh"
YAFP_CONFIG_FILE="$TEST_ROOT/yafp-cfg.zsh"
if [ -n "${ZSH_VERSION:-}" ]; then . "$TEST_ROOT/yafp-ps1.zsh"
else . "$TEST_ROOT/yafp-ps1.bash"
fi
for interval in 0 -1 bad 0008 999999999999999999; do
    YAFP_CODEX_CHECK_INTERVAL=$interval
    yafp_codex_context
    [ -z "$yafp_ctx_codex" ] || fail 'Invalid or disabled interval produced context'
    [ -z "${YAFP_CODEX_DIR:-}" ] || fail 'Disabled quota created a cache'
done
export YAFP_TEST_CODEX_READY="$TEST_ROOT/codex-ready"
cat > "$TEST_ROOT/scripts/unix/codex/collect.bash" <<'EOF'
#!/usr/bin/env bash
printf '%s account/rateLimits/read in-progress 10 %s\n' "$2" "$$" > "$1.debug.tmp"
mv "$1.debug.tmp" "$1.debug"
while [ ! -f "$YAFP_TEST_CODEX_READY" ]; do sleep 0.05; done
printf '%s parse-limits ok 25 %s\n' "$2" "$$" > "$1.debug.tmp"
mv "$1.debug.tmp" "$1.debug"
printf '%s ok 60 75 60 %s\n' "$2" "$(( $2 + 464460 ))" > "$1.tmp"
mv "$1.tmp" "$1"
EOF
YAFP_CODEX_CHECK_INTERVAL=300 YAFP_DEVEL=1
yafp_now_ms begin
yafp_codex_context
yafp_now_ms end
[ "$((end - begin))" -lt 500 ] || fail 'Quota worker blocked context'
# shellcheck disable=SC2153
pid=$YAFP_CODEX_PID
[ "$yafp_ctx_codex" = '֍⟳d⟳h' ] || fail 'Pending quota must show the loading symbol'
for theme in default minimal light; do
    YAFP_THEME=$theme
    load_theme
    theme_build
    for style in percent symbols; do
        YAFP_CODEX_VALUE_STYLE=$style
        yafp_codex_context
        [ "$yafp_ctx_codex_color" = 90 ] || fail 'Pending quota must remain gray'
        out="$(theme_render_codex)"
        plain_prompt
        [ "$out" = '↤[֍⟳d⟳h]' ] || fail "Pending quota reset placeholders: $theme/$style/$out"
    done
done
YAFP_CODEX_VALUE_STYLE=percent
for iteration in 1 2 3; do yafp_codex_context; done
[ "$YAFP_CODEX_PID" = "$pid" ] || fail 'Duplicate workers'
yafp-reload
YAFP_CODEX_CHECK_INTERVAL=300
yafp_codex_context
[ "$YAFP_CODEX_PID" = "$pid" ] || fail 'Reload duplicated worker'
touch "$YAFP_TEST_CODEX_READY"
for iteration in {1..60}; do
    [ ! -f "$YAFP_CODEX_DIR/sample" ] || break
    sleep 0.05
done
yafp_codex_context
[ "$yafp_ctx_codex" = '֍60%5d9h' ] || fail 'Remaining quota was not read'
out="$(yafp-codex)"
yafp_strip_terminal_styles "$out"
contains "$yafp_plain_text" '    Remaining: 60%' 'Diagnostic uses the limiting window'
contains "$yafp_plain_text" '        Reset: 5d9h' 'Diagnostic reset duration'
check_codex_debug() {
    local out saved_diagnostic worker_pid=$YAFP_CODEX_PID
    local YAFP_CODEX_PID='' YAFP_CODEX_ATTEMPT=$YAFP_CODEX_ATTEMPT
    saved_diagnostic=$(< "$YAFP_CODEX_DIR/sample.debug")
    out="$(yafp-codex)"
    case "$out" in *'Stage:'*) fail 'Default report exposed debug fields' ;; esac
    out="$(yafp-codex --debug)"
    contains "$out" 'Worker: idle' 'Completed worker'
    contains "$out" 'Stage: parse-limits' 'Last completed stage'
    contains "$out" 'Reason: ok' 'Last completed reason'
    contains "$out" 'Duration: 25ms' 'Final duration'
    printf '%s account/rateLimits/read in-progress 10 123\n' "$YAFP_CODEX_ATTEMPT" > "$YAFP_CODEX_DIR/sample.debug"
    YAFP_CODEX_PID=$$
    out="$(yafp-codex --debug)"
    contains "$out" "Worker: running (PID $$)" 'Live worker'
    contains "$out" 'Stage: account/rateLimits/read' 'Live request stage'
    contains "$out" 'Reason: in-progress' 'Live progress reason'
    contains "$out" 'ms (running)' 'Live duration'
    [ "$YAFP_CODEX_PID" = "$$" ] || fail 'Debug replaced an active worker'
    YAFP_CODEX_PID=''
    out="$(yafp-codex --debug)"
    contains "$out" 'Reason: worker-ended' 'Interrupted worker must not look active'
    printf '%s initialize rpc-error 15 123\n' "$YAFP_CODEX_ATTEMPT" > "$YAFP_CODEX_DIR/sample.debug"
    out="$(yafp-codex --debug)"
    contains "$out" 'Reason: rpc-error' 'Failure reason'
    for row in 'PRIVATE initialize rpc-error 10 1' '0 PRIVATE rpc-error 10 1' '0 initialize PRIVATE 10 1' '0 initialize rpc-error PRIVATE 1' '0 initialize rpc-error 10 PRIVATE' '0 initialize rpc-error 10 1 PRIVATE'; do
        printf '%s\n' "$row" > "$YAFP_CODEX_DIR/sample.debug"
        out="$(yafp-codex --debug)"
        contains "$out" 'Reason: no-diagnostics' 'Malformed diagnostic rejected'
        case "$out" in *PRIVATE*) fail 'Debug leaked unvalidated cache content' ;; esac
    done
    printf '%s initialize rpc-error 15 123\n' "$((YAFP_CODEX_ATTEMPT + 1))" > "$YAFP_CODEX_DIR/sample.debug"
    out="$(yafp-codex --debug)"
    contains "$out" 'Reason: no-diagnostics' 'Other attempt diagnostic rejected'
    rm "$YAFP_CODEX_DIR/sample.debug"
    out="$(yafp-codex --debug)"
    contains "$out" 'Reason: no-diagnostics' 'Legacy worker supported'
    if yafp-codex --invalid >/dev/null 2>&1; then fail 'Unknown option accepted'; fi
    printf '%s\n' "$saved_diagnostic" > "$YAFP_CODEX_DIR/sample.debug"
    YAFP_CODEX_PID=$worker_pid
}
check_codex_debug
check_codex_report() {
    local original_sample state icon color out expected reset
    local YAFP_CODEX_PID='' YAFP_CODEX_ATTEMPT=$SECONDS
    local YAFP_CODEX_VALUE_STYLE=symbols YAFP_CODEX_CHECK_INTERVAL=300
    original_sample=$(< "$YAFP_CODEX_DIR/sample")
    while IFS='|' read -r state icon color; do
        YAFP_CODEX_CHECK_INTERVAL=300 YAFP_CODEX_PID=''
        printf '%s %s 74 74 - %s\n' "$SECONDS" "$state" "$((SECONDS + 115230))" > "$YAFP_CODEX_DIR/sample"
        case "$state" in
            pending) rm "$YAFP_CODEX_DIR/sample"; YAFP_CODEX_PID=$$ ;;
            disabled) YAFP_CODEX_CHECK_INTERVAL=0 ;;
        esac
        out="$(yafp-codex)"
        contains "$out" "$(printf '\033[%sm' "$color")$icon $state" 'Report state color/icon'
        yafp_strip_terminal_styles "$out"
        contains "$yafp_plain_text" '┌' 'Diagnostic opening frame'
        contains "$yafp_plain_text" '┘' 'Diagnostic closing frame'
        contains "$yafp_plain_text" "        State: $icon $state" 'Semantic report state'
        if [ "$state" = ok ]; then
            contains "$yafp_plain_text" '    Remaining: 74%' 'Numeric availability in symbol mode'
            contains "$yafp_plain_text" '        Reset: 1d8h' 'Days/hours report reset'
        else
            contains "$yafp_plain_text" '    Remaining: ' 'Unavailable quota is not a stale percentage'
            contains "$yafp_plain_text" '        Reset: ' 'Unavailable reset is not invented'
        fi
    done < "$ROOT_DIR/tests/codex_report_cases.txt"
    YAFP_CODEX_PID='' YAFP_CODEX_CHECK_INTERVAL=300
    for reset in - 0; do
        printf '%s ok 74 74 - %s\n' "$SECONDS" "$reset" > "$YAFP_CODEX_DIR/sample"
        out="$(yafp-codex)"
        yafp_strip_terminal_styles "$out"
        expected='0d0h'; [ "$reset" != - ] || expected=''
        contains "$yafp_plain_text" "        Reset: $expected" 'Missing/expired report reset'
    done
    printf 'invalid\n' > "$YAFP_CODEX_DIR/sample"
    out="$(yafp-codex)"
    yafp_strip_terminal_styles "$out"
    contains "$yafp_plain_text" 'State:  unavailable' 'Invalid cache must not reuse an old state'
    contains "$yafp_plain_text" 'Remaining: ' 'Invalid cache must not reuse an old percentage'
    printf '%s\n' "$original_sample" > "$YAFP_CODEX_DIR/sample"
}
check_codex_report
saved_path=$PATH
# shellcheck disable=SC2123
PATH=/nonexistent
yafp_codex_context
PATH=$saved_path
[ "$yafp_ctx_codex" = '֍60%5d9h' ] || fail 'Warm context needed an external process'
printf 'ok - Codex quota is opt-in, asynchronous, cached, and preserved on reload\n'

while IFS='|' read -r value color cell; do
    case "$color" in Green) code=92 ;; Yellow) code=93 ;; Red) code=91 ;; DarkGray) code=90 ;; esac
    for style in percent symbols; do
        YAFP_CODEX_VALUE_STYLE=$style
        yafp_codex_segment "$value"
        expected="֍$cell"
        if [ "$style" = percent ] && [ "$value" != - ]; then expected="֍$value%"; fi
        [ "$yafp_ctx_codex_token" = "$expected" ] || fail "Wrong token: $value/$style"
        [ "$yafp_ctx_codex_color" = "$code" ] || fail "Wrong color: $value/$style"
    done
done < "$ROOT_DIR/tests/codex_display_cases.txt"

while IFS='|' read -r seconds expected; do
    yafp_codex_format_reset "$seconds"
    [ "$yafp_ctx_codex_reset_text" = "$expected" ] || fail "Wrong reset countdown: $seconds"
done < "$ROOT_DIR/tests/codex_reset_cases.txt"

YAFP_CODEX_VALUE_STYLE=bad
yafp_codex_segment 74
[ "$yafp_ctx_codex_token" = '֍74%' ] || fail 'Invalid style must fall back to percent'
git init --quiet "$TEST_ROOT/repo"
printf 'staged\n' > "$TEST_ROOT/repo/file.txt"
git -C "$TEST_ROOT/repo" add file.txt
original_pwd=$PWD
for theme in default minimal light; do
    YAFP_THEME=$theme
    yafp-reload
    YAFP_CODEX_CHECK_INTERVAL=300
    YAFP_REPOS=0 YAFP_TITLE=0 YAFP_CLOCK=1 YAFP_OSC133=0 YAFP_ERROR=0 YAFP_DEVEL=1
    yaft_general_context 7
    yafp_ctx_git_has_repo=0 yafp_venv_segment='' yafp_ctx_show_status=0
    for style in percent symbols; do
        YAFP_CODEX_VALUE_STYLE=$style
        yafp_codex_context
        expected='֍60%5d9h'
        [ "$style" != symbols ] || expected='֍⣦5d9h'
        out="$(theme_render_main_block)"
        plain_prompt
        user_marker='\u'
        if [ -n "${ZSH_VERSION:-}" ]; then user_marker="$(print -P -- '%n')"; fi
        contains "$out" "$user_marker↤[$expected]" "User adjacency in $theme/$style"
        rest=${out#*"↤[$expected]"}
        case "$rest" in *"↤[$expected]"*) fail 'Quota rendered twice' ;; esac
        out="$(theme_render_codex)"
        frame=$cSeparator
        [ "$theme" != default ] || frame=$cGit
        contains "$out" "$(ps1_wrap "$frame")↤[" 'Git opening frame style'
        contains "$out" "$(ps1_wrap "$frame")]" 'Git closing frame style'
        contains "$out" $'\033[0;92m' 'Transparent green token'
        plain_prompt
        [ "$out" = "↤[$expected]" ] || fail 'Unexpected age or padding in prompt'
    done
    # User quota contributes to banner width only when Git follows the user.
    YAFP_REPOS=1 YAFP_REMOTE_CHECK_INTERVAL=0 COLUMNS=1000
    cd "$TEST_ROOT/repo"
    yaft_general_context 0
    yafp_git_context 0
    saved_codex=$yafp_ctx_codex
    yafp_ctx_codex=''
    theme_prepare_expansion_columns
    before_column=$yafp_ctx_git_staged_indicator_column
    yafp_ctx_codex=$saved_codex
    theme_prepare_expansion_columns
    delta=$((yafp_ctx_git_staged_indicator_column - before_column))
    out="$(theme_render_codex)"
    plain_prompt
    yafp_text_display_width "$out"
    expected_delta=$yafp_display_width
    [ "$theme" != default ] || expected_delta=0
    [ "$delta" -eq "$expected_delta" ] || fail "Quota banner column: $theme/$delta/$expected_delta"
    cd "$original_pwd"
    YAFP_REPOS=0
    yafp_ctx_git_has_repo=0 yafp_ctx_git_staged=0
    YAFP_CODEX_CHECK_INTERVAL=0
    yafp_codex_context
    [ -z "$(theme_render_codex)" ] || fail 'Disabled quota rendered a frame'
done

# Older workers can still publish the five-field sample after a reload.
YAFP_CODEX_CHECK_INTERVAL=300 YAFP_CODEX_VALUE_STYLE=percent
printf '0 ok 60 75 60\n' > "$YAFP_CODEX_DIR/sample"
yafp_codex_context
[ "$yafp_ctx_codex" = '֍60%' ] || fail 'Legacy samples must omit an unknown reset'
printf '0 ok 60 75 60 0\n' > "$YAFP_CODEX_DIR/sample"
yafp_codex_context
[ "$yafp_ctx_codex" = '֍60%0s' ] || fail 'Expired reset must stop at zero'

# Reject corrupted cache rows without evaluation, and never retain old green quota after an error.
YAFP_CODEX_CHECK_INTERVAL=300
# shellcheck disable=SC2016
for row in '0 ok $(touch bad) 75 60' '0 ok 101 75 60' '0 ok 75 75' '0 ok 075 75 60' '0 ok 75 75 60 extra' '0 ok 75 75 60 01' '0 ok 75 75 60 -1' '0 ok 75 75 60 99999999999'; do
    printf '%s\n' "$row" > "$YAFP_CODEX_DIR/sample"
    yafp_codex_context
    [ "$yafp_ctx_codex" = '֍dh' ] || fail 'Invalid quota accepted'
done
for state in missing-cli missing-python logged-out unsupported-auth timeout unavailable; do
    printf '0 %s - - -\n' "$state" > "$YAFP_CODEX_DIR/sample"
    yafp_codex_context
    [ "$yafp_ctx_codex" = '֍dh' ] || fail 'Unavailable quota invented a percentage'
    [ "$yafp_ctx_codex_color" = 91 ] || fail 'Unavailable quota needs red'
done
[ ! -f bad ] || fail 'Cache executed as code'
for theme in default minimal light; do
    YAFP_THEME=$theme
    load_theme
    theme_build
    for style in percent symbols; do
        YAFP_CODEX_VALUE_STYLE=$style
        yafp_codex_context
        out="$(theme_render_codex)"
        contains "$out" $'\033[0;91m' 'Unavailable quota is red'
        plain_prompt
        [ "$out" = '↤[֍dh]' ] || fail "Unavailable quota frame: $theme/$style/$out"
    done
done
YAFP_CODEX_VALUE_STYLE=percent
yafp_err_context 7
[ "$yafp_ctx_exit" = 7 ] || fail 'Previous command status changed'
printf 'ok - Codex percent/Braille, inclusive color boundaries, user placement, and silent errors\n'

# The quota cache has the same per-session temporary-directory lifecycle.
old_dir=$YAFP_CODEX_DIR
rm -f -- "$old_dir/sample" "$old_dir/sample.debug"
rmdir -- "$old_dir"
YAFP_CODEX_ATTEMPT=$((SECONDS - 301))
yafp_codex_context
[ "$YAFP_CODEX_DIR" != "$old_dir" ] || fail 'Missing quota directory was reused'
[ -d "$YAFP_CODEX_DIR" ] || fail 'Quota cache directory was not recreated'
pid=$YAFP_CODEX_PID
yafp_codex_context
[ "$YAFP_CODEX_PID" = "$pid" ] || fail 'Cache recovery duplicated the quota worker'
for iteration in {1..60}; do
    [ ! -f "$YAFP_CODEX_DIR/sample" ] || break
    sleep 0.05
done
yafp_codex_context
[ "$yafp_ctx_codex" = '֍60%5d9h' ] || fail 'Quota sample did not recover after cache removal'
printf 'ok - Codex quota recovers after its temporary directory disappears\n'
