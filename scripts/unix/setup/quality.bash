#!/usr/bin/env bash
set -euo pipefail

MARKDOWNLINT_VERSION='0.49.1'
DRY_RUN=0

print_usage() {
    printf 'Usage: %s [--dry-run]\n' "${0##*/}"
}

run_command() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '  +'
        printf ' %q' "$@"
        printf '\n'
        return
    fi

    "$@"
}

run_privileged() {
    if [ "$(id -u)" -eq 0 ]; then
        run_command "$@"
    elif command -v sudo >/dev/null 2>&1; then
        run_command sudo "$@"
    else
        printf '❌ Root privileges are required to run: %s\n' "$1" >&2
        return 1
    fi
}

install_linux_tools() {
    local need_node="$1"
    local need_shellcheck="$2"

    if command -v apt-get >/dev/null 2>&1; then
        local packages=()
        [ "$need_shellcheck" -eq 1 ] && packages+=(shellcheck)
        if [ "$need_node" -eq 1 ]; then
            packages+=(nodejs npm)
        fi
        run_privileged apt-get update
        run_privileged apt-get install --yes "${packages[@]}"
    elif command -v dnf >/dev/null 2>&1; then
        local packages=()
        [ "$need_shellcheck" -eq 1 ] && packages+=(ShellCheck)
        [ "$need_node" -eq 1 ] && packages+=(nodejs npm)
        run_privileged dnf install --assumeyes "${packages[@]}"
    elif command -v pacman >/dev/null 2>&1; then
        local packages=()
        [ "$need_shellcheck" -eq 1 ] && packages+=(shellcheck)
        [ "$need_node" -eq 1 ] && packages+=(nodejs npm)
        run_privileged pacman --sync --needed --noconfirm "${packages[@]}"
    elif command -v zypper >/dev/null 2>&1; then
        local packages=()
        [ "$need_shellcheck" -eq 1 ] && packages+=(ShellCheck)
        [ "$need_node" -eq 1 ] && packages+=(nodejs npm)
        run_privileged zypper --non-interactive install "${packages[@]}"
    else
        printf '❌ Supported package manager not found.\n' >&2
        return 1
    fi
}

install_macos_tools() {
    local packages=()

    if ! command -v brew >/dev/null 2>&1; then
        printf '❌ Homebrew is required on macOS: https://brew.sh\n' >&2
        return 1
    fi

    ! command -v shellcheck >/dev/null 2>&1 && packages+=(shellcheck)
    ! command -v npm >/dev/null 2>&1 && packages+=(node)
    if [ "${#packages[@]}" -gt 0 ]; then
        run_command brew install "${packages[@]}"
    fi
}

run_windows_setup() {
    local setup_path="$ROOT_DIR/scripts/windows/setup/quality.ps1"
    local arguments=(-NoProfile -File "$setup_path")

    if ! command -v pwsh >/dev/null 2>&1; then
        printf '❌ PowerShell 7 is required on Windows.\n' >&2
        return 1
    fi
    if command -v cygpath >/dev/null 2>&1; then
        setup_path="$(cygpath -w "$setup_path")"
        arguments=(-NoProfile -File "$setup_path")
    fi
    [ "$DRY_RUN" -eq 1 ] && arguments+=(-DryRun)

    run_command pwsh "${arguments[@]}"
}

install_markdownlint() {
    local npm_prefix

    if [ "$DRY_RUN" -eq 0 ] && [ "$(uname -s)" = 'Linux' ]; then
        npm_prefix="$(npm prefix --global)"
        if [ -d "$npm_prefix" ] && [ ! -w "$npm_prefix" ]; then
            run_privileged npm install --global \
                "markdownlint-cli@$MARKDOWNLINT_VERSION"
            return
        fi
    fi

    run_command npm install --global "markdownlint-cli@$MARKDOWNLINT_VERSION"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
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

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." >/dev/null && pwd)"

printf '🔧 Preparing Unix quality tools\n'

case "$(uname -s)" in
    Darwin)
        install_macos_tools
        ;;
    Linux)
        need_node=0
        need_shellcheck=0
        command -v npm >/dev/null 2>&1 || need_node=1
        command -v shellcheck >/dev/null 2>&1 || need_shellcheck=1
        if [ "$need_node" -eq 1 ] || [ "$need_shellcheck" -eq 1 ]; then
            install_linux_tools "$need_node" "$need_shellcheck"
        fi
        ;;
    MINGW*|MSYS*|CYGWIN*)
        run_windows_setup
        exit 0
        ;;
    *)
        printf '❌ Unsupported Unix platform: %s\n' "$(uname -s)" >&2
        exit 1
        ;;
esac

install_markdownlint

if [ "$DRY_RUN" -eq 0 ]; then
    command -v shellcheck >/dev/null 2>&1
    command -v markdownlint >/dev/null 2>&1
fi

printf '✅ Unix quality tools are ready\n'
