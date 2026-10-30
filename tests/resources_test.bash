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
printf 'ok - recursos desactivados o inválidos no crean workers\n'

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
[ "$((end - begin))" -lt 500 ] || fail 'worker bloqueó el contexto'
pid=$YAFP_RESOURCE_PID
assert_contains "$yafp_ctx_resources" 'esperando muestra' 'primera muestra pendiente'
for iteration in 1 2 3; do yafp_resources_context; done
[ "$YAFP_RESOURCE_PID" = "$pid" ] || fail 'workers duplicados'
yafp-reload
YAFP_RESOURCE_CHECK_INTERVAL=30
yafp_resources_context
[ "$YAFP_RESOURCE_PID" = "$pid" ] || fail 'reload duplicó el worker'
for iteration in {1..60}; do
    [ ! -f "$YAFP_RESOURCE_DIR/sample" ] || break
    sleep 0.05
done
yafp_resources_context
assert_contains "$yafp_ctx_resources" 'C25% R50% S50% D75% ' 'CPU al inicio y swap entre RAM y disco'
case "$yafp_ctx_resources" in *'|'*) fail 'separador en resumen compacto' ;; esac
assert_contains "$(yafp-resources)" '2048/4096 MiB' 'detalle de swap'

# The hot path must work even without any external tools.
saved_path=$PATH
# shellcheck disable=SC2123
PATH=/nonexistent
yafp_resources_context
PATH=$saved_path
printf 'ok - worker no bloqueante, único, conserva caché al recargar y renderiza sin procesos\n'

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
            block="⇢[$expected]"
            assert_contains "$out" "$host_marker$block" "host y recursos en $theme/$labels/$values"
            rest=${out#*"$block"}
            case "$rest" in *"$block"*) fail 'recursos duplicados' ;; esac
            out="$(theme_render_resources)"
            assert_contains "$out" $'\033[0;92m' 'verde sin fondo'
            assert_contains "$out" $'\033[0;91m' 'swap roja sin fondo'
            frame=$cSeparator
            [ "$theme" != default ] || frame=$cGit
            assert_contains "$out" "$(ps1_wrap "$frame")⇢[" 'marco inicial con colores Git'
            assert_contains "$out" "$(ps1_wrap "$frame")]" 'marco final con colores Git'
            plain_prompt
            [ "$out" = "$block" ] || fail "marco o edad en $theme/$labels/$values: $out"
            assert_contains "$yafp_ctx_resources" "$expected " 'resumen y espacio antes de la edad'
        done
    done
    YAFP_RESOURCE_CHECK_INTERVAL=0
    yafp_resources_context
    [ -z "$(theme_render_resources)" ] || fail 'marco vacío cuando está desactivado'
    YAFP_RESOURCE_CHECK_INTERVAL=30
    yafp_resources_context

    # Host resources affect Git banner columns only when Git follows the host.
    YAFP_REPOS=1 YAFP_REMOTE_CHECK_INTERVAL=0 COLUMNS=1000
    cd "$TEST_ROOT/repo"
    yaft_general_context 0
    yafp_git_context 0
    [ "$yafp_ctx_git_staged" -eq 1 ] || fail 'fixture de cambios staged'
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
    [ "$delta" -eq "$expected_delta" ] || fail "columna staged en $theme: $delta/$expected_delta"
    cd "$original_pwd"
    YAFP_REPOS=0
    yafp_ctx_git_has_repo=0 yafp_ctx_git_staged=0
    # Failed input remains represented in the command context.
    yafp_err_context 7
    [ "$yafp_ctx_exit" = 7 ] || fail 'estado del comando alterado'
done
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
            [ "$yafp_resource_color" = "$code" ] || fail "umbral $kind/$value"
        done
    done
done < "$ROOT_DIR/tests/resource_display_cases.txt"
YAFP_RESOURCE_LABEL_STYLE=bad YAFP_RESOURCE_VALUE_STYLE=bad
yafp_resource_segment 1 74
[ "$yafp_resource_token" = 'R74%' ] || fail 'fallback de estilos inválidos'
YAFP_RESOURCE_LABEL_STYLE=letters YAFP_RESOURCE_VALUE_STYLE=percent
printf 'ok - etiquetas, cuatro combinaciones, Braille y límites de color compartidos\n'

# Unallocated swap, unknown capacity, and a fractional percentage.
YAFP_RESOURCE_SWAP_USED=0 YAFP_RESOURCE_SWAP_TOTAL=0
yafp_resources_summary
assert_contains "$yafp_ctx_resources" ' S0% ' 'swap no asignada'
YAFP_RESOURCE_SWAP_USED=1552 YAFP_RESOURCE_SWAP_TOTAL=3072
yafp_resources_summary
assert_contains "$yafp_ctx_resources" ' S50% ' 'porcentaje entero de swap'
YAFP_RESOURCE_SWAP_TOTAL=-
yafp_resources_summary
assert_contains "$yafp_ctx_resources" ' SN/D ' 'capacidad de swap desconocida'

# Truncated or code-shaped cache data never executes or reaches the prompt.
# shellcheck disable=SC2016
printf '%s\n' '$(touch forbidden) 1 2 3' > "$YAFP_RESOURCE_DIR/sample"
yafp_resources_context
case "$yafp_ctx_resources" in *'R50%'*) fail 'caché inválida aceptada' ;; esac
[ ! -e forbidden ] || fail 'la caché ejecutó código'
YAFP_RESOURCE_PID=99999999
YAFP_RESOURCE_ATTEMPT=$((SECONDS - 31))
yafp_resources_context
[ "$YAFP_RESOURCE_PID" != 99999999 ] || fail 'worker muerto no se recuperó'
printf 'ok - tres temas, estado previo, caché inválida y recuperación de worker\n'
