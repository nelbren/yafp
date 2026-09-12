#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null && pwd)"
export TERM="${TERM:-xterm-256color}"
export YAFP_NO_INSTALL_HOOKS=1

set +u
. "$ROOT_DIR/yafp-ps1.bash"
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

printf 'ok - Bash theme loading and fallback\n'
