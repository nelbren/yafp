#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/yafp-hook-test.XXXXXX")"

cleanup() {
    rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
    printf 'not ok - %s\n' "$1" >&2
    exit 1
}

repo="$TEST_ROOT/repo"
mkdir -p "$repo"
git -C "$repo" init --quiet

setup="$ROOT_DIR/scripts/unix/git/setup.bash"
hook="$repo/.git/hooks/prepare-commit-msg"

dry_run_output="$(bash "$setup" --dry-run --repo "$repo")"
case "$dry_run_output" in
    *'Would install Origin-Device hook:'*) ;;
    *) fail 'hook setup dry run did not describe the installation' ;;
esac
[ ! -e "$hook" ] || fail 'hook setup dry run changed the repository'

bash "$setup" --repo "$repo" >/dev/null
[ -x "$hook" ] || fail 'installed hook is not executable'
bash "$setup" --repo "$repo" >/dev/null

message_file="$TEST_ROOT/message"
printf '%s\n' 'feat: test hook' > "$message_file"
COMPUTERNAME='TEST-MAC' PATH='/usr/bin:/bin' "$hook" "$message_file"
grep -qx 'Origin-Device: TEST-MAC' "$message_file" ||
    fail 'hook did not add the calculated device name'

COMPUTERNAME='TEST-MAC' PATH='/usr/bin:/bin' "$hook" "$message_file"
[ "$(grep -c '^Origin-Device:' "$message_file")" -eq 1 ] ||
    fail 'hook duplicated an existing trailer'

printf '%s\n\n%s\n' \
    'feat: preserve hook trailer' \
    'Origin-Device: ORIGINAL-DEVICE' > "$message_file"
COMPUTERNAME='TEST-MAC' PATH='/usr/bin:/bin' "$hook" "$message_file"
grep -qx 'Origin-Device: ORIGINAL-DEVICE' "$message_file" ||
    fail 'hook replaced an existing device trailer'

printf 'ok - Origin-Device prepare-commit-msg hook\n'
