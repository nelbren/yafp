#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/yafp-analyzer-test.XXXXXX")"
TEST_ROOT="$(cd -- "$TEST_ROOT" && pwd)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
setup="$ROOT_DIR/scripts/unix/setup/psscriptanalyzer.bash"
bash_bin="$(command -v bash)"

fail() {
    printf 'not ok - %s\n' "$1" >&2
    exit 1
}

mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/repo with spaces/scripts/unix/setup" \
    "$TEST_ROOT/repo with spaces/scripts/windows/setup"
cp "$setup" "$TEST_ROOT/repo with spaces/scripts/unix/setup/"
setup="$TEST_ROOT/repo with spaces/scripts/unix/setup/psscriptanalyzer.bash"
ln -s "$(command -v dirname)" "$TEST_ROOT/bin/dirname"

PATH="$TEST_ROOT/bin" "$bash_bin" "$setup" --help >/dev/null
if PATH="$TEST_ROOT/bin" "$bash_bin" "$setup" >"$TEST_ROOT/output" 2>&1; then
    fail 'missing pwsh must fail'
fi
grep -q 'pwsh.*required' "$TEST_ROOT/output" || fail 'missing prerequisite message'
status=0
"$bash_bin" "$setup" --invalid >/dev/null 2>&1 || status=$?
[ "$status" -eq 2 ] || fail 'invalid option must exit with status 2'

cat >"$TEST_ROOT/bin/pwsh" <<'EOF'
#!/bin/sh
printf '%s\n' "$@"
exit "${YAFP_TEST_PWSH_EXIT:-0}"
EOF
chmod +x "$TEST_ROOT/bin/pwsh"
expected_path="$TEST_ROOT/repo with spaces/scripts/windows/setup/psscriptanalyzer.ps1"
expected="$(printf '%s\n' '-NoProfile' '-File' "$expected_path" '-DryRun')"
actual="$(PATH="$TEST_ROOT/bin" "$bash_bin" "$setup" --dry-run)"
[ "$actual" = "$expected" ] || fail 'dry run arguments or spaced path were not preserved'
expected="$(printf '%s\n' '-NoProfile' '-File' "$expected_path")"
actual="$(PATH="$TEST_ROOT/bin" "$bash_bin" "$setup")"
[ "$actual" = "$expected" ] || fail 'installation arguments were not preserved'
status=0
YAFP_TEST_PWSH_EXIT=17 PATH="$TEST_ROOT/bin" "$bash_bin" "$setup" \
    >/dev/null 2>&1 || status=$?
[ "$status" -eq 17 ] || fail 'pwsh exit status was not propagated'

printf 'ok - Unix PSScriptAnalyzer setup prerequisites, arguments, and failures\n'
