#!/bin/bash
#
# yafp-ps1.bash
#
# Main engine of YAFP
#

# Customize in themes...

# Base colors
YAFP_COLOR_NORMAL_BG="black"
YAFP_COLOR_NORMAL_FG="white"

YAFP_COLOR_SEPARATOR_BG="transparent"
YAFP_COLOR_SEPARATOR_FG="white"

YAFP_COLOR_DIR_BG="yellow"
YAFP_COLOR_DIR_FG="black"

YAFP_COLOR_TIMESTAMP_BG="white"
YAFP_COLOR_TIMESTAMP_FG="black"

YAFP_COLOR_STATUS_OK_BG="green"
YAFP_COLOR_STATUS_OK_FG="black"

YAFP_COLOR_STATUS_WARNING_BG="yellow"
YAFP_COLOR_STATUS_WARNING_FG="black"

YAFP_COLOR_STATUS_ERROR_BG="RED"
YAFP_COLOR_STATUS_ERROR_FG="WHITE"
YAFP_COLOR_STATUS_ERROR_ATTRS="blink"

YAFP_COLOR_STATUS_NEXT_BG="cyan"
YAFP_COLOR_STATUS_NEXT_FG="black"

YAFP_COLOR_USER_BG="cyan"
YAFP_COLOR_USER_FG="black"

YAFP_COLOR_ROOT_BG="RED"
YAFP_COLOR_ROOT_FG="black"

YAFP_COLOR_HOST_DEV_BG="green"
YAFP_COLOR_HOST_DEV_FG="black"

YAFP_COLOR_HOST_PRO_BG="magenta"
YAFP_COLOR_HOST_PRO_FG="black"

YAFP_COLOR_PROMPT_USER_BG="transparent"
YAFP_COLOR_PROMPT_USER_FG="GREEN"

YAFP_COLOR_PROMPT_ROOT_BG="transparent"
YAFP_COLOR_PROMPT_ROOT_FG="RED"

YAFP_COLOR_VENV_BG="magenta"
YAFP_COLOR_VENV_FG="white"

YAFP_COLOR_GIT_BG="white"
YAFP_COLOR_GIT_FG="black"

YAFP_COLOR_REPO_BG="yellow"
YAFP_COLOR_REPO_FG="black"

# Executed command block
YAFP_COLOR_CMD_OK_BG="green"
YAFP_COLOR_CMD_OK_FG="black"

YAFP_COLOR_CMD_ERROR_BG="red"
YAFP_COLOR_CMD_ERROR_FG="WHITE"

# Check / warning blocks
YAFP_COLOR_OK_ICON_BG="green"
YAFP_COLOR_OK_ICON_FG="white"

YAFP_COLOR_WARN_ICON_BG="yellow"
YAFP_COLOR_WARN_ICON_FG="white"

# Git counters
YAFP_COLOR_GIT_DELETE_BG="RED"
YAFP_COLOR_GIT_DELETE_FG="BLACK"
YAFP_COLOR_GIT_DELETE_ATTRS="blink"

YAFP_COLOR_GIT_CHANGE_BG="YELLOW"
YAFP_COLOR_GIT_CHANGE_FG="BLACK"
YAFP_COLOR_GIT_CHANGE_ATTRS="blink"

YAFP_COLOR_GIT_NEW_BG="CYAN"
YAFP_COLOR_GIT_NEW_FG="BLACK"
YAFP_COLOR_GIT_NEW_ATTRS="blink"

# Extra blocks
YAFP_COLOR_CLIENT_BG="white"
YAFP_COLOR_CLIENT_FG="black"

YAFP_COLOR_COUNTRY_BG="cyan"
YAFP_COLOR_COUNTRY_FG="black"

YAFP_COLOR_GIT_BRANCH_BG="blue"
YAFP_COLOR_GIT_BRANCH_FG="white"

# Symbols and labels
YAFP_SYMBOL_ON="🔛"
YAFP_SYMBOL_END="🔚"
YAFP_SYMBOL_SOON="🔜"

YAFP_SYMBOL_CMD="🚀"
YAFP_SYMBOL_OK="✅"
YAFP_SYMBOL_WARN="⚠️"
YAFP_SYMBOL_ERROR="❌"
YAFP_SYMBOL_ARROW="→"
YAFP_SYMBOL_MORNING="🌅"
YAFP_SYMBOL_AFTERNOON="🌇"
YAFP_SYMBOL_NIGHT="🌃"

YAFP_SYMBOL_GIT_EMOJI=""
YAFP_SYMBOL_GIT_REPO="💾"
YAFP_SYMBOL_GIT_DIR="💻"
YAFP_SYMBOL_GIT_SEP="ᚼ"
YAFP_SYMBOL_REMOTE="⚡"
YAFP_SYMBOL_LOCAL="⇣"
YAFP_SYMBOL_GIT_DELETE_EMOJI="🗑️"
YAFP_SYMBOL_GIT_DELETE="-"
YAFP_SYMBOL_GIT_CHANGE_EMOJI="📝"
YAFP_SYMBOL_GIT_CHANGE="±"
YAFP_SYMBOL_GIT_NEW_EMOJI="🆕"
YAFP_SYMBOL_GIT_NEW="+"


YAFP_SYMBOL_VENV_EMOJI="🐍"


# Theme build
theme_build() {
    cNormal="$(theme_color \
        "$YAFP_COLOR_NORMAL_BG" \
        "$YAFP_COLOR_NORMAL_FG")"

    cSeparator="$(theme_color \
        "$YAFP_COLOR_SEPARATOR_BG" \
        "$YAFP_COLOR_SEPARATOR_FG")"

    cDir="$(theme_color \
        "$YAFP_COLOR_DIR_BG" \
        "$YAFP_COLOR_DIR_FG")"

    cTimestamp="$(theme_color \
        "$YAFP_COLOR_TIMESTAMP_BG" \
        "$YAFP_COLOR_TIMESTAMP_FG")"

    cStatusOk="$(theme_color \
        "$YAFP_COLOR_STATUS_OK_BG" \
        "$YAFP_COLOR_STATUS_OK_FG")"

    cStatusWarning="$(theme_color \
        "$YAFP_COLOR_WARN_ICON_BG" \
        "$YAFP_COLOR_WARN_ICON_FG")"

    cStatusError="$(theme_color \
        "$YAFP_COLOR_STATUS_ERROR_BG" \
        "$YAFP_COLOR_STATUS_ERROR_FG" \
        "$YAFP_COLOR_STATUS_ERROR_ATTRS")"

    cStatusNext="$(theme_color \
        "$YAFP_COLOR_STATUS_NEXT_BG" \
        "$YAFP_COLOR_STATUS_NEXT_FG")"

    cVenv="$(theme_color \
        "$YAFP_COLOR_VENV_BG" \
        "$YAFP_COLOR_VENV_FG")"

    cGit="$(theme_color \
        "$YAFP_COLOR_GIT_BG" \
        "$YAFP_COLOR_GIT_FG")"

    cRepo="$(theme_color \
        "$YAFP_COLOR_REPO_BG" \
        "$YAFP_COLOR_REPO_FG")"

    cCmdOk="$(theme_color \
        "$YAFP_COLOR_CMD_OK_BG" \
        "$YAFP_COLOR_CMD_OK_FG" \
        "$YAFP_COLOR_CMD_OK_ATTRS")"

    cCmdError="$(theme_color \
        "$YAFP_COLOR_CMD_ERROR_BG" \
        "$YAFP_COLOR_CMD_ERROR_FG" \
        "$YAFP_COLOR_CMD_ERROR_ATTRS")"


    cOkIcon="$(theme_color \
        "$YAFP_COLOR_OK_ICON_BG" \
        "$YAFP_COLOR_OK_ICON_FG")"

    cWarnIcon="$(theme_color \
        "$YAFP_COLOR_WARN_ICON_BG" \
        "$YAFP_COLOR_WARN_ICON_FG")"

    cGitDelete="$(theme_color \
        "$YAFP_COLOR_GIT_DELETE_BG" \
        "$YAFP_COLOR_GIT_DELETE_FG" \
        "$YAFP_COLOR_GIT_DELETE_ATTRS")"

    cGitChange="$(theme_color \
        "$YAFP_COLOR_GIT_CHANGE_BG" \
        "$YAFP_COLOR_GIT_CHANGE_FG" \
        "$YAFP_COLOR_GIT_CHANGE_ATTRS")"

    cGitNew="$(theme_color \
        "$YAFP_COLOR_GIT_NEW_BG" \
        "$YAFP_COLOR_GIT_NEW_FG" \
        "$YAFP_COLOR_GIT_NEW_ATTRS")"

    cClient="$(theme_color \
        "$YAFP_COLOR_CLIENT_BG" \
        "$YAFP_COLOR_CLIENT_FG")"

    cCountry="$(theme_color \
        "$YAFP_COLOR_COUNTRY_BG" \
        "$YAFP_COLOR_COUNTRY_FG")"

    cGitBranch="$(theme_color \
        "$YAFP_COLOR_GIT_BRANCH_BG" \
        "$YAFP_COLOR_GIT_BRANCH_FG")"

    cExit=$cStatusError

    cReset="\e[0m"
    cClearLine="\e[K"
    cFullReset="${cReset}$cClearLine"
}

theme_reset_all() {
    printf '%s' "\[\e[0m\]"
}

theme_color() {
    # theme_reset_all
    themeColor "$1" "$2" "$3"
}


theme_ps1_color() {
    printf '%s' "$(ps1_wrap "$(themeColor "$1" "$2" "$3")")"
}


theme_reset() {
    themeColor "$YAFP_COLOR_NORMAL_BG" "$YAFP_COLOR_NORMAL_FG"
}


theme_ps1_reset() {
    printf '%s' "$(ps1_wrap "$(theme_reset)")"
}


theme_ps1_user_color() {
    if [ "$yafp_ctx_is_root" = "1" ]; then
        themeColor "$YAFP_COLOR_ROOT_BG" \
                   "$YAFP_COLOR_ROOT_FG"
    else
        themeColor "$YAFP_COLOR_USER_BG" \
                   "$YAFP_COLOR_USER_FG"
    fi
}


theme_ps1_host_color() {
    if [ "$yafp_ctx_is_dev" = "1" ]; then
        themeColor "$YAFP_COLOR_HOST_DEV_BG" \
                   "$YAFP_COLOR_HOST_DEV_FG"
    else
        themeColor "$YAFP_COLOR_HOST_PRO_BG" \
                   "$YAFP_COLOR_HOST_PRO_FG"
    fi
}


theme_ps1_prompt_color() {
    if [ "$yafp_ctx_is_root" = "1" ]; then
        themeColor "$YAFP_COLOR_PROMPT_ROOT_BG" \
            "$YAFP_COLOR_PROMPT_ROOT_FG"
    else
        themeColor "$YAFP_COLOR_PROMPT_USER_BG" \
            "$YAFP_COLOR_PROMPT_USER_FG"
    fi
}


yafp_timer_backend_init() {
    if [ -n "${EPOCHREALTIME:-}" ]; then
        YAFP_TIMER_BACKEND="EPOCHREALTIME"
    elif command -v python3 >/dev/null 2>&1; then
        YAFP_TIMER_BACKEND="python3"
    elif command -v perl >/dev/null 2>&1; then
        YAFP_TIMER_BACKEND="perl"
    else
        YAFP_TIMER_BACKEND="date"
    fi
}


theme_render_git_counts() {
    local out=""
    local cGitDeletePS1
    local cGitChangePS1
    local cGitNewPS1
    local cNormalPS1

    cGitDeletePS1="$(ps1_wrap "$cGitDelete")"
    cGitChangePS1="$(ps1_wrap "$cGitChange")"
    cGitNewPS1="$(ps1_wrap "$cGitNew")"
    cNormalPS1="$(theme_ps1_reset)"

    if [ "$yafp_ctx_git_delete" -gt 0 ]; then
        out+="$cGitDeletePS1"
        out+="$YAFP_SYMBOL_GIT_DELETE_EMOJI"
        out+="$YAFP_SYMBOL_GIT_DELETE"
        out+="${yafp_ctx_git_delete}${cNormalPS1}"
    fi

    if [ "$yafp_ctx_git_change" -gt 0 ]; then
        out+="$cGitChangePS1"
        out+="$YAFP_SYMBOL_GIT_CHANGE_EMOJI"
        out+="$YAFP_SYMBOL_GIT_CHANGE"
        out+="${yafp_ctx_git_change}${cNormalPS1}"
    fi

    if [ "$yafp_ctx_git_new" -gt 0 ]; then
        out+="$cGitNewPS1"
        out+="$YAFP_SYMBOL_GIT_NEW_EMOJI"
        out+="$YAFP_SYMBOL_GIT_NEW"
        out+="${yafp_ctx_git_new}${cNormalPS1}"
    fi

    printf '%s' "$out"
}


theme_apply_terminal_title() {
    local title_text

    title_text="${title:-}"
    PS1="${PS1}\[\e]0;[\\u@\\h:\\w]${title_text}\a\]"
}


theme_ps1_prompt_mark() {
    local cPromptPS1
    local cNormalPS1

    cPromptPS1="$(ps1_wrap "$(theme_ps1_prompt_color)")"
    cNormalPS1="$(theme_ps1_reset)"

    printf '%s\\$%s' "$cPromptPS1" "$cNormalPS1"
}


theme_render_main_block() {
    theme_render_general_block

    if [ "$yafp_ctx_git_has_repo" = "1" ]; then
        theme_render_git_block
    fi
    
    if [ -n "$yafp_venv_segment" ]; then
        theme_render_venv_block
    fi

    theme_render_timestamp

    if [ "$yafp_ctx_show_status" = "1" ]; then
        if [ "$yafp_ctx_exit" == "0" ]; then
            theme_render_status_ok_block
        else
            theme_render_status_error_block
        fi
    fi
}

# -o-

yafp_timer_backend_emoji() {
    case "$YAFP_TIMER_BACKEND" in
        EPOCHREALTIME) printf "⚡" ;;
        python3)       printf "🐍" ;;
        perl)          printf "🧬" ;;
        date)          printf "📅" ;;
        *)             printf "❓" ;;
    esac
}


yafp_now_ms() {
    [[ "${YAFP_DEVEL:-0}" -ne 0 ]] || return
    local __outvar="$1"
    local __value

    case "${YAFP_TIMER_BACKEND:-}" in
        EPOCHREALTIME)
            local t="${EPOCHREALTIME/,/.}"
            local sec="${t%.*}"
            local frac="${t#*.}"
            [ "$sec" = "$t" ] && sec="$t" && frac="000"
            frac="${frac:0:3}"
            while [ ${#frac} -lt 3 ]; do
                frac="${frac}0"
            done
            __value="$(printf '%s%03d' "$sec" "$((10#$frac))")"
            ;;
        python3)
            __value="$(python3 -c \
                'import time; print(int(time.time() * 1000))')"
            ;;
        perl)
            __value="$(perl -MTime::HiRes=time -e \
                'printf("%.0f\n", time() * 1000)')"
            ;;
        *)
            __value="$(date +%s)000"
            ;;
    esac

    printf -v "$__outvar" '%s' "$__value"
}


getColorIndex() {
    declare -a colorNames=(
        black red green yellow blue magenta cyan white
    )
    declare -a colorNAMES=(
        BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE
    )

    local colorName
    local index

    colorName="$1"

    for index in "${!colorNames[@]}"; do
        if [[ "${colorNames[$index]}" = "${colorName}" ]]; then
            echo "${index}"
            return 0
        fi

        if [[ "${colorNAMES[$index]}" = "${colorName}" ]]; then
            echo $((index + 8))
            return 0
        fi
    done

    echo "0"
    return 0
}


setColor() {
    local colorBG
    local colorFG
    local indexBG
    local indexFG
    local normal
    local codes
    local atributo

    colorBG="$1"
    colorFG="$2"

    indexFG=$(getColorIndex "$colorFG")

    normal=1
    codes=""

    shift 2

    for atributo in "$@"; do
        if [ "$atributo" = "bold" ]; then
            codes="${codes}$(tput bold)"
            normal=0
        fi

        if [ "$atributo" = "blink" ]; then
            codes="${codes}$(tput blink)"
            normal=0
        fi
    done

    if [ "$normal" = "1" ]; then
        codes="${codes}$(tput sgr0)"
    fi

    if [ "$colorBG" != "transparent" ]; then
        indexBG=$(getColorIndex "$colorBG")
        codes="${codes}$(tput setab "$indexBG")"
    fi

    codes="${codes}$(tput setaf "$indexFG")"

    printf "%s" "$codes"
}


themeColor() {
    local bg
    local fg
    local attrs

    bg="$1"
    fg="$2"
    attrs="$3"

    if [ -n "$attrs" ]; then
        # shellcheck disable=SC2086
        setColor "$bg" "$fg" $attrs
    else
        setColor "$bg" "$fg"
    fi
}


load_theme() {
    local theme_file

    yafp_timer_backend_init
    YAFP_TIMER_BACKEND_EMOJI="$(yafp_timer_backend_emoji)"

    theme_file="${SCRIPT_DIR}/themes/${YAFP_THEME}.bash"

    if [ ! -f "$theme_file" ]; then
        theme_file="${SCRIPT_DIR}/themes/default.bash"
    fi

    [ -f "$theme_file" ] || return 1
    . "$theme_file"
}


ps1_wrap() {
    printf '\\[%s\\]' "$1"
}


set_SERVER_OS_EMOJI() {
    local platform
    local os_id
    local emoji

    platform=$(uname -s)
    os_id=""
    emoji="❓"

    case "$platform" in
        Darwin)
            emoji="🍎"
            ;;
        Linux)
            if [ -r /etc/os-release ]; then
                while IFS='=' read -r key value; do
                    if [ "$key" = "ID" ]; then
                        os_id=${value#\"}
                        os_id=${os_id%\"}
                        break
                    fi
                done < /etc/os-release
            fi

            case "$os_id" in
                kali)
                    emoji="㉿"
                    ;;
                ubuntu|debian)
                    emoji=""
                    ;;
                *)
                    emoji="🐧"
                    ;;
            esac
            ;;
        MINGW*|MSYS*|CYGWIN*)
            emoji="🪟"
            ;;
        *)
            emoji="❓"
            ;;
    esac

    SERVER_OS_EMOJI="$emoji"
}


set_CLIENT_OS_EMOJI() {
    local emoji

    case "$CLIENT_OS" in
        WINDOWS) emoji="🪟" ;;
        MACOS)   emoji="🍎" ;;
        LINUX)   emoji="🐧" ;;
        WSL2)    emoji="🐧▶🪟" ;;
        CYGWIN)  emoji="⬘▶🪟" ;;
        GITBASH) emoji="⬙▶🪟" ;;
        *)       emoji="❓" ;;
    esac

    CLIENT_OS_EMOJI="$emoji"
}


set_YAFP_USER() {
    if [ "${EUID:-$(id -u)}" -eq 0 ]; then
        YAFP_USER_TYPE="root"
        YAFP_USER_ICON="💀"
        YAFP_USER_PROMPT_SYMBOL="#"
    else
        YAFP_USER_TYPE="user"
        YAFP_USER_ICON="👤"
        YAFP_USER_PROMPT_SYMBOL="$"
    fi
}


set_YAFP_GEOIP_COUNTRY() {
    local ip
    local country

    if [[ -n "$SSH_CLIENT" && -z "$YAFP_GEOIP_COUNTRY" ]]; then
        ip="${SSH_CLIENT%% *}"

        if command -v geoiplookup >/dev/null 2>&1; then
            country=$(geoiplookup "$ip" 2>/dev/null \
                | awk -F': ' '/Country Edition/ {print $2}' \
                | awk -F',' '{print $1}' \
                | head -n1 \
                | tr -d ' ')

            [[ -n "$country" ]] && export YAFP_GEOIP_COUNTRY="$country"
        fi
    fi
}


set_YAFP_CLOCK_EMOJI() {
    [[ "${YAFP_CLOCK:-0}" -ne 0 ]] || return
    local h
    local m
    local base
    local half

    h=$(date +%I)
    m=$(date +%M)

    h=${h#0}
    m=${m#0}
    m=${m:-0}

    case "$h" in
        1)  base="🕐"; half="🕜" ;;
        2)  base="🕑"; half="🕝" ;;
        3)  base="🕒"; half="🕞" ;;
        4)  base="🕓"; half="🕟" ;;
        5)  base="🕔"; half="🕠" ;;
        6)  base="🕕"; half="🕡" ;;
        7)  base="🕖"; half="🕢" ;;
        8)  base="🕗"; half="🕣" ;;
        9)  base="🕘"; half="🕤" ;;
        10) base="🕙"; half="🕥" ;;
        11) base="🕚"; half="🕦" ;;
        12) base="🕛"; half="🕧" ;;
    esac

    if [ "$m" -ge 30 ]; then
        export YAFP_CLOCK_EMOJI="$half"
    else
        export YAFP_CLOCK_EMOJI="$base"
    fi
}


load_vars() {
    set_SERVER_OS_EMOJI
    set_CLIENT_OS_EMOJI
    set_YAFP_USER
    set_YAFP_GEOIP_COUNTRY
    set_YAFP_CLOCK_EMOJI
}


yaft_general_context() {
    yafp_now_ms t_general_begin
    local last_exit=$1
    local last_command="$previous_command"

    yafp_ctx_exit="$last_exit"
    yafp_ctx_user="$USER"
    yafp_ctx_host="$HOSTNAME"
    yafp_ctx_pwd="$PWD"
    yafp_ctx_timestamp="$(date +'%Y-%m-%d %H:%M:%S')"


    yafp_ctx_is_root=0
    yafp_ctx_is_dev=1
    yafp_ctx_show_status=1

    if [ "$yafp_ctx_user" = "root" ]; then
        yafp_ctx_is_root=1
    fi

    if [ "${HOSTNAME:0:${#PRO}}" = "$PRO" ]; then
        yafp_ctx_is_dev=0
    fi

    yafp_now_ms t_general_end
}


yafp_git_check() {
    if [[ "$PWD" != "$YAFP_GIT_LAST_PWD" ]]; then
        if [[ -d .git ]]; then
            YAFP_GIT_INSIDE=1
        else
            # fallback real
            git rev-parse --is-inside-work-tree \
                >/dev/null 2>&1 && YAFP_GIT_INSIDE=1 || YAFP_GIT_INSIDE=0
        fi
        YAFP_GIT_LAST_PWD="$PWD"
    fi
}


yafp_git_context() {
    yafp_now_ms t_git_begin
    if [ "${YAFP_REPOS:-0}" -eq 0 ]; then
        yafp_now_ms t_git_end
        return
    fi

    yafp_git_segment=""
    yafp_ctx_git_has_repo=0
    yafp_git_check

    if [ "${YAFP_GIT_INSIDE}" -eq 0 ]; then
        yafp_now_ms t_git_end
        return 0
    fi

    local git_repo_url
    local gitstatus
    local line

    yafp_ctx_git_repo=""
    yafp_ctx_git_branch=""
    yafp_ctx_git_remote=""
    yafp_ctx_git_last_ts=""
    yafp_ctx_git_new=0
    yafp_ctx_git_change=0
    yafp_ctx_git_delete=0

    yafp_ctx_git_has_repo=1

    git_repo_url=$(git remote get-url origin 2>/dev/null)

    if [ -z "$git_repo_url" ]; then
        yafp_ctx_git_repo=$(
            basename "$(git rev-parse --show-toplevel 2>/dev/null)"
        )
        yafp_ctx_git_remote="local"
    else
        yafp_ctx_git_repo=$(basename -s .git "$git_repo_url")
        yafp_ctx_git_remote="remote"
    fi

    yafp_ctx_git_branch="$(git symbolic-ref --short HEAD 2>/dev/null)"
    if [ -z "$yafp_ctx_git_branch" ]; then
        yafp_ctx_git_branch="unnamed"
    fi

    yafp_ctx_git_last_ts=$(
        git log -1 --stat --date=format:'%Y-%m-%d %H:%M:%S' 2>/dev/null \
        | grep "^Date:" \
        | cut -d":" -f2-
    )
    yafp_ctx_git_last_ts="$(echo $yafp_ctx_git_last_ts)"

    gitstatus="$(git status --porcelain 2>/dev/null)"

    while IFS= read -r line; do
        [[ $line =~ ^[[:space:]]D ]] && \
            yafp_ctx_git_delete=$((yafp_ctx_git_delete + 1))
        [[ $line =~ ^[[:space:]]M ]] && \
            yafp_ctx_git_change=$((yafp_ctx_git_change + 1))
        [[ $line =~ ^\?\? ]] && \
            yafp_ctx_git_new=$((yafp_ctx_git_new + 1))
    done <<< "$gitstatus"
    yafp_now_ms t_git_end
}


yafp_venv_context() {
    yafp_now_ms t_venv_begin
    yafp_venv_segment=""

    if [ "${YAFP_PVENV:-0}" -eq 0 ]; then
        yafp_now_ms t_venv_end
        return 0
    fi

    if [[ -n "${VIRTUAL_ENV:-}" ]]; then
        local venv_name
        venv_name="${VIRTUAL_ENV##*/}"
        yafp_venv_segment="${venv_name}"
    fi
    yafp_now_ms t_venv_end
}


yafp_err_context() {
    yafp_now_ms t_err_begin
    local last_exit="$1"
    yafp_ctx_exit=$last_exit
    yafp_err_segment=""

    if [ "${YAFP_ERROR:-0}" -eq 0 ]; then
        yafp_now_ms t_err_end
        return
    fi

    # Previous command (Bash history)
    local previous_command
    previous_command="$(history 1 | sed 's/^ *[0-9]\+ *//')"

    # Escape '%' to avoid prompt expansion issues
    previous_command="${previous_command//%/%%}"

    # Optional: truncate long commands (para no romper el prompt)
    local max_len=60
    if (( ${#previous_command} > max_len )); then
        previous_command="${previous_command:0:max_len}..."
    fi

    yafp_ctx_previous_command="$previous_command"
    yafp_ctx_previous_timestamp="$previous_timestamp"

    previous_timestamp="$yafp_ctx_timestamp"

    if [ -z "$yafp_ctx_previous_command" ]; then
        yafp_ctx_exit=0
    fi

    case "$yafp_ctx_previous_command" in
        theme_*|yafp_*|ps1k)
            yafp_ctx_exit=0
            ;;
    esac

    # echo $yafp_ctx_timestamp $yafp_ctx_previous_command >> /tmp/yafp_ctx_previous_command.txt

    if [ "${yafp_ctx_previous_command:0:4}" = "PS1=" ]; then
        yafp_ctx_exit=0
        yafp_ctx_previous_command=""
    fi

    case "$yafp_ctx_previous_command" in
        *%*)
            yafp_ctx_previous_command=${yafp_ctx_previous_command//%/%%}
            ;;
    esac

    # Build segment
    yafp_err_segment="${previous_command} ✖ ${yafp_ctx_exit}"
    yafp_now_ms t_err_end
}


yafp_dev_segment() {
    local t_all=$((t_all_end - t_all_begin))
    local t_general=$((t_general_end - t_general_begin))
    local t_git=$((t_git_end - t_git_begin))
    local t_venv=$((t_venv_end - t_venv_begin)) 
    local t_err=$((t_err_end - t_err_begin))
    local t_timer=$((t_all - t_general - t_git - t_venv - t_err))
    local icon=""
    local cSpeed=""

    # t_all=100
    if (( t_all < 50 )); then
        icon="🚀"
        cSpeed="$(ps1_wrap "$cStatusOk")"
    elif (( t_all < 200 )); then
        icon="⏱️"
        cSpeed="$(ps1_wrap "$cStatusWarning")"
    else
        icon="🐢"
        cSpeed="$(ps1_wrap "$cStatusError")"
    fi

    local parts=(
        "${cSpeed}$icon"
        "${t_all}ms"
        "$cSeparator | "
        "${cSpeed}⚙️$t_general "
        "🌱$t_git "
        "🐍$t_venv "
        "❌$t_err "
        "$YAFP_TIMER_BACKEND_EMOJI"
        "$t_timer"
        "\[\e[0m\e[K\]\n"
    )

    printf '%s' "${parts[@]}"
}


yafp_validate_ps1_strict() {
    local ps1="$1"
    local errors=0

    # 1. Balance \[ \]
    local open close
    open=$(grep -o '\\\[' <<< "$ps1" | wc -l)
    close=$(grep -o '\\\]' <<< "$ps1" | wc -l)

    if (( open != close )); then
        echo "❌ Error: \\[ ($open) != \\] ($close)"
        ((errors++))
    fi

    # 2. ANSI fuera de bloques \[ \]
    local cleaned
    cleaned=$(sed 's/\\\[[^\\\]]*\\\]//g' <<< "$ps1")

    if grep -q $'\033\[' <<< "$cleaned"; then
        echo "⚠️ ANSI fuera de \\[ \\]"
        ((errors++))
    fi

    # 3. Reset final
    if ! grep -q $'\033\[0m' <<< "$ps1"; then
        echo "⚠️ Falta reset global \\033[0m"
    fi

    # 4. Resultado
    if (( errors == 0 )); then
        echo "✅ PS1 limpio como código en revisión de tesis"
        return 0
    else
        echo "💀 PS1 sospechoso… revisa antes de que rompa el cursor"
        return 1
    fi
}


yafp_prompt_command() {
    local last_exit=$? # Capture the exit code at the very beginning
    yafp_now_ms t_all_begin

    yaft_general_context "$last_exit"
    yafp_git_context
    yafp_venv_context
    yafp_err_context "$last_exit"

    if [ "$YAFP_TITLE" = "1" ]; then
        title="[${yafp_ctx_previous_command} => exit code ${yafp_ctx_exit}]"
        theme_apply_terminal_title
    fi

    # ps1k
    yafp_now_ms t_all_end

    ps1=$(theme_render_ps1)
    PS1=$ps1
    #yafp_validate_ps1_strict $PS1
}


SCRIPT_DIR=$(
    cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd
)

cfg="${SCRIPT_DIR}/yafp-cfg.bash"

[ -f "$cfg" ] || return 1
. "$cfg"

load_vars
load_theme || return 1
theme_build

previous_command=""
this_command=""
previous_timestamp=""

trap 'previous_command=$this_command; this_command=$BASH_COMMAND' DEBUG
PROMPT_COMMAND=yafp_prompt_command
export PROMPT_COMMAND