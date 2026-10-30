#!/usr/bin/env bash
# Run with Bash and zsh to check the shared contract.
if [ -n "${ZSH_VERSION:-}" ]; then emulate -LR zsh -o KSH_ARRAYS; fi
set -eo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_ROOT=$(mktemp -d)
export TERM=xterm-256color YAFP_NO_INSTALL_HOOKS=1 YAFP_METRICS_DISABLED=1
cleanup() {
    yafp_resources_cleanup
    rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT
fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }
assert_contains() { case "$1" in *"$2"*) ;; *) fail "$3: $1" ;; esac; }
plain_prompt() {
    if [ -n "${ZSH_VERSION:-}" ]; then
        out="$(print -Pr -- "$out")"
    else
        out=${out//\\[/}
        out=${out//\\]/}
        out=${out//\\e/$'\033'}
    fi
    yafp_strip_terminal_styles "$out"
    out=$yafp_plain_text
}

cp "$ROOT_DIR/yafp-ps1.bash" "$ROOT_DIR/yafp-ps1.zsh" "$TEST_ROOT/"
cp -R "$ROOT_DIR/themes" "$ROOT_DIR/scripts" "$TEST_ROOT/"
sed '/^YAFP_THEME=/d' "$ROOT_DIR/yafp-cfg.bash.example" > "$TEST_ROOT/yafp-cfg.bash"
sed '/^YAFP_THEME=/d' "$ROOT_DIR/yafp-cfg.zsh.example" > "$TEST_ROOT/yafp-cfg.zsh"
YAFP_CONFIG_FILE="$TEST_ROOT/yafp-cfg.zsh"
if [ -n "${ZSH_VERSION:-}" ]; then
    . "$TEST_ROOT/yafp-ps1.zsh"
else
    . "$TEST_ROOT/yafp-ps1.bash"
fi

for interval in 0 -1 bad 0008 999999999999999999999; do
    YAFP_RESOURCE_CHECK_INTERVAL=$interval
    yafp_resources_context
    [ -z "$yafp_ctx_resources" ] || fail 'disabled/invalid interval produced context'
    [ -z "${YAFP_RESOURCE_DIR:-}" ] || fail 'disabled sampling created a cache'
done
printf 'ok - disabled or invalid resource monitoring starts no workers\n'

cat > "$TEST_ROOT/scripts/unix/resources/collect.bash" <<'EOF'
#!/usr/bin/env bash
sleep 1
printf '%s 8192 16384 2048 4096 25 750 1000\n' "$2" > "$1.tmp"
mv "$1.tmp" "$1"
EOF
YAFP_RESOURCE_CHECK_INTERVAL=30
YAFP_DEVEL=1
yafp_now_ms begin
yafp_resources_context
yafp_now_ms end
[ "$((end - begin))" -lt 500 ] || fail 'worker blocked context collection'
pid=$YAFP_RESOURCE_PID
assert_contains "$yafp_ctx_resources" 'waiting for sample' 'first sample is pending'
[ "$yafp_ctx_resources" = 'Resources: waiting for sample~' ] || fail 'Pending message must be English and compact'
for iteration in 1 2 3; do yafp_resources_context; done
[ "$YAFP_RESOURCE_PID" = "$pid" ] || fail 'duplicate workers'
yafp-reload
YAFP_RESOURCE_CHECK_INTERVAL=30
yafp_resources_context
[ "$YAFP_RESOURCE_PID" = "$pid" ] || fail 'reload duplicated the worker'
for iteration in {1..60}; do
    [ ! -f "$YAFP_RESOURCE_DIR/sample" ] || break
    sleep 0.05
done
yafp_resources_context
assert_contains "$yafp_ctx_resources" 'C25% R50% S50% D75% ' 'CPU first and swap between RAM and disk'
case "$yafp_ctx_resources" in *'|'*) fail 'unexpected separator in compact summary' ;; esac
assert_contains "$(yafp-resources)" '2048/4096 MiB' 'swap details'

# The hot path must work even without any external tools.
saved_path=$PATH
# shellcheck disable=SC2123
PATH=/nonexistent
yafp_resources_context
PATH=$saved_path
printf 'ok - single nonblocking worker, cache preserved on reload, and rendering without external processes\n'

git init --quiet "$TEST_ROOT/repo"
printf 'staged\n' > "$TEST_ROOT/repo/file.txt"
git -C "$TEST_ROOT/repo" add file.txt
original_pwd=$PWD

for theme in default minimal light; do
    YAFP_THEME=$theme
    yafp-reload
    YAFP_RESOURCE_CHECK_INTERVAL=30
    YAFP_REPOS=0 YAFP_TITLE=0 YAFP_CLOCK=1 YAFP_OSC133=0 YAFP_ERROR=0 YAFP_DEVEL=1
    yaft_general_context 0
    yafp_ctx_git_has_repo=0 yafp_venv_segment='' yafp_ctx_show_status=0
    for labels in letters unicode; do
        for values in percent symbols; do
            YAFP_RESOURCE_LABEL_STYLE=$labels YAFP_RESOURCE_VALUE_STYLE=$values
            case "$labels/$values" in
                letters/percent) expected='C25% R50% S50% D75%' ;;
                unicode/percent) expected='⚙25% ▦50% ⇄50% ◉75%' ;;
                letters/symbols) expected='C⣄ R⣦ S⣦ D⣷' ;;
                unicode/symbols) expected='⚙⣄▦⣦⇄⣦◉⣷' ;;
            esac
            yafp_resources_context
            out="$(theme_render_main_block)"
            plain_prompt
            host_marker='\h'
            if [ -n "${ZSH_VERSION:-}" ]; then host_marker="$(print -P -- '%m')"; fi
            block="↦[$expected]"
            assert_contains "$out" "$host_marker$block" "host and resources in $theme/$labels/$values"
            rest=${out#*"$block"}
            case "$rest" in *"$block"*) fail 'duplicate resources' ;; esac
            out="$(theme_render_resources)"
            assert_contains "$out" $'\033[0;92m' 'green foreground without a background'
            assert_contains "$out" $'\033[0;91m' 'red swap foreground without a background'
            frame=$cSeparator
            [ "$theme" != default ] || frame=$cGit
            assert_contains "$out" "$(ps1_wrap "$frame")↦[" 'opening frame uses Git colors'
            assert_contains "$out" "$(ps1_wrap "$frame")]" 'closing frame uses Git colors'
            plain_prompt
            [ "$out" = "$block" ] || fail "frame or sample age in $theme/$labels/$values: $out"
            assert_contains "$yafp_ctx_resources" "$expected " 'summary and space before sample age'
            saved_summary=$yafp_ctx_resources
            yafp_ctx_resources+="~"
            case "$yafp_ctx_resources" in *' ~'*) fail 'Space before refresh marker in timed summary' ;; esac
            case "$yafp_ctx_resources" in *s~) ;; *) fail 'Refresh marker must touch sample age' ;; esac
            out="$(theme_render_resources)"
            plain_prompt
            [ "$out" = "↦[${expected}~]" ] || fail "Refresh marker spacing: $theme/$labels/$values/$out"
            yafp_ctx_resources=$saved_summary
        done
    done
    YAFP_RESOURCE_CHECK_INTERVAL=0
    yafp_resources_context
    [ -z "$(theme_render_resources)" ] || fail 'empty frame while disabled'
    [ "$(yafp-resources)" = 'Resources disabled. Set YAFP_RESOURCE_CHECK_INTERVAL=30.' ] || fail 'Disabled message must be English'
    YAFP_RESOURCE_CHECK_INTERVAL=30
    yafp_resources_context

    # Host resources affect Git banner columns only when Git follows the host.
    YAFP_REPOS=1 YAFP_REMOTE_CHECK_INTERVAL=0 COLUMNS=1000
    cd "$TEST_ROOT/repo"
    yaft_general_context 0
    yafp_git_context 0
    [ "$yafp_ctx_git_staged" -eq 1 ] || fail 'staged changes fixture'
    saved_resources=$yafp_ctx_resources
    yafp_ctx_resources=''
    theme_prepare_expansion_columns
    before_column=$yafp_ctx_git_staged_indicator_column
    yafp_ctx_resources=$saved_resources
    theme_prepare_expansion_columns
    delta=$((yafp_ctx_git_staged_indicator_column - before_column))
    out="$(theme_render_resources)"
    plain_prompt
    yafp_text_display_width "$out"
    expected_delta=$yafp_display_width
    [ "$theme" != default ] || expected_delta=0
    [ "$delta" -eq "$expected_delta" ] || fail "staged indicator column in $theme: $delta/$expected_delta"
    cd "$original_pwd"
    YAFP_REPOS=0
    yafp_ctx_git_has_repo=0 yafp_ctx_git_staged=0
    # Failed input remains represented in the command context.
    yafp_err_context 7
    [ "$yafp_ctx_exit" = 7 ] || fail 'previous command status changed'
done
YAFP_RESOURCE_ATTEMPT=$((SECONDS - 31))
yafp_resources_context
case "$yafp_ctx_resources" in *' ~'*) fail 'Refresh context inserted a space before the marker' ;; esac
case "$yafp_ctx_resources" in *s~) ;; *) fail 'Cached refresh must show age followed by tilde' ;; esac
for iteration in {1..60}; do
    kill -0 "$YAFP_RESOURCE_PID" 2>/dev/null || break
    sleep 0.05
done
yafp_resources_context
YAFP_RESOURCE_LABEL_STYLE=letters YAFP_RESOURCE_VALUE_STYLE=percent

while IFS='|' read -r kind value color cell; do
    case "$kind" in
        R) index=1; unicode_label='▦' ;;
        S) index=2; unicode_label='⇄' ;;
        C) index=0; unicode_label='⚙' ;;
        D) index=3; unicode_label='◉' ;;
    esac
    case "$color" in Green) code=92 ;; Yellow) code=93 ;; Red) code=91 ;; DarkGray) code=90 ;; esac
    for labels in letters unicode; do
        for values in percent symbols; do
            YAFP_RESOURCE_LABEL_STYLE=$labels YAFP_RESOURCE_VALUE_STYLE=$values
            label=$kind
            [ "$labels" != unicode ] || label=$unicode_label
            expected="$label$cell"
            if [ "$values" = percent ] && [ "$value" != - ]; then expected="$label$value%"; fi
            yafp_resource_segment "$index" "$value"
            [ "$yafp_resource_token" = "$expected" ] || fail "token $kind/$value/$labels/$values"
            [ "$yafp_resource_color" = "$code" ] || fail "threshold $kind/$value"
        done
    done
done < "$ROOT_DIR/tests/resource_display_cases.txt"
YAFP_RESOURCE_LABEL_STYLE=bad YAFP_RESOURCE_VALUE_STYLE=bad
yafp_resource_segment 1 74
[ "$yafp_resource_token" = 'R74%' ] || fail 'invalid style fallback'
YAFP_RESOURCE_LABEL_STYLE=letters YAFP_RESOURCE_VALUE_STYLE=percent
printf 'ok - labels, four display modes, Braille, and shared color boundaries\n'

# Unallocated swap, unknown capacity, and a fractional percentage.
YAFP_RESOURCE_SWAP_USED=0 YAFP_RESOURCE_SWAP_TOTAL=0
yafp_resources_summary
assert_contains "$yafp_ctx_resources" ' S0% ' 'unallocated swap'
YAFP_RESOURCE_SWAP_USED=1552 YAFP_RESOURCE_SWAP_TOTAL=3072
yafp_resources_summary
assert_contains "$yafp_ctx_resources" ' S50% ' 'integer swap percentage'
YAFP_RESOURCE_SWAP_TOTAL=-
yafp_resources_summary
assert_contains "$yafp_ctx_resources" ' SN/A ' 'unknown swap capacity'

# Truncated or code-shaped cache data never executes or reaches the prompt.
# shellcheck disable=SC2016
printf '%s\n' '$(touch forbidden) 1 2 3' > "$YAFP_RESOURCE_DIR/sample"
yafp_resources_context
case "$yafp_ctx_resources" in *'R50%'*) fail 'invalid cache accepted' ;; esac
[ ! -e forbidden ] || fail 'cache executed code'
YAFP_RESOURCE_PID=99999999
YAFP_RESOURCE_ATTEMPT=$((SECONDS - 31))
yafp_resources_context
[ "$YAFP_RESOURCE_PID" != 99999999 ] || fail 'dead worker did not recover'
printf 'ok - three themes, previous status, invalid cache, and worker recovery\n'
