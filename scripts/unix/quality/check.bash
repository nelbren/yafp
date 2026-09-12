#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." >/dev/null && pwd)"
REQUIRE_LINTERS="${YAFP_REQUIRE_LINTERS:-0}"

cd "$ROOT_DIR"

print_quality_line() {
    local line="$1"
    local message

    if [[ "$line" == "ok - "* ]]; then
        message="✅ ${line#ok - }"
        if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
            printf '\033[32m%s\033[0m\n' "$message"
        else
            printf '%s\n' "$message"
        fi
    elif [[ "$line" == "not ok - "* ]]; then
        print_quality_error "${line#not ok - }"
    elif [[ "$line" == "error - "* ]]; then
        print_quality_error "${line#error - }"
    else
        printf '%s\n' "$line"
    fi
}

print_quality_warning() {
    local message="⚠️ $1"

    if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
        printf '\033[33m%s\033[0m\n' "$message" >&2
    else
        printf '%s\n' "$message" >&2
    fi
}

print_quality_error() {
    local message="❌ $1"

    if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
        printf '\033[31m%s\033[0m\n' "$message" >&2
    else
        printf '%s\n' "$message" >&2
    fi
}

handle_quality_error() {
    local status=$?

    trap - ERR
    print_quality_error "Unix quality checks failed (exit $status)"
    exit "$status"
}

trap handle_quality_error ERR

colorize_quality_output() {
    local line

    while IFS= read -r line; do
        print_quality_line "$line"
    done
}

require_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        print_quality_error "Required command not found: $command_name"
        return 1
    fi
}

run_optional() {
    local command_name="$1"
    shift

    if command -v "$command_name" >/dev/null 2>&1; then
        "$command_name" "$@"
        return
    fi

    if [ "$REQUIRE_LINTERS" -eq 1 ]; then
        print_quality_error "Required linter not found: $command_name"
        return 1
    fi

    print_quality_warning "Optional linter not found: $command_name"
}

require_command bash
require_command git

while IFS= read -r -d '' file; do
    bash -n "$file"
done < <(find . -type f -name '*.bash' -print0)
print_quality_line 'ok - Bash syntax'

bash tests/osc133_test.bash 2>&1 | colorize_quality_output
bash tests/theme_loading_test.bash 2>&1 | colorize_quality_output
bash tests/remote_status_test.bash 2>&1 | colorize_quality_output

if command -v shellcheck >/dev/null 2>&1; then
    while IFS= read -r -d '' file; do
        shellcheck "$file"
    done < <(git ls-files -z '*.bash')
else
    run_optional shellcheck
fi

run_optional markdownlint '**/*.md'

print_quality_line 'ok - Unix quality checks'
