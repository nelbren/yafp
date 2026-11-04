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
mkdir -p "$TEST_ROOT/scripts/unix/preview"
cp -R "$ROOT_DIR/scripts/unix/preview/lib" "$TEST_ROOT/scripts/unix/preview/lib"
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
# OS glyphs preserve Debian/Kali identities and use Tux for other Linux IDs.
# Called indirectly by set_SERVER_OS_EMOJI in the sourced Bash/zsh engine.
# shellcheck disable=SC2317,SC2329
uname() { printf '%s\n' "$test_platform"; }
for test_platform in Darwin Linux MINGW64_NT MSYS_NT CYGWIN_NT; do
    case "$test_platform" in Darwin) expected_os='' ;; Linux) expected_os='' ;; *) expected_os='' ;; esac
    set_SERVER_OS_EMOJI "$TEST_ROOT/missing-os-release"
    [ "$SERVER_OS_EMOJI" = "$expected_os" ] || fail "Server OS glyph: $test_platform"
done
test_platform=Linux
for distro in debian kali ubuntu arch fedora unknown; do
    case "$distro" in debian) expected_os='' ;; kali) expected_os='㉿' ;; *) expected_os='' ;; esac
    for quoting in bare double single; do
        case "$quoting" in
            bare) printf 'ID_LIKE=debian\nID=%s\n' "$distro" > "$TEST_ROOT/os-release" ;;
            double) printf 'ID="%s"\n' "$distro" > "$TEST_ROOT/os-release" ;;
            single) printf "ID='%s'\n" "$distro" > "$TEST_ROOT/os-release" ;;
        esac
        set_SERVER_OS_EMOJI "$TEST_ROOT/os-release"
        [ "$SERVER_OS_EMOJI" = "$expected_os" ] || fail "Linux distro glyph: $distro/$quoting"
    done
done
printf 'NAME=Linux\nID_LIKE=debian\n' > "$TEST_ROOT/os-release"
set_SERVER_OS_EMOJI "$TEST_ROOT/os-release"
[ "$SERVER_OS_EMOJI" = '' ] || fail 'Missing ID must use generic Linux glyph'
unset -f uname
set_SERVER_OS_EMOJI
saved_client_os=${CLIENT_OS:-}
for CLIENT_OS in WINDOWS MACOS LINUX WSL2 CYGWIN GITBASH; do
    case "$CLIENT_OS" in
        WINDOWS) expected_os='' ;; MACOS) expected_os='' ;; LINUX) expected_os='' ;;
        WSL2) expected_os='▶' ;; CYGWIN) expected_os='⬘▶' ;; GITBASH) expected_os='⬙▶' ;;
    esac
    set_CLIENT_OS_EMOJI
    [ "$CLIENT_OS_EMOJI" = "$expected_os" ] || fail "Client OS glyph: $CLIENT_OS"
done
CLIENT_OS=$saved_client_os
set_CLIENT_OS_EMOJI
[ "$YAFP_SYMBOL_GIT_EMOJI/$YAFP_SYMBOL_GIT_REPO" = '/' ] || fail 'Git logo glyphs'

yafp_ctx_git_has_repo=1 yafp_ctx_git_remote=remote yafp_ctx_git_branch=main
yafp_ctx_git_repo=fixture yafp_ctx_git_last_ts='2026-10-29 12:00:00'
yafp_ctx_git_ahead=2 yafp_ctx_git_behind=3 yafp_ctx_git_upstream=origin/main
yafp_ctx_git_remote_refreshing=0 yafp_ctx_git_remote_connection_announcement=0
YAFP_REMOTE_CHECK_INTERVAL=300 YAFP_REMOTE_OFFLINE_ACKNOWLEDGED=0
for dark in 0 1; do
    YAFP_DARKC=$dark
    for theme in default minimal light; do (
        YAFP_THEME=$theme
        load_theme
        theme_build
        yafp_ctx_timestamp='2026-11-02 01:24:59'
        out="$(theme_render_timestamp)"
        contains "$out" '' "Clock glyph in $theme"
        yafp_venv_segment=venv
        out="$(theme_render_venv_block)"
        if [ "$theme" != default ]; then
            contains "$out" '' "Python glyph in $theme"
        else
            contains "$out" '[venv]' 'Default keeps its existing environment label'
        fi
        yafp_ctx_previous_command='echo ⚠️'
        yafp_ctx_previous_timestamp='' yafp_ctx_exit=0
        out="$(theme_render_status_ok_block)"
        contains "$out" '' "Success glyph in $theme"
        if [ "$theme" = default ]; then
            contains "$out" 'echo ⚠️' 'Command marker must not alter command text'
        fi
        yafp_ctx_exit=7
        out="$(theme_render_status_error_block)"
        case "$theme" in default) error_text='7' ;; minimal) error_text=' 7' ;; light) error_text=' 7' ;; esac
        contains "$out" "$(ps1_wrap "$cCmdError")${error_text}" 'Error symbol and status keep their color'
        if [ "$theme" = minimal ]; then
            case "$YAFP_USER_TYPE" in root) user_icon='' ;; *) user_icon='' ;; esac
            out="$(SSH_CLIENT='' OMP_GEOIP_COUNTRY='' theme_render_general_block)"
            contains "$out" "$user_icon" 'User privilege glyph'
            contains "$out" '' 'Local desktop glyph'
            contains "$out" '' 'Local country fallback glyph'
            out="$(SSH_CLIENT=fixture theme_render_general_block)"
            contains "$out" '' 'SSH laptop glyph'
        fi
        t_all_begin=0 t_general_begin=0 t_general_end=2 t_git_begin=0 t_git_end=3
        t_venv_begin=0 t_venv_end=4 t_err_begin=0 t_err_end=5
        for t_all_end in 49 50 199 200; do
            case "$t_all_end" in
                49) speed_icon=''; speed_color=$cStatusOk ;;
                50|199) speed_icon=''; speed_color=$cStatusWarning ;;
                200) speed_icon=''; speed_color=$cStatusError ;;
            esac
            out="$(yafp_dev_segment)"
            contains "$out" "$(ps1_wrap "$speed_color")${speed_icon}${t_all_end}ms" 'Performance thresholds keep their colors'
            contains "$out" '2 3 4 5 ' 'Development context glyphs'
        done
        frame=$cSeparator
        [ "$theme" != default ] || frame=$cGit
        for style in numeric symbols; do
            YAFP_REMOTE_COUNTDOWN_STYLE=$style
            yafp_ctx_git_remote_state=current yafp_ctx_git_remote_refresh_in=175
            out="$(theme_render_git_remote_status)"
            contains "$out" "$(ps1_wrap "$frame")[" 'Git frame opening style'
            contains "$out" "$(ps1_wrap "$frame")]" 'Git frame closing style'
            contains "$out" "$(ps1_wrap "$cRemoteOk")" 'Existing success color'
            plain
            expected='[⣦]↤'
            [ "$style" != numeric ] || expected='[(175)]↤'
            [ "$out" = "$expected" ] || fail "Compact remote block: $theme/$style/$out"
        done
        # Narrow terminals suppress banners while retaining every compact state.
        COLUMNS=1
        yafp_ctx_git_remote_refresh_in=''
        yafp_ctx_git_remote_state=current yafp_ctx_git_remote_refreshing=1
        out="$(theme_render_git_remote_status)"
        contains "$out" "$(ps1_wrap "$cRemotePending")" 'Existing refresh color'
        plain
        [ "$out" = '[]↤' ] || fail "Refresh icon must touch the cached state: $theme/$out"
        yafp_ctx_git_remote_refreshing=0
        for state in no-commits no-upstream checking ahead behind diverged error; do
            yafp_ctx_git_remote_state=$state
            case "$state" in
                no-commits) indicator='○0' ;; no-upstream) indicator='⇡?' ;;
                checking) indicator='⟳' ;; ahead) indicator='⇡2' ;;
                behind) indicator='⇣3' ;; diverged) indicator='⇡2⇣3' ;; error) indicator='' ;;
            esac
            out="$(theme_render_git_remote_status)"
            if [ "$state" = checking ]; then
                contains "$out" "$(ps1_wrap $'\033[0;90m')⟳" 'Pending remote color'
            fi
            plain
            [ "$out" = "[$indicator]↤" ] || fail "Remote state framing: $theme/$state/$out"
        done
        # The failure highlight is independent of theme darkness; acknowledgement clears it.
        yafp_ctx_git_remote_state=error
        for acknowledged in 0 1; do
            YAFP_REMOTE_OFFLINE_ACKNOWLEDGED=$acknowledged
            out="$(theme_render_git_remote_status)"
            expected_color=$cRemoteProblem
            [ "$acknowledged" -eq 0 ] || expected_color=$cRemoteAcknowledged
            contains "$out" "$(ps1_wrap "$expected_color")" "Offline highlight: $theme/$dark/$acknowledged"
        done
        YAFP_REMOTE_OFFLINE_ACKNOWLEDGED=0
        yafp_ctx_git_remote_state=''
        [ -z "$(theme_render_git_remote_status)" ] || fail 'Empty remote frame'
        yafp_ctx_git_delete=0 yafp_ctx_git_change=0 yafp_ctx_git_new=0 yafp_ctx_git_staged=0
        [ -z "$(theme_render_git_counts)" ] || fail 'Empty counter frame'
        yafp_ctx_git_delete=1 yafp_ctx_git_change=2 yafp_ctx_git_new=3 yafp_ctx_git_staged=4
        COLUMNS=1000
        out="$(YAFP_MEASURE_EXPANSIONS=1 theme_render_git_counts)"
        contains "$out" "$(ps1_wrap "$frame")↦[" 'Counter frame opening style'
        contains "$out" "$(ps1_wrap "$frame")]" 'Counter frame closing style'
        contains "$out" "$(ps1_wrap "$(theme_color transparent RED)")1" 'Deleted counter color'
        contains "$out" "$(ps1_wrap "$(theme_color transparent YELLOW)")2" 'Modified counter color'
        contains "$out" "$(ps1_wrap "$(theme_color transparent CYAN)")3" 'New counter color'
        plain
        prefix='↦[123'
        expected="${prefix}${YAFP_STAGED_EXPANSION_MARKER}${YAFP_SYMBOL_GIT_STAGED_EMOJI}4]"
        [ "$out" = "$expected" ] || fail "Staged anchor must follow preceding counters: $theme/$out"
        yafp_ctx_git_remote_state=behind yafp_ctx_git_remote_refresh_in=175
        YAFP_REMOTE_COUNTDOWN_STYLE=symbols
        out="$(YAFP_MEASURE_EXPANSIONS=1 theme_render_git_remote_status)"
        plain
        [ "$out" = "[⣦${YAFP_REMOTE_EXPANSION_MARKER}⇣3]↤" ] || fail 'Remote anchor must include the new frame'
        out="$(YAFP_MEASURE_EXPANSIONS=1 theme_render_git_block)"
        contains "$out" '' "Git logo in $theme"
        plain
        contains "$out" ']↤main↦[' "Remote, branch, and counters touch: $theme"
        yafp_ctx_git_remote=local yafp_ctx_git_remote_state='' yafp_ctx_git_remote_refresh_in=''
        out="$(theme_render_git_block)"
        plain
        contains "$out" 'main↦[' "Local branch and counters touch: $theme"
        case "$out" in *']↤'*|*↯*) fail "Unexpected remote marker: $out" ;; esac
        for state in current checking error local; do
            yafp_ctx_git_remote=remote yafp_ctx_git_remote_state=$state
            case "$state" in
                current) color=92; icon='' ;;
                checking) color=93; icon='' ;;
                error) color=91; icon='' ;;
                local) color=93; icon=''; yafp_ctx_git_remote=local ;;
            esac
            out="$(theme_render_git_branch_icon)"
            contains "$out" "$(ps1_wrap "$(printf '\033[0;%sm' "$color")")$icon" "Branch icon color: $state"
        done
        COLUMNS=80 yafp_ctx_git_remote_indicator_column=78 yafp_ctx_git_remote_indicator_rows=1
        yafp_ctx_git_remote_state=error
        out="$(theme_render_remote_expansion)"
        contains "$out" $'\033[2A' 'Offline banner returns to the reserved row'
        contains "$out" '(  REMOTE CHECK FAILED )' 'Offline banner fits at the right edge'
        yafp_ctx_git_remote_state=current yafp_ctx_git_remote_connection_announcement=1
        out="$(theme_render_remote_expansion)"
        contains "$out" $'\033[2A' 'Recovery banner returns to the reserved row'
        contains "$out" '(  INTERNET CONNECTION )' 'Recovery banner fits at the right edge'
        out="$(theme_render_git_remote_status)"
        contains "$out" "$(ps1_wrap "$cRemoteConnection")" 'Recovery icon shares the banner style'
        COLUMNS=12
        out="$(theme_render_git_remote_status)"
        contains "$out" "$(ps1_wrap "$cRemoteOk")" 'Suppressed banner keeps the steady icon color'

    ) done
done
out="$(yafp_remote_status_report current 0 0 1 0 300 0)"
contains "$out" ' Refreshing · last:  Up to date' 'Detailed refresh icon'
for remaining in 175 ''; do
    out="$(yafp_remote_status_report current 0 0 0 "$remaining" 300 0)"
    contains "$out" '       Remote:  Up to date' 'Remote report glyphs'
    contains "$out" ' Current time: ' 'Current-time glyph'
    contains "$out" '   Next check: ' 'Scheduled-check glyph'
    while IFS= read -r line; do
        yafp_text_display_width "${line%%:*}"
        [ "$yafp_display_width" -eq 14 ] || fail "Report label alignment: $line"
    done <<< "$out"
done
. "$ROOT_DIR/scripts/unix/preview/lib/frame.bash"
out="$(yafp_remote_status_report current 0 0 0 175 300 0 frame)"
contains "$out" '┌' 'Status opening frame'
contains "$out" '┘' 'Status closing frame'
plain
contains "$out" '       Remote:  Up to date' 'Framed status fields'
contains "$out" '   Next check:' 'Framed next-check field'
YAFP_COMMANDS_TOTAL=13 YAFP_COMMANDS_SUCCEEDED=11 YAFP_COMMANDS_FAILED=2
out="$(NO_COLOR='' yafp-stats)"
contains "$out" $'\033[92m Succeeded:' 'Framed succeeded color'
contains "$out" $'\033[91m Failed:' 'Framed failed color'
contains "$out" $'\033[97m∑ Total:' 'Framed total color'
plain
contains "$out" ' Succeeded: 11 (085%)' 'Framed succeeded precision'
contains "$out" ' Failed:     2 (015%)' 'Framed failed alignment'
contains "$out" '∑ Total:     13 (100%)' 'Framed total'
out="$(NO_COLOR='' yafp-help)"
contains "$out" '┌' 'Help opening frame'
contains "$out" '┘' 'Help closing frame'
contains "$out" $'\033[93myafp-status' 'Help command color'
plain
contains "$out" 'yafp-resources • Show the latest RAM, swap, CPU, and disk sample.' 'Help entries retained'
out="$(yafp-msgs)"
contains "$out" '┌' 'Message catalog opening frame'
contains "$out" '┘' 'Message catalog closing frame'
contains "$out" "${cRemotePending}(  PUSH PENDING: 1 )" 'Message catalog warning colors'
plain
contains "$out" '(  INTERNET CONNECTION )' 'Success catalog entry'
contains "$out" '(  REMOTE CHECK FAILED )' 'Error catalog entry'
for fixture in $'\033[31m12345678901234567890\033[0m\n$ ' \
    $'\nabcdef\033[s\033[1A\033[3D\033[33mWARN\033[0m\033[uXYZ\n$ ' \
    $'abc\033[K\nA界é\n$ '; do
    out="$(yafp_preview_frame "$fixture" 20)"
    contains "$out" '┌' 'Preview top border'
    contains "$out" '┘' 'Preview bottom border'
    case "$out" in *$'\033[s'*|*$'\033[u'*|*$'\033[1A'*|*$'\033[K'*) fail 'Preview cursor controls escaped the canvas' ;; esac
    plain
    while IFS= read -r line; do
        case "$line" in *界*)
            [ "$line" = '│ A界é           │' ] || fail "Unicode padding: $line"
            continue ;;
        esac
        yafp_text_display_width "$line"
        [ "$yafp_display_width" -eq 19 ] || fail "Preview frame width: $line"
    done <<< "$out"
    case "$fixture" in
        *WARN*) contains "$out" '   WARN' 'Banner placement'; contains "$out" 'abcdefXYZ' 'Cursor restore' ;;
        *123*) contains "$out" '123456789012345' 'Wrapped first row'; contains "$out" '67890' 'Wrapped continuation' ;;
        *) contains "$out" 'abc' 'Erase-to-end preserves preceding text'; contains "$out" 'A界e' 'Unicode content' ;;
    esac
done
out="$(yafp_preview_frame $'\033[31mred\033[0m\n$ ' 20)"
contains "$out" $'\033[31m' 'Preview foreground color'
out="$(yafp_preview_frame 'tiny' 6)"
[ "$out" = tiny ] || fail 'Very narrow preview falls back to plain rendering'
printf 'ok - uniform Git frames, compact countdowns, severity colors, and banner anchors in all themes\n'
