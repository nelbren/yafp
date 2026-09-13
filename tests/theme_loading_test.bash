#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null && pwd)"
export TERM="${TERM:-xterm-256color}"
export YAFP_NO_INSTALL_HOOKS=1

TEST_RUNTIME="$(mktemp -d "${TMPDIR:-/tmp}/yafp-theme-test.XXXXXX")"

cleanup() {
    if [ -n "${TEST_RUNTIME:-}" ] && [ -d "$TEST_RUNTIME" ]; then
        rm -rf -- "$TEST_RUNTIME"
    fi
}

trap cleanup EXIT
cp "$ROOT_DIR/yafp-ps1.bash" "$TEST_RUNTIME/yafp-ps1.bash"
cp "$ROOT_DIR/yafp-cfg.bash.example" "$TEST_RUNTIME/yafp-cfg.bash"
cp -R "$ROOT_DIR/themes" "$TEST_RUNTIME/themes"

# shellcheck source=../yafp-ps1.bash
set +u
. "$TEST_RUNTIME/yafp-ps1.bash"
set -u
trap - DEBUG
PROMPT_COMMAND=

fail() {
    printf 'not ok - %s\n' "$1" >&2
    exit 1
}

assert_theme() {
    local requested="$1"
    local expected="$2"

    YAFP_THEME="$requested"
    set +u
    load_theme || fail "theme failed to load: $requested"
    set -u
    [ "$YAFP_THEME_NAME" = "$expected" ] ||
        fail "$requested loaded $YAFP_THEME_NAME instead of $expected"
}

assert_theme default default
assert_theme minimal minimal
assert_theme light light
assert_theme missing-theme default

YAFP_DARKC=1
[ "$(yafp_theme_background_color RED)" = 'red' ] ||
    fail 'YAFP_DARKC=1 did not select the dark Bash background'
[ "$(yafp_theme_background_color transparent)" = 'transparent' ] ||
    fail 'YAFP_DARKC=1 changed a transparent Bash background'
YAFP_DARKC=0
[ "$(yafp_theme_background_color red)" = 'RED' ] ||
    fail 'YAFP_DARKC=0 did not select the bright Bash background'
[ "$(yafp_theme_background_color transparent)" = 'transparent' ] ||
    fail 'YAFP_DARKC=0 changed a transparent Bash background'
YAFP_DARKC=1

assert_theme default default
cGit='<git>'
cRepo='<repo>'
cSeparator='<separator>'
yafp_ctx_git_has_repo=1
yafp_ctx_git_remote=remote
yafp_ctx_git_last_ts='2026-09-12 18:37:04'
yafp_ctx_git_repo='yafp'
yafp_ctx_git_branch='master'
yafp_ctx_git_remote_refresh_in=''
yafp_ctx_git_remote_refreshing=0
yafp_ctx_git_remote_state=''
yafp_ctx_git_delete=0
yafp_ctx_git_change=0
yafp_ctx_git_new=0

set +u
git_block="$(theme_render_git_block)"
set -u
expected_repo_segment="${YAFP_SYMBOL_GIT_REPO}<repo>yafp<git>${YAFP_SYMBOL_GIT_SEP}"
[[ "$git_block" == *"$expected_repo_segment"* ]] ||
    fail 'default theme does not color only the repository name'

assert_theme light light
[ "$YAFP_COLOR_NORMAL_BG" = 'transparent' ] ||
    fail 'light theme normal reset can paint separator spaces'
cGitBranch='<branch>'
cRemoteNeutral='<timer>'
yafp_ctx_git_remote_refresh_in=42
yafp_ctx_git_remote_state=current
set +u
git_block="$(theme_render_git_block)"
set -u
timer_start="${YAFP_SYMBOL_GIT_EMOJI} $(ps1_wrap "$cRemoteNeutral")(42) "
[[ "$git_block" == *"$timer_start"* ]] ||
    fail 'light theme remote timer spacing or color differs from PowerShell'
branch_start="$(ps1_wrap "$cGitBranch")$yafp_ctx_git_branch"
[[ "$git_block" == *"$branch_start"* ]] ||
    fail 'light theme did not restore the blue branch color after the timer'
remote_start="${branch_start}${cSeparator}${YAFP_SYMBOL_REMOTE}"
[[ "$git_block" == *"$remote_start"* ]] ||
    fail 'light theme applied the blue branch color to the remote symbol'

printf 'ok - Bash theme loading, Git colors, and remote timer spacing\n'
