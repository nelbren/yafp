#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." >/dev/null && pwd)"
CONFIG_PATH="$ROOT_DIR/yafp-cfg.bash"
STRICT=0
PASS_COUNT=0
WARNING_COUNT=0
ERROR_COUNT=0
DOCTOR_PREFIX=''

print_usage() {
    printf 'Usage: %s [--config PATH] [--strict]\n' "${0##*/}"
}

doctor_pass() {
    local message

    PASS_COUNT=$((PASS_COUNT + 1))
    message="${DOCTOR_PREFIX}✅ $1"
    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
        printf '\033[32m%s\033[0m\n' "$message"
    else
        printf '%s\n' "$message"
    fi
}

doctor_warning() {
    local message

    WARNING_COUNT=$((WARNING_COUNT + 1))
    message="${DOCTOR_PREFIX}⚠️ $1"
    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
        printf '\033[33m%s\033[0m\n' "$message"
    else
        printf '%s\n' "$message"
    fi
}

doctor_error() {
    local message

    ERROR_COUNT=$((ERROR_COUNT + 1))
    message="${DOCTOR_PREFIX}❌ $1"
    if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
        printf '\033[31m%s\033[0m\n' "$message" >&2
    else
        printf '%s\n' "$message" >&2
    fi
}

check_command() {
    local command_name="$1"
    local requirement="$2"

    if command -v "$command_name" >/dev/null 2>&1; then
        doctor_pass "Command available: $command_name"
    elif [ "$requirement" = 'required' ]; then
        doctor_error "Required command missing: $command_name"
    else
        doctor_warning "Optional quality command missing: $command_name"
    fi
}

check_binary_option() {
    local name="$1"
    local value="$2"

    case "$value" in
        0|1)
            doctor_pass "$name is valid: $value"
            ;;
        '')
            doctor_warning "$name is not configured"
            ;;
        *)
            doctor_error "$name must be 0 or 1; found: $value"
            ;;
    esac
}

check_configuration() {
    local output
    local darkc=''
    local clock=''
    local osc133=''
    local remote_interval=''
    local devel=''
    local theme=''
    local repos=''
    local title=''
    local error=''
    local pvenv=''
    local developer_prefix=''
    local production_prefix=''
    local key
    local value

    printf '│   ├── 📄 yafp-cfg.bash.example\n'
    DOCTOR_PREFIX='│   │   └── '
    if [ ! -f "$ROOT_DIR/yafp-cfg.bash.example" ]; then
        doctor_error 'Configuration template missing: yafp-cfg.bash.example'
    else
        doctor_pass 'Configuration template found'
    fi

    printf '│   └── 📄 %s\n' "$CONFIG_PATH"
    DOCTOR_PREFIX='│       ├── '
    if [ ! -f "$CONFIG_PATH" ]; then
        doctor_error 'Personal configuration missing'
        DOCTOR_PREFIX='│       └── '
        doctor_warning 'Create it with: cp yafp-cfg.bash.example yafp-cfg.bash'
        return
    fi
    doctor_pass 'Personal configuration found'

    if ! bash -n "$CONFIG_PATH"; then
        DOCTOR_PREFIX='│       └── '
        doctor_error 'Invalid Bash configuration syntax'
        return
    fi
    doctor_pass 'Bash configuration syntax is valid'

    if ! output="$(bash -c '
        # shellcheck disable=SC1090
        source "$1"
        printf "__YAFP_DARKC=%s\n" "${YAFP_DARKC-}"
        printf "__YAFP_CLOCK=%s\n" "${YAFP_CLOCK-}"
        printf "__YAFP_OSC133=%s\n" "${YAFP_OSC133-}"
        printf "__YAFP_REMOTE_CHECK_INTERVAL=%s\n" \
            "${YAFP_REMOTE_CHECK_INTERVAL-}"
        printf "__YAFP_DEVEL=%s\n" "${YAFP_DEVEL-}"
        printf "__YAFP_THEME=%s\n" "${YAFP_THEME-}"
        printf "__YAFP_REPOS=%s\n" "${YAFP_REPOS-}"
        printf "__YAFP_TITLE=%s\n" "${YAFP_TITLE-}"
        printf "__YAFP_ERROR=%s\n" "${YAFP_ERROR-}"
        printf "__YAFP_PVENV=%s\n" "${YAFP_PVENV-}"
        printf "__DEV=%s\n" "${DEV-}"
        printf "__PRO=%s\n" "${PRO-}"
    ' bash "$CONFIG_PATH")"; then
        DOCTOR_PREFIX='│       └── '
        doctor_error 'Unable to load Bash configuration'
        return
    fi

    while IFS='=' read -r key value; do
        case "$key" in
            __YAFP_DARKC) darkc="$value" ;;
            __YAFP_CLOCK) clock="$value" ;;
            __YAFP_OSC133) osc133="$value" ;;
            __YAFP_REMOTE_CHECK_INTERVAL) remote_interval="$value" ;;
            __YAFP_DEVEL) devel="$value" ;;
            __YAFP_THEME) theme="$value" ;;
            __YAFP_REPOS) repos="$value" ;;
            __YAFP_TITLE) title="$value" ;;
            __YAFP_ERROR) error="$value" ;;
            __YAFP_PVENV) pvenv="$value" ;;
            __DEV) developer_prefix="$value" ;;
            __PRO) production_prefix="$value" ;;
        esac
    done <<< "$output"

    check_binary_option YAFP_DARKC "$darkc"
    check_binary_option YAFP_CLOCK "$clock"
    check_binary_option YAFP_OSC133 "$osc133"
    check_binary_option YAFP_DEVEL "$devel"
    check_binary_option YAFP_REPOS "$repos"
    check_binary_option YAFP_TITLE "$title"
    check_binary_option YAFP_ERROR "$error"
    check_binary_option YAFP_PVENV "$pvenv"

    if [ -n "$developer_prefix" ] && [ -n "$production_prefix" ]; then
        doctor_pass 'Development and production host prefixes are configured'
    else
        doctor_error 'DEV and PRO host prefixes must be non-empty strings'
    fi

    if [[ "$remote_interval" =~ ^[0-9]+$ ]]; then
        doctor_pass "YAFP_REMOTE_CHECK_INTERVAL is valid: $remote_interval"
    else
        doctor_error 'YAFP_REMOTE_CHECK_INTERVAL must be a non-negative integer'
    fi

    DOCTOR_PREFIX='│       └── '
    if [ -n "$theme" ] && [ -f "$ROOT_DIR/themes/$theme.bash" ]; then
        doctor_pass "Configured Bash theme exists: $theme"
    else
        doctor_error "Configured Bash theme not found: ${theme:-<empty>}"
    fi
}

check_theme_pairs() {
    local file
    local theme

    for file in "$ROOT_DIR"/themes/*.bash; do
        [ -e "$file" ] || continue
        theme="${file##*/}"
        theme="${theme%.bash}"
        if [ ! -f "$ROOT_DIR/themes/$theme.ps1" ]; then
            doctor_error "PowerShell theme counterpart missing: $theme.ps1"
        fi
    done
    for file in "$ROOT_DIR"/themes/*.ps1; do
        [ -e "$file" ] || continue
        theme="${file##*/}"
        theme="${theme%.ps1}"
        if [ ! -f "$ROOT_DIR/themes/$theme.bash" ]; then
            doctor_error "Bash theme counterpart missing: $theme.bash"
        fi
    done

    if [ "$ERROR_COUNT" -eq 0 ]; then
        doctor_pass 'Bash and PowerShell theme sets are paired'
    fi
}

check_profile() {
    local found
    local line
    local profile

    for profile in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
        found=0
        [ -f "$profile" ] || continue
        while IFS= read -r line; do
            case "$line" in
                *yafp-ps1.bash*) found=1; break ;;
            esac
        done < "$profile"
        if [ "$found" -eq 1 ]; then
            doctor_pass "Bash profile loads YAFP: $profile"
            return
        fi
    done

    doctor_warning 'No Bash profile entry loading yafp-ps1.bash was found'
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --config)
            if [ "$#" -lt 2 ]; then
                print_usage >&2
                exit 2
            fi
            CONFIG_PATH="$2"
            shift
            ;;
        --strict)
            STRICT=1
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

printf '🩺 YAFP Unix doctor\n'

printf '├── 🖥️ Runtime\n'
DOCTOR_PREFIX='│   └── '
case "$(uname -s)" in
    Linux|Darwin|MINGW*|MSYS*|CYGWIN*)
        doctor_pass "Supported platform: $(uname -s)"
        ;;
    *)
        doctor_error "Unsupported platform: $(uname -s)"
        ;;
esac

printf '├── 🔧 Commands\n'
DOCTOR_PREFIX='│   ├── '
check_command bash required
check_command git required
check_command shellcheck optional
DOCTOR_PREFIX='│   └── '
check_command markdownlint optional

printf '├── 🧩 Prompt\n'
DOCTOR_PREFIX='│   └── '
if [ -f "$ROOT_DIR/yafp-ps1.bash" ]; then
    doctor_pass 'Bash prompt entry point found'
else
    doctor_error 'Bash prompt entry point missing: yafp-ps1.bash'
fi

printf '├── ⚙️ Configuration\n'
check_configuration

printf '├── 🔗 Integration\n'
DOCTOR_PREFIX='│   ├── '
check_theme_pairs
DOCTOR_PREFIX='│   └── '
check_profile

printf '└── 🩺 Summary: %d passed, %d warning(s), %d error(s)\n' \
    "$PASS_COUNT" "$WARNING_COUNT" "$ERROR_COUNT"

if [ "$ERROR_COUNT" -gt 0 ] || {
    [ "$STRICT" -eq 1 ] && [ "$WARNING_COUNT" -gt 0 ]
}; then
    exit 1
fi
