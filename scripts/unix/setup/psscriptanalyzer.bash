#!/usr/bin/env bash
set -euo pipefail

dry_run=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run) dry_run=1 ;;
        -h|--help)
            printf 'Usage: %s [--dry-run]\n' "${0##*/}"
            exit 0
            ;;
        *)
            printf 'Usage: %s [--dry-run]\n' "${0##*/}" >&2
            exit 2
            ;;
    esac
    shift
done

if ! command -v pwsh >/dev/null 2>&1; then
    printf '❌ PowerShell 7.2.11 or later (pwsh) is required.\n' >&2
    exit 1
fi

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." >/dev/null && pwd)"
setup_path="$ROOT_DIR/scripts/windows/setup/psscriptanalyzer.ps1"
if command -v cygpath >/dev/null 2>&1; then
    setup_path="$(cygpath -w "$setup_path")"
fi

arguments=(-NoProfile -File "$setup_path")
if [ "$dry_run" -eq 1 ]; then
    arguments+=(-DryRun)
fi
exec pwsh "${arguments[@]}"
