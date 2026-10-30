#!/usr/bin/env bash
# Python is optional and is required only for the enabled Codex integration.
if command -v python3 >/dev/null 2>&1; then
    exec python3 "${BASH_SOURCE[0]%/*}/collect.py" "$1" "$2"
fi
printf '%s missing-python - - - -\n' "$2" > "$1.tmp"
mv -- "$1.tmp" "$1"
