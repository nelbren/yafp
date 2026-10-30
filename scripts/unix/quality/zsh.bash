#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." >/dev/null && pwd)"
cd "$ROOT_DIR"
command -v zsh >/dev/null 2>&1 || { printf 'error - zsh is required\n' >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { printf 'error - python3 is required for PTY tests\n' >&2; exit 1; }
for file in yafp-ps1.zsh yafp-cfg.zsh.example themes/*.zsh tests/*.zsh; do
    zsh -n "$file"
done
printf 'ok - zsh syntax\n'
zsh -df tests/zsh_prompt_test.zsh
zsh -df tests/block_frames_test.bash
zsh -df tests/zsh_remote_status_test.zsh
zsh -df tests/resources_test.bash
zsh -df tests/codex_test.bash
python3 tests/zsh_interactive_test.py
