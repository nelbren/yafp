#!/bin/bash
#
# themes/minimal.bash
#

YAFP_THEME_NAME="minimal"
YAFP_THEME_VERSION="2.1"

# --------------------------------------------------
# Base colors
# --------------------------------------------------
YAFP_COLOR_NORMAL_BG="black"
YAFP_COLOR_NORMAL_FG="white"

YAFP_COLOR_DIR_BG="yellow"
YAFP_COLOR_DIR_FG="black"

YAFP_COLOR_TIMESTAMP_BG="white"
YAFP_COLOR_TIMESTAMP_FG="black"

YAFP_COLOR_STATUS_OK_BG="green"
YAFP_COLOR_STATUS_OK_FG="black"

YAFP_COLOR_STATUS_ERROR_BG="red"
YAFP_COLOR_STATUS_ERROR_FG="black"

YAFP_COLOR_STATUS_NEXT_BG="cyan"
YAFP_COLOR_STATUS_NEXT_FG="black"

YAFP_COLOR_ERROR_BG="red"
YAFP_COLOR_ERROR_FG="yellow"
YAFP_COLOR_ERROR_ATTRS="bold blink"

YAFP_COLOR_USER_BG="cyan"
YAFP_COLOR_USER_FG="black"

YAFP_COLOR_ROOT_BG="red"
YAFP_COLOR_ROOT_FG="black"

YAFP_COLOR_HOST_DEV_BG="green"
YAFP_COLOR_HOST_DEV_FG="black"

YAFP_COLOR_HOST_PRO_BG="magenta"
YAFP_COLOR_HOST_PRO_FG="black"

YAFP_COLOR_PROMPT_USER_BG="black"
YAFP_COLOR_PROMPT_USER_FG="green"

YAFP_COLOR_PROMPT_ROOT_BG="black"
YAFP_COLOR_PROMPT_ROOT_FG="red"

YAFP_COLOR_VENV_BG="blue"
YAFP_COLOR_VENV_FG="white"

YAFP_COLOR_GIT_BG="white"
YAFP_COLOR_GIT_FG="black"

YAFP_COLOR_REPO_BG="yellow"
YAFP_COLOR_REPO_FG="black"

# Command start/end blocks
YAFP_COLOR_EDGE_BG="black"
YAFP_COLOR_EDGE_FG="white"

YAFP_COLOR_EDGE_ICON_BG="green"
YAFP_COLOR_EDGE_ICON_FG="magenta"

YAFP_COLOR_EDGE_LABEL_BG="green"
YAFP_COLOR_EDGE_LABEL_FG="magenta"

# Executed command block
YAFP_COLOR_CMD_BG="green"
YAFP_COLOR_CMD_FG="black"

# Check / warning blocks
YAFP_COLOR_OK_ICON_BG="green"
YAFP_COLOR_OK_ICON_FG="white"

YAFP_COLOR_WARN_ICON_BG="red"
YAFP_COLOR_WARN_ICON_FG="white"

# Git counters
YAFP_COLOR_GIT_DELETE_BG="red"
YAFP_COLOR_GIT_DELETE_FG="black"

YAFP_COLOR_GIT_CHANGE_BG="yellow"
YAFP_COLOR_GIT_CHANGE_FG="black"

YAFP_COLOR_GIT_NEW_BG="cyan"
YAFP_COLOR_GIT_NEW_FG="black"

# Extra blocks
YAFP_COLOR_CLIENT_BG="white"
YAFP_COLOR_CLIENT_FG="black"

YAFP_COLOR_COUNTRY_BG="cyan"
YAFP_COLOR_COUNTRY_FG="black"

YAFP_COLOR_GIT_BRANCH_BG="blue"
YAFP_COLOR_GIT_BRANCH_FG="white"

YAFP_COLOR_EXIT_BG="red"
YAFP_COLOR_EXIT_FG="white"

# --------------------------------------------------
# Symbols and labels
# --------------------------------------------------
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

YAFP_SYMBOL_GIT_REPO="💾"
YAFP_SYMBOL_GIT_DIR="💻"
YAFP_SYMBOL_GIT_SEP="ᚼ"
YAFP_SYMBOL_REMOTE="⚡"
YAFP_SYMBOL_LOCAL="⇣"

YAFP_SYMBOL_GIT_DELETE="-"
YAFP_SYMBOL_GIT_CHANGE="±"
YAFP_SYMBOL_GIT_NEW="+"

# --------------------------------------------------
# Helpers
# --------------------------------------------------
function ps1_wrap() {
    printf '\\[%s\\]' "$1"
}


function theme_color() {
    ThemeColor "$1" "$2" "$3"
}


function theme_ps1_color() {
    printf '%s' "$(ps1_wrap "$(ThemeColor "$1" "$2" "$3")")"
}


function theme_reset() {
    ThemeColor "$YAFP_COLOR_NORMAL_BG" "$YAFP_COLOR_NORMAL_FG"
}


function theme_ps1_reset() {
    printf '%s' "$(ps1_wrap "$(theme_reset)")"
}

# --------------------------------------------------
# Libs
# --------------------------------------------------
function set_server_os() {
    local platform

    platform=$(uname -s)
    case "$platform" in
        Darwin)
            export SERVER_OS_EMOJI="🍎"
            ;;
        Linux)
            if [ -r /etc/debian_version ]; then
                export SERVER_OS_EMOJI=""
            else
                export SERVER_OS_EMOJI="🐧"
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*)
            export SERVER_OS_EMOJI="🪟"
            ;;
        *)
            export SERVER_OS_EMOJI="❓"
            ;;
    esac
}


function set_client_os() {
    case "$CLIENT_OS" in
        WINDOWS) export CLIENT_OS_EMOJI="🪟" ;;
        MACOS)   export CLIENT_OS_EMOJI="🍎" ;;
        LINUX)   export CLIENT_OS_EMOJI="🐧" ;;
        WSL2)    export CLIENT_OS_EMOJI="🐧▶🪟" ;;
        CYGWIN)  export CLIENT_OS_EMOJI="⬘▶🪟" ;;
        GITBASH) export CLIENT_OS_EMOJI="⬙▶🪟" ;;
        *)       export CLIENT_OS_EMOJI="" ;;
    esac
}


function set_user_context() {
    if [ "${EUID:-$(id -u)}" -eq 0 ]; then
        export OMP_USER_TYPE="root"
        export OMP_USER_ICON="💀"
        export OMP_PROMPT_SYMBOL="#"
    else
        export OMP_USER_TYPE="user"
        export OMP_USER_ICON="👤"
        export OMP_PROMPT_SYMBOL="$"
    fi
}


function get_ssh_location() {
    local ip
    local country

    if [[ -n "$SSH_CLIENT" && -z "$OMP_GEOIP_COUNTRY" ]]; then
        ip="${SSH_CLIENT%% *}"

        if command -v geoiplookup >/dev/null 2>&1; then
            country=$(geoiplookup "$ip" 2>/dev/null \
                | awk -F': ' '/Country Edition/ {print $2}' \
                | awk -F',' '{print $1}' \
                | head -n1 \
                | tr -d ' ')

            [[ -n "$country" ]] && export OMP_GEOIP_COUNTRY="$country"
        fi
    fi
}


function set_clock_emoji() {
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
        export OMP_CLOCK_EMOJI="$half"
    else
        export OMP_CLOCK_EMOJI="$base"
    fi
}


function set_minimal_functions() {
    set_server_os
    set_client_os
    set_user_context
    get_ssh_location
    set_clock_emoji
}

# --------------------------------------------------
# Theme build
# --------------------------------------------------
function theme_build() {
    cNormal="$(theme_color \
        "$YAFP_COLOR_NORMAL_BG" \
        "$YAFP_COLOR_NORMAL_FG")"

    cDir="$(theme_color \
        "$YAFP_COLOR_DIR_BG" \
        "$YAFP_COLOR_DIR_FG")"

    cTimestamp="$(theme_color \
        "$YAFP_COLOR_TIMESTAMP_BG" \
        "$YAFP_COLOR_TIMESTAMP_FG")"

    cStatusOk="$(theme_color \
        "$YAFP_COLOR_STATUS_OK_BG" \
        "$YAFP_COLOR_STATUS_OK_FG")"

    cStatusError="$(theme_color \
        "$YAFP_COLOR_STATUS_ERROR_BG" \
        "$YAFP_COLOR_STATUS_ERROR_FG")"

    cStatusNext="$(theme_color \
        "$YAFP_COLOR_STATUS_NEXT_BG" \
        "$YAFP_COLOR_STATUS_NEXT_FG")"

    cError="$(theme_color \
        "$YAFP_COLOR_ERROR_BG" \
        "$YAFP_COLOR_ERROR_FG" \
        "$YAFP_COLOR_ERROR_ATTRS")"

    cVenv="$(theme_color \
        "$YAFP_COLOR_VENV_BG" \
        "$YAFP_COLOR_VENV_FG")"

    cGit="$(theme_color \
        "$YAFP_COLOR_GIT_BG" \
        "$YAFP_COLOR_GIT_FG")"

    cRepo="$(theme_color \
        "$YAFP_COLOR_REPO_BG" \
        "$YAFP_COLOR_REPO_FG")"

    cEdge="$(theme_color \
        "$YAFP_COLOR_EDGE_BG" \
        "$YAFP_COLOR_EDGE_FG")"

    cEdgeIcon="$(theme_color \
        "$YAFP_COLOR_EDGE_ICON_BG" \
        "$YAFP_COLOR_EDGE_ICON_FG")"

    cEdgeLabel="$(theme_color \
        "$YAFP_COLOR_EDGE_LABEL_BG" \
        "$YAFP_COLOR_EDGE_LABEL_FG")"

    cCmd="$(theme_color \
        "$YAFP_COLOR_CMD_BG" \
        "$YAFP_COLOR_CMD_FG")"

    cOkIcon="$(theme_color \
        "$YAFP_COLOR_OK_ICON_BG" \
        "$YAFP_COLOR_OK_ICON_FG")"

    cWarnIcon="$(theme_color \
        "$YAFP_COLOR_WARN_ICON_BG" \
        "$YAFP_COLOR_WARN_ICON_FG")"

    cGitDelete="$(theme_color \
        "$YAFP_COLOR_GIT_DELETE_BG" \
        "$YAFP_COLOR_GIT_DELETE_FG")"

    cGitChange="$(theme_color \
        "$YAFP_COLOR_GIT_CHANGE_BG" \
        "$YAFP_COLOR_GIT_CHANGE_FG")"

    cGitNew="$(theme_color \
        "$YAFP_COLOR_GIT_NEW_BG" \
        "$YAFP_COLOR_GIT_NEW_FG")"

    cClient="$(theme_color \
        "$YAFP_COLOR_CLIENT_BG" \
        "$YAFP_COLOR_CLIENT_FG")"

    cCountry="$(theme_color \
        "$YAFP_COLOR_COUNTRY_BG" \
        "$YAFP_COLOR_COUNTRY_FG")"

    cGitBranch="$(theme_color \
        "$YAFP_COLOR_GIT_BRANCH_BG" \
        "$YAFP_COLOR_GIT_BRANCH_FG")"

    cExit="$(theme_color \
        "$YAFP_COLOR_EXIT_BG" \
        "$YAFP_COLOR_EXIT_FG")"

    cReset="\e[0m"
    cClearLine="\e[K"

    set_minimal_functions
}


function theme_ps1_user_color() {
    if [ "$yafp_ctx_is_root" = "1" ]; then
        ThemeColor "$YAFP_COLOR_ROOT_BG" "$YAFP_COLOR_ROOT_FG"
    else
        ThemeColor "$YAFP_COLOR_USER_BG" "$YAFP_COLOR_USER_FG"
    fi
}


function theme_ps1_host_color() {
    if [ "$yafp_ctx_is_dev" = "1" ]; then
        ThemeColor "$YAFP_COLOR_HOST_DEV_BG" "$YAFP_COLOR_HOST_DEV_FG"
    else
        ThemeColor "$YAFP_COLOR_HOST_PRO_BG" "$YAFP_COLOR_HOST_PRO_FG"
    fi
}


function theme_ps1_prompt_color() {
    if [ "$yafp_ctx_is_root" = "1" ]; then
        ThemeColor "$YAFP_COLOR_PROMPT_ROOT_BG" \
            "$YAFP_COLOR_PROMPT_ROOT_FG"
    else
        ThemeColor "$YAFP_COLOR_PROMPT_USER_BG" \
            "$YAFP_COLOR_PROMPT_USER_FG"
    fi
}


function theme_ps1_prompt_mark() {
    local cPromptPS1
    local cNormalPS1

    cPromptPS1="$(ps1_wrap "$(theme_ps1_prompt_color)")"
    cNormalPS1="$(theme_ps1_reset)"

    printf '%s\\$%s' "$cPromptPS1" "$cNormalPS1"
}


function theme_render_venv_block() {
    local cVenvPS1
    local cNormalPS1

    [ -n "$yafp_ctx_venv" ] || return

    cVenvPS1="$(ps1_wrap "$cVenv")"
    cNormalPS1="$(theme_ps1_reset)"

    printf '%s[%s]%s' \
        "$cVenvPS1" \
        "$yafp_ctx_venv" \
        "$cNormalPS1"
}


function theme_render_git_counts() {
    local out=""
    local cGitDeletePS1
    local cGitChangePS1
    local cGitNewPS1
    local cNormalPS1

    cGitDeletePS1="$(ps1_wrap "$cGitDelete")"
    cGitChangePS1="$(ps1_wrap "$cGitChange")"
    cGitNewPS1="$(ps1_wrap "$cGitNew")"
    cNormalPS1="$(theme_ps1_reset)"

    [ "$yafp_ctx_git_delete" -gt 0 ] && \
        out="${out}${cGitDeletePS1}🗑️${YAFP_SYMBOL_GIT_DELETE}"\
"${yafp_ctx_git_delete}${cNormalPS1}"

    [ "$yafp_ctx_git_change" -gt 0 ] && \
        out="${out}${cGitChangePS1}📝${YAFP_SYMBOL_GIT_CHANGE}"\
"${yafp_ctx_git_change}${cNormalPS1}"

    [ "$yafp_ctx_git_new" -gt 0 ] && \
        out="${out}${cGitNewPS1}🆕${YAFP_SYMBOL_GIT_NEW}"\
"${yafp_ctx_git_new}${cNormalPS1}"

    printf '%s' "$out"
}


function theme_render_git_block() {
    local remote_symbol
    local counts
    local cGitBranchPS1
    local cNormalPS1

    [ "$yafp_ctx_git_has_repo" = "1" ] || return

    counts="$(theme_render_git_counts)"
    cGitBranchPS1="$(ps1_wrap "$cGitBranch")"
    cNormalPS1="$(theme_ps1_reset)"

    if [ "$yafp_ctx_git_remote" = "remote" ]; then
        remote_symbol="$YAFP_SYMBOL_REMOTE"
    else
        remote_symbol="$YAFP_SYMBOL_LOCAL"
    fi

    printf ' on %s[%s %s%s%s]%s' \
        "$cGitBranchPS1" \
        "$yafp_ctx_git_branch" \
        "$YAFP_SYMBOL_GIT_DIR" \
        "$remote_symbol" \
        "$counts" \
        "$cNormalPS1"
}


function theme_render_status_ok_block() {
    local cmd
    local cStatusOkPS1
    local cOkIconPS1
    local cNormalPS1

    cmd="$yafp_ctx_previous_command"
    cStatusOkPS1="$(ps1_wrap "$cStatusOk")"
    cOkIconPS1="$(ps1_wrap "$cOkIcon")"
    cNormalPS1="$(theme_ps1_reset)"

    printf '%s[%s%s%s%s%s%s]%s' \
        "$cStatusOkPS1" \
        "$YAFP_SYMBOL_END" \
        "$yafp_ctx_timestamp" \
        "$YAFP_SYMBOL_CMD" \
        "$cmd" \
        "$YAFP_SYMBOL_ARROW" \
        "${cOkIconPS1}${YAFP_SYMBOL_OK}" \
        "$cNormalPS1"
}


function theme_render_status_error_block() {
    local cExitPS1
    local cNormalPS1

    cExitPS1="$(ps1_wrap "$cExit")"
    cNormalPS1="$(theme_ps1_reset)"

    printf ' → %s %s%s%s' \
        "$YAFP_SYMBOL_ERROR" \
        "$cExitPS1" \
        "$yafp_ctx_exit" \
        "$cNormalPS1"
}


function theme_render_timestamp_next_block() {
    local cStatusNextPS1
    local cNormalPS1

    cStatusNextPS1="$(ps1_wrap "$cStatusNext")"
    cNormalPS1="$(theme_ps1_reset)"

    printf '%s[%s%s%s]%s' \
        "$cStatusNextPS1" \
        "$YAFP_SYMBOL_SOON" \
        "$yafp_ctx_timestamp" \
        "$day" \
        "$cNormalPS1"
}


function theme_render_info_lines() {
    return
}


function theme_render_main_block() {
    local cUserPS1
    local cHostPS1
    local cNormalPS1
    local cDirPS1
    local cClientPS1
    local cCountryPS1
    local cTimestampPS1
    local emojiClient
    local day
    local hour
    local country_text

    cUserPS1="$(ps1_wrap "$(theme_ps1_user_color)")"
    cHostPS1="$(ps1_wrap "$(theme_ps1_host_color)")"
    cNormalPS1="$(theme_ps1_reset)"
    cDirPS1="$(theme_ps1_color \
        "$YAFP_COLOR_DIR_BG" \
        "$YAFP_COLOR_DIR_FG")"
    cClientPS1="$(ps1_wrap "$cClient")"
    cCountryPS1="$(ps1_wrap "$cCountry")"
    cTimestampPS1="$(ps1_wrap "$cTimestamp")"

    hour=${yafp_ctx_timestamp:11:2}
    if [ "$hour" -gt 6 ] && [ "$hour" -lt 12 ]; then
        day="$YAFP_SYMBOL_MORNING"
    elif [ "$hour" -ge 12 ] && [ "$hour" -lt 18 ]; then
        day="$YAFP_SYMBOL_AFTERNOON"
    else
        day="$YAFP_SYMBOL_NIGHT"
    fi

    if [ -n "$SSH_CLIENT" ]; then
        emojiClient="💻 ${cClientPS1}${CLIENT_OS_EMOJI}${cNormalPS1}"
    else
        emojiClient="🖥️ ${cClientPS1}LOCAL${cNormalPS1}"
    fi

    country_text="${OMP_GEOIP_COUNTRY:---}"

    printf '%s %s %s\\u%s @ %s\\h%s ← %s ◎ %s%s%s ⌂ %s\\w%s' \
        "$SERVER_OS_EMOJI" \
        "$OMP_USER_ICON" \
        "$cUserPS1" \
        "$cNormalPS1" \
        "$cHostPS1" \
        "$cNormalPS1" \
        "$emojiClient" \
        "$cCountryPS1" \
        "$country_text" \
        "$cNormalPS1" \
        "$cDirPS1" \
        "$cNormalPS1"

    if [ "$yafp_ctx_git_has_repo" = "1" ]; then
        theme_render_git_block
    fi

    printf ' %s %s%s%s %s' \
        "$OMP_CLOCK_EMOJI" \
        "$cTimestampPS1" \
        "$yafp_ctx_timestamp" \
        "$cNormalPS1" \
        "$day"

    if [ "$yafp_ctx_show_status" = "1" ] &&
       [ "$yafp_ctx_exit" != "0" ]; then
        theme_render_status_error_block
    fi
}


function theme_render_ps1() {
    local ps1
    local main
    local promptMark

    main="$(theme_render_main_block)"
    promptMark="$(theme_ps1_prompt_mark)"

    # ps1="${main}\n${promptMark}\[\e[0m\e[K\] "
    ps1="${main}\[\e[0m\e[K\]\n${promptMark}\[\e[0m\e[K\] "

    printf '%s' "$ps1"
}


function theme_apply_terminal_title() {
    local title_text

    title_text="${title:-}"
    PS1="${PS1}\[\e]0;[\\u@\\h:\\w]${title_text}\a\]"
}