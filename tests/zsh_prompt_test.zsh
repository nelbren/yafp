#!/usr/bin/env zsh
emulate -LR zsh
setopt KSH_ARRAYS

ROOT_DIR="${0:A:h:h}"
export YAFP_NO_INSTALL_HOOKS=1
TEST_RUNTIME="$(mktemp -d)"
trap 'rm -rf -- "$TEST_RUNTIME"' EXIT
sed '/^YAFP_THEME=/d' "$ROOT_DIR/yafp-cfg.zsh.example" > "$TEST_RUNTIME/config.zsh"
export YAFP_CONFIG_FILE="$TEST_RUNTIME/config.zsh"
export TERM=xterm-256color
. "$ROOT_DIR/yafp-ps1.zsh" || exit 1
cd "$TEST_RUNTIME" || exit 1

fail() { print -u2 -r -- "not ok - $1"; exit 1; }
assert_eq() { [[ "$1" == "$2" ]] || fail "$3: expected [$1], got [$2]"; }
assert_contains() { [[ "$1" == *"$2"* ]] || fail "$3"; }

assert_eq "$ROOT_DIR" "$YAFP_ROOT" 'root resolved from source'
assert_eq "$ROOT_DIR/yafp-ps1.zsh" "$YAFP_SCRIPT_PATH" 'native reload path'
assert_eq push "$(yafp_git_command_action "git -C 'path with spaces' push")" 'quoted Git arguments'
assert_eq fetch "$(yafp_git_command_action 'command git -c color.ui=false fetch')" 'command prefix'
if yafp_is_git_sync_command 'echo "git push"'; then fail 'incidental Git text'; fi
if yafp_should_force_remote_refresh 'git pull' 1; then fail 'failed pull refresh'; fi

YAFP_REPOS=0
YAFP_TITLE=0
YAFP_CLOCK=0
YAFP_OSC133=0
YAFP_ERROR=1
YAFP_PVENV=1
VIRTUAL_ENV='/tmp/env%F{red}$(touch forbidden)'
for theme in default minimal light; do
    YAFP_THEME="$theme"
    # Reload to restore the base renderers and theme palette.
    yafp-reload || fail 'reload'
    YAFP_REPOS=0 YAFP_CLOCK=0 YAFP_OSC133=0 YAFP_TITLE=0 YAFP_DEVEL=1
    yafp_ctx_timestamp='YAFP_CLOCK_DISABLED_SENTINEL'
    yafp_prompt_command
    assert_eq "$theme" "$YAFP_THEME_NAME" 'native theme loading'
    assert_contains "$YAFP_ZSH_PROMPT" 'env%%F{red}' 'venv percent escaped'
    assert_contains "$YAFP_ZSH_PROMPT" 'ms' 'development metrics'
    [[ "$YAFP_ZSH_PROMPT" != *"$yafp_ctx_timestamp"* ]] || fail 'clock disabled in every theme'
    assert_contains "$YAFP_ZSH_PROMPT" '%{' 'native zero-width spans'
    assert_contains "$YAFP_ZSH_PROMPT" "$YAFP_USER_PROMPT_SYMBOL" 'prompt mark'
    [[ "$YAFP_ZSH_PROMPT" != *'\u'* && "$YAFP_ZSH_PROMPT" != *'\w'* ]] || fail 'Bash prompt escapes'
    [[ "$YAFP_ZSH_PROMPT" != *'\033'* ]] || fail 'literal terminal escapes'
    yafp_err_context 7
    out="$(theme_render_status_error_block)"
    assert_contains "$out" '7' 'exit status in every theme'
    assert_contains "$cCmdError" $'\033[91m' 'intense red error'
    [[ "$cCmdError" != *$'\033[4'* ]] || fail 'error background must be transparent'
    YAFP_DEVEL=0
    yafp_prompt_command
    [[ "$YAFP_ZSH_PROMPT" != *'⚙️'* ]] || fail 'metrics disabled'
done
YAFP_THEME='does-not-exist'
load_theme || fail 'fallback loading'
assert_eq default "$YAFP_THEME_NAME" 'unknown theme fallback'

YAFP_THEME=light
load_theme; theme_build
assert_eq $'\033[0;48;2;255;255;0;38;2;0;0;0m' "$cRemotePending" 'exact warning colors'
assert_eq $'\033[0;48;2;0;128;0;38;2;255;255;255m' "$cRemoteConnection" 'exact recovery colors'
yafp_strip_terminal_styles $'\033[31mred\033[0m'
assert_eq red "$yafp_plain_text" 'ANSI stripping uses native match'
available_locales="$(locale -a)"
original_lc_all="${LC_ALL-}"
original_lc_all_set=${+LC_ALL}
for test_locale in en_US.UTF-8 es_ES.UTF-8; do
    case "$available_locales" in
        *"$test_locale"*) ;;
        *) continue ;;
    esac
    LC_ALL="$test_locale"
    yafp_zsh_wrap_styles $'\033[31mred\033[0m' \
        > "$TEST_RUNTIME/wrapped-styles" 2> "$TEST_RUNTIME/wrapped-styles.err"
    out="$(<"$TEST_RUNTIME/wrapped-styles")"
    err="$(<"$TEST_RUNTIME/wrapped-styles.err")"
    assert_eq $'%{\033[31m%}red%{\033[0m%}' "$out" \
        "ANSI wrapping under $test_locale"
    assert_eq '' "$err" "ANSI wrapping diagnostics under $test_locale"
    assert_eq "$test_locale" "$LC_ALL" \
        "ANSI wrapping preserves caller locale under $test_locale"
done
if (( original_lc_all_set )); then
    LC_ALL="$original_lc_all"
else
    unset LC_ALL
fi
yafp_text_display_width 'abc🌐'
assert_eq 5 "$yafp_display_width" 'Unicode width'

YAFP_REMOTE_COUNTDOWN_STYLE=symbols
YAFP_REMOTE_CHECK_INTERVAL=300
yafp_remote_countdown_indicator 200
assert_eq '⣶' "$yafp_remote_countdown_text" 'symbolic countdown'
yafp_remote_countdown_indicator 0
assert_eq '' "$yafp_remote_countdown_text" 'zero countdown hidden'
YAFP_REMOTE_COUNTDOWN_STYLE=numeric

YAFP_CLOCK=0 YAFP_DEVEL=0 YAFP_REPOS=0 YAFP_OSC133=0
yaft_general_context 0
yafp_venv_context
YAFP_REMOTE_CONNECTIVITY_STATE=online
YAFP_REMOTE_OFFLINE_ACKNOWLEDGED=0
yafp_ctx_git_has_repo=1
yafp_ctx_git_remote=remote
yafp_ctx_git_branch='branch%F{red}'
yafp_ctx_git_repo='repo%F{red}'
yafp_ctx_git_last_ts=''
yafp_ctx_git_new=1 yafp_ctx_git_change=2 yafp_ctx_git_delete=3 yafp_ctx_git_staged=4
yafp_ctx_git_remote_state=ahead yafp_ctx_git_ahead=2 yafp_ctx_git_behind=0
yafp_ctx_git_upstream=origin/main yafp_ctx_git_remote_refresh_in=200
yafp_ctx_git_remote_refreshing=0 yafp_ctx_git_remote_connection_announcement=0
COLUMNS=200
out="$(theme_render_ps1)"
assert_contains "$out" '📦4' 'staged indicator'
assert_contains "$out" '( ⚠ COMMIT PENDING:' 'staged banner'
assert_contains "$out" '⇡2' 'ahead indicator'
assert_contains "$out" '( ⚠ REMOTE NOT UPDATED:' 'remote banner'
assert_contains "$out" 'branch%%F{red}' 'branch percent escaped'
COLUMNS=12
out="$(theme_render_ps1)"
[[ "$out" != *'( ⚠'* ]] || fail 'banner must fit narrow terminal'
assert_contains "$out" '📦4' 'narrow compact indicator retained'
yafp_ctx_git_remote_state=error
YAFP_REMOTE_OFFLINE_ACKNOWLEDGED=1
out="$(theme_render_git_remote_status)"
assert_contains "$out" '☒🌐︎' 'acknowledged compact error'
[[ "$out" != *'REMOTE CHECK FAILED'* ]] || fail 'acknowledged banner hidden'

YAFP_COMMANDS_TOTAL=0 YAFP_COMMANDS_SUCCEEDED=0 YAFP_COMMANDS_FAILED=0
YAFP_COMMAND_SERIAL=1
yafp_record_command_stats true 0 || fail 'record success'
YAFP_COMMAND_SERIAL=2
yafp_record_command_stats false 1 || fail 'record failure'
yafp-reload || fail 'reload after counters'
assert_eq 2 "$YAFP_COMMANDS_TOTAL" 'reload preserves total'
assert_eq 1 "$YAFP_COMMANDS_FAILED" 'reload preserves failure'

# Loading from elsewhere must preserve unrelated caller options.
setopt NO_UNSET SH_WORD_SPLIT
. "$YAFP_SCRIPT_PATH" || fail 'load with caller options'
[[ -o nounset && -o shwordsplit ]] || fail 'caller options changed'
unsetopt NO_UNSET SH_WORD_SPLIT
yafp_osc133_parse $'\033]133;D;7\007'
assert_eq 7 "$YAFP_OSC133_EXIT_CODE" 'OSC parser'
print -r -- 'ok - zsh themes, context, banners, helpers, and reload'
