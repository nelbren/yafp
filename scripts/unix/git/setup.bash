#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/../../.." >/dev/null && pwd)"
SOURCE_HOOK="$SCRIPT_DIR/prepare-commit-msg"
REPO_PATH="$ROOT_DIR"
DRY_RUN=0

print_usage() {
    printf 'Usage: %s [--dry-run] [--repo PATH]\n' "${0##*/}"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            ;;
        --repo)
            [ "$#" -ge 2 ] || {
                print_usage >&2
                exit 2
            }
            REPO_PATH="$2"
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            print_usage >&2
            exit 2
            ;;
    esac
    shift
done

repo_root="$(git -C "$REPO_PATH" rev-parse --show-toplevel 2>/dev/null)" || {
    printf '❌ Not a Git repository: %s\n' "$REPO_PATH" >&2
    exit 1
}
hooks_dir="$(git -C "$repo_root" rev-parse --git-path hooks)"
case "$hooks_dir" in
    /*|[A-Za-z]:/*) ;;
    *) hooks_dir="$repo_root/$hooks_dir" ;;
esac
target_hook="$hooks_dir/prepare-commit-msg"

if [ -e "$target_hook" ]; then
    if cmp -s "$SOURCE_HOOK" "$target_hook"; then
        printf '✅ Origin-Device hook is already installed: %s\n' \
            "$target_hook"
        exit 0
    fi
    printf '❌ Refusing to overwrite an existing hook: %s\n' \
        "$target_hook" >&2
    exit 1
fi

if [ "$DRY_RUN" -eq 1 ]; then
    printf 'Would install Origin-Device hook: %s\n' "$target_hook"
    exit 0
fi

mkdir -p "$hooks_dir"
temp_hook="$(mktemp "$hooks_dir/.prepare-commit-msg.XXXXXX")"
cleanup() {
    rm -f "$temp_hook"
}
trap cleanup EXIT

cp "$SOURCE_HOOK" "$temp_hook"
chmod +x "$temp_hook"
mv "$temp_hook" "$target_hook"
trap - EXIT

printf '✅ Installed Origin-Device hook: %s\n' "$target_hook"
