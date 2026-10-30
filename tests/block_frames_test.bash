#!/usr/bin/env bash
# Shared Bash/zsh presentation contract, without Git or network probes.
if [ -n "${ZSH_VERSION:-}" ]; then emulate -LR zsh -o KSH_ARRAYS; fi
set -eo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
export TERM=xterm-256color YAFP_NO_INSTALL_HOOKS=1 YAFP_METRICS_DISABLED=1
cp "$ROOT_DIR/yafp-ps1.bash" "$ROOT_DIR/yafp-ps1.zsh" "$TEST_ROOT/"
cp -R "$ROOT_DIR/themes" "$TEST_ROOT/themes"
sed '/^YAFP_THEME=/d' "$ROOT_DIR/yafp-cfg.bash.example" > "$TEST_ROOT/yafp-cfg.bash"
sed '/^YAFP_THEME=/d' "$ROOT_DIR/yafp-cfg.zsh.example" > "$TEST_ROOT/yafp-cfg.zsh"
YAFP_CONFIG_FILE="$TEST_ROOT/yafp-cfg.zsh"
if [ -n "${ZSH_VERSION:-}" ]; then . "$TEST_ROOT/yafp-ps1.zsh"
else . "$TEST_ROOT/yafp-ps1.bash"
fi
fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }
contains() { case "$1" in *"$2"*) ;; *) fail "$3: $1" ;; esac; }
plain() {
    if [ -n "${ZSH_VERSION:-}" ]; then
        out=${out//'%{'/}; out=${out//'%}'/}
    else
        out=${out//\\[/}; out=${out//\\]/}
    fi
    yafp_strip_terminal_styles "$out"
    out=$yafp_plain_text
}
yafp_ctx_git_has_repo=1 yafp_ctx_git_remote=remote yafp_ctx_git_branch=main
yafp_ctx_git_repo=fixture yafp_ctx_git_last_ts='2026-10-29 12:00:00'
yafp_ctx_git_ahead=2 yafp_ctx_git_behind=3 yafp_ctx_git_upstream=origin/main
yafp_ctx_git_remote_refreshing=0 yafp_ctx_git_remote_connection_announcement=0
YAFP_REMOTE_CHECK_INTERVAL=300 YAFP_REMOTE_OFFLINE_ACKNOWLEDGED=0
for dark in 0 1; do
    YAFP_DARKC=$dark
    for theme in default minimal light; do
        YAFP_THEME=$theme
        load_theme
        theme_build
        frame=$cSeparator
        [ "$theme" != default ] || frame=$cGit
        for style in numeric symbols; do
            YAFP_REMOTE_COUNTDOWN_STYLE=$style
            yafp_ctx_git_remote_state=current yafp_ctx_git_remote_refresh_in=175
            out="$(theme_render_git_remote_status)"
            contains "$out" "$(ps1_wrap "$frame")↦[" 'Git frame opening style'
            contains "$out" "$(ps1_wrap "$frame")]" 'Git frame closing style'
            contains "$out" "$(ps1_wrap "$cRemoteOk")✓🌐︎" 'Existing success color'
            plain
            expected='↦[⣦✓🌐︎]'
            [ "$style" != numeric ] || expected='↦[(175)✓🌐︎]'
            [ "$out" = "$expected" ] || fail "Compact remote block: $theme/$style/$out"
        done
        # Narrow terminals suppress banners while retaining every compact state.
        COLUMNS=1
        yafp_ctx_git_remote_refresh_in=''
        for state in no-commits no-upstream checking ahead behind diverged error; do
            yafp_ctx_git_remote_state=$state
            case "$state" in
                no-commits) indicator='○0' ;; no-upstream) indicator='⇡?' ;;
                checking) indicator='…' ;; ahead) indicator='⇡2' ;;
                behind) indicator='⇣3' ;; diverged) indicator='⇡2⇣3' ;; error) indicator='☒🌐︎' ;;
            esac
            out="$(theme_render_git_remote_status)"
            plain
            [ "$out" = "↦[$indicator]" ] || fail "Remote state framing: $theme/$state/$out"
        done
        yafp_ctx_git_remote_state=''
        [ -z "$(theme_render_git_remote_status)" ] || fail 'Empty remote frame'
        yafp_ctx_git_delete=0 yafp_ctx_git_change=0 yafp_ctx_git_new=0 yafp_ctx_git_staged=0
        [ -z "$(theme_render_git_counts)" ] || fail 'Empty counter frame'
        yafp_ctx_git_delete=1 yafp_ctx_git_change=2 yafp_ctx_git_new=3 yafp_ctx_git_staged=4
        COLUMNS=1000
        out="$(YAFP_MEASURE_EXPANSIONS=1 theme_render_git_counts)"
        contains "$out" "$(ps1_wrap "$frame")↦[" 'Counter frame opening style'
        contains "$out" "$(ps1_wrap "$frame")]" 'Counter frame closing style'
        plain
        prefix="↦[${YAFP_SYMBOL_GIT_DELETE_EMOJI}${YAFP_SYMBOL_GIT_DELETE}1"
        prefix+="${YAFP_SYMBOL_GIT_CHANGE_EMOJI}${YAFP_SYMBOL_GIT_CHANGE}2"
        prefix+="${YAFP_SYMBOL_GIT_NEW_EMOJI}${YAFP_SYMBOL_GIT_NEW}3"
        expected="${prefix}${YAFP_STAGED_EXPANSION_MARKER}${YAFP_SYMBOL_GIT_STAGED_EMOJI}4]"
        [ "$out" = "$expected" ] || fail "Staged anchor must follow preceding counters: $theme/$out"
        yafp_ctx_git_remote_state=behind yafp_ctx_git_remote_refresh_in=175
        YAFP_REMOTE_COUNTDOWN_STYLE=symbols
        out="$(YAFP_MEASURE_EXPANSIONS=1 theme_render_git_remote_status)"
        plain
        [ "$out" = "↦[⣦${YAFP_REMOTE_EXPANSION_MARKER}⇣3]" ] || fail 'Remote anchor must include the new frame'
        out="$(YAFP_MEASURE_EXPANSIONS=1 theme_render_git_block)"
        plain
        count=0 rest=$out
        while :; do
            case "$rest" in *'↦['*) rest=${rest#*'↦['}; count=$((count + 1)) ;; *) break ;; esac
        done
        [ "$count" -eq 2 ] || fail "Missing or nested Git frames: $theme/$out"
        git_indicator=$YAFP_SYMBOL_GIT_EMOJI
        [ "$theme" != default ] || git_indicator=$YAFP_SYMBOL_GIT_SEP
        contains "$out" "${git_indicator}↦[" "Git marker must touch its remote frame: $theme"
    done
done
printf 'ok - uniform Git frames, compact countdowns, severity colors, and banner anchors in all themes\n'
