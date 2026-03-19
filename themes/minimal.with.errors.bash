#!/bin/bash
#
# themes/default.bash
#

YAFP_THEME_NAME="default"
YAFP_THEME_VERSION="2.0"

# --------------------------------------------------
# Base colors
# --------------------------------------------------
YAFP_COLOR_NORMAL_BG="black"
YAFP_COLOR_NORMAL_FG="white"

YAFP_COLOR_DIR_BG="yellow"
YAFP_COLOR_DIR_FG="black"

YAFP_COLOR_TIMESTAMP_BG="cyan"
YAFP_COLOR_TIMESTAMP_FG="black"

YAFP_COLOR_STATUS_OK_BG="green"
YAFP_COLOR_STATUS_OK_FG="black"

YAFP_COLOR_STATUS_ERROR_BG="red"
YAFP_COLOR_STATUS_ERROR_FG="black"

YAFP_COLOR_STATUS_NEXT_BG="cyan"
YAFP_COLOR_STATUS_NEXT_FG="black"

YAFP_COLOR_ERROR_BG="red"
YAFP_COLOR_ERROR_FG="YELLOW"
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
YAFP_COLOR_PROMPT_USER_FG="GREEN"

YAFP_COLOR_PROMPT_ROOT_BG="black"
YAFP_COLOR_PROMPT_ROOT_FG="RED"

YAFP_COLOR_VENV_BG="blue"
YAFP_COLOR_VENV_FG="WHITE"

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
YAFP_COLOR_GIT_DELETE_BG="RED"
YAFP_COLOR_GIT_DELETE_FG="black"

YAFP_COLOR_GIT_CHANGE_BG="YELLOW"
YAFP_COLOR_GIT_CHANGE_FG="black"

YAFP_COLOR_GIT_NEW_BG="CYAN"
YAFP_COLOR_GIT_NEW_FG="black"

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
YAFP_SYMBOL_MORNING="🌃"
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
# Libs
# --------------------------------------------------


function set_server_os() {
    platform=$(uname -s)
    case "$platform" in
        Darwin) export SERVER_OS_EMOJI="🍎" ;;
        Linux)  if [ -r /etc/debian_version ]; then
                    export SERVER_OS_EMOJI=""
                else
                    export SERVER_OS_EMOJI="🐧"
                fi;;
        MINGW*|MSYS*|CYGWIN*) export SERVER_OS_EMOJI="🪟" ;;
        *) export SERVER_OS_EMOJI ="❓" ;;
    esac
}


function set_client_os() {
    case "$CLIENT_OS" in
        WINDOWS) export CLIENT_OS_EMOJI="🪟";;
        MACOS)   export CLIENT_OS_EMOJI="🍎";;
        LINUX)   export CLIENT_OS_EMOJI="🐧";;
        WSL2)    export CLIENT_OS_EMOJI="🐧▶🪟";;
        CYGWIN)  export CLIENT_OS_EMOJI="⬘▶🪟";;
        GITBASH) export CLIENT_OS_EMOJI="⬙▶🪟";;
        *) export CLIENT_OS_EMOJI="";;
    esac
    # echo "$(date +'%Y-%m-%d %H:%M:%S') CLIENT_OS=$CLIENT_OS -> CLIENT_OS_EMOJI=$CLIENT_OS ❓" >> /tmp/yafp_debug.log
}


function set_user_context() {
    if [ "${EUID:-$(id -u)}" -eq 0 ]; then
        export OMP_USER_TYPE="root"
        export OMP_USER_ICON="💀"
        export OMP_PROMPT_SYMBOL="#"
        export OMP_USER_STYLE=$'\e[1;38;5;15;48;5;160m'
    else
        export OMP_USER_TYPE="user"
        export OMP_USER_ICON="👤"
        export OMP_PROMPT_SYMBOL="$"
        export OMP_USER_STYLE=$'\e[7;38;5;51;48;5;0m'
    fi
}


function get_ssh_location() {
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
    local h m
    h=$(date +%I)
    m=$(date +%M)

    h=${h#0}
    m=${m#0}

    # convertir minutos a entero seguro
    m=${m:-0}

    case "$h" in
        1)  base="🕐" half="🕜" ;;
        2)  base="🕑" half="🕝" ;;
        3)  base="🕒" half="🕞" ;;
        4)  base="🕓" half="🕟" ;;
        5)  base="🕔" half="🕠" ;;
        6)  base="🕕" half="🕡" ;;
        7)  base="🕖" half="🕢" ;;
        8)  base="🕗" half="🕣" ;;
        9)  base="🕘" half="🕤" ;;
        10) base="🕙" half="🕥" ;;
        11) base="🕚" half="🕦" ;;
        12) base="🕛" half="🕧" ;;
    esac

    # si estamos en segunda mitad de la hora
    if [ "$m" -ge 30 ]; then
        #echo "$half"
        export OMP_CLOCK_EMOJI=$half
    else
        # echo "$base"
        export OMP_CLOCK_EMOJI=$base
    fi
}


function set_custom_colors() {
    export OMP_HOST_STYLE=$'\e[7;38;5;46;48;5;0m'
    export OMP_COUNTRY_STYLE=$'\e[7;38;5;37;48;5;0m'
    export OMP_WDIR_STYLE=$'\e[7;38;5;226;48;5;0m'
    export OMP_TIMESTAMP_STYLE=$'\e[7;38;5;245;48;5;0m'
    export OMP_GIT_BRANCH_STYLE=$'\e[7;38;5;39;48;5;0m'
    export OMP_GIT_STATUS_STYLE=$'\e[7;38;5;214;48;5;0m'
    export OMP_GIT_STAGED_STYLE=$'\e[38;5;46m'
    export OMP_GIT_CONFLICT_STYLE=$'\e[38;5;196m'
    export OMP_GIT_SYNC_STYLE=$'\e[38;5;245m'
    export OMP_EXIT_STYLE=$'\e[1;38;5;15;48;5;160m'
    export OMP_CLIENT_OS_STYLE=$'\e[7;38;5;245;48;5;0m'
    export OMP_RESET=$'\e[0m'
}


function set_minimal_functions() {
    set_server_os
    set_client_os
    set_user_context
    get_ssh_location
    set_clock_emoji
    set_custom_colors
}


# --------------------------------------------------
# Theme build
# --------------------------------------------------
function theme_build() {
    cNormal="$(ThemeColor \
        "$YAFP_COLOR_NORMAL_BG" \
        "$YAFP_COLOR_NORMAL_FG")"

    cDir="$(ThemeColor \
        "$YAFP_COLOR_DIR_BG" \
        "$YAFP_COLOR_DIR_FG")"

    cTimestamp="$(ThemeColor \
        "$YAFP_COLOR_TIMESTAMP_BG" \
        "$YAFP_COLOR_TIMESTAMP_FG")"

    cStatusOk="$(ThemeColor \
        "$YAFP_COLOR_STATUS_OK_BG" \
        "$YAFP_COLOR_STATUS_OK_FG")"

    cStatusError="$(ThemeColor \
        "$YAFP_COLOR_STATUS_ERROR_BG" \
        "$YAFP_COLOR_STATUS_ERROR_FG")"

    cStatusNext="$(ThemeColor \
        "$YAFP_COLOR_STATUS_NEXT_BG" \
        "$YAFP_COLOR_STATUS_NEXT_FG")"

    cError="$(ThemeColor \
        "$YAFP_COLOR_ERROR_BG" \
        "$YAFP_COLOR_ERROR_FG" \
        "$YAFP_COLOR_ERROR_ATTRS")"

    cVenv="$(ThemeColor \
        "$YAFP_COLOR_VENV_BG" \
        "$YAFP_COLOR_VENV_FG")"

    cGit="$(ThemeColor \
        "$YAFP_COLOR_GIT_BG" \
        "$YAFP_COLOR_GIT_FG")"

    cRepo="$(ThemeColor \
        "$YAFP_COLOR_REPO_BG" \
        "$YAFP_COLOR_REPO_FG")"

    cEdge="$(ThemeColor \
        "$YAFP_COLOR_EDGE_BG" \
        "$YAFP_COLOR_EDGE_FG")"

    cEdgeIcon="$(ThemeColor \
        "$YAFP_COLOR_EDGE_ICON_BG" \
        "$YAFP_COLOR_EDGE_ICON_FG")"

    cEdgeLabel="$(ThemeColor \
        "$YAFP_COLOR_EDGE_LABEL_BG" \
        "$YAFP_COLOR_EDGE_LABEL_FG")"

    cCmd="$(ThemeColor \
        "$YAFP_COLOR_CMD_BG" \
        "$YAFP_COLOR_CMD_FG")"

    cOkIcon="$(ThemeColor \
        "$YAFP_COLOR_OK_ICON_BG" \
        "$YAFP_COLOR_OK_ICON_FG")"

    cWarnIcon="$(ThemeColor \
        "$YAFP_COLOR_WARN_ICON_BG" \
        "$YAFP_COLOR_WARN_ICON_FG")"

    cGitDelete="$(ThemeColor \
        "$YAFP_COLOR_GIT_DELETE_BG" \
        "$YAFP_COLOR_GIT_DELETE_FG")"

    cGitChange="$(ThemeColor \
        "$YAFP_COLOR_GIT_CHANGE_BG" \
        "$YAFP_COLOR_GIT_CHANGE_FG")"

    cGitNew="$(ThemeColor \
        "$YAFP_COLOR_GIT_NEW_BG" \
        "$YAFP_COLOR_GIT_NEW_FG")"

    cReset="\e[K"

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
        ThemeColor "$YAFP_COLOR_PROMPT_ROOT_BG" "$YAFP_COLOR_PROMPT_ROOT_FG"
    else
        ThemeColor "$YAFP_COLOR_PROMPT_USER_BG" "$YAFP_COLOR_PROMPT_USER_FG"
    fi
}


function theme_ps1_prompt_mark() {
    cPromptPS1="\[$(theme_ps1_prompt_color)\]"
    if [ "$yafp_ctx_is_root" = "1" ]; then
        printf "${cPromptPS1}#${cNormal}"
    else
        printf "${cPromptPS1}\$${cNormal}"
    fi
}


function theme_render_venv_block() {
    [ -n "$yafp_ctx_venv" ] || return

    printf "%s[%s]%s" \
        "$cVenv" \
        "$yafp_ctx_venv" \
        "$cNormal"
}


function theme_render_git_counts() {
    local out=""

    [ "$yafp_ctx_git_delete" -gt 0 ] && \
        out="${out}${cGitDelete}🗑️${YAFP_SYMBOL_GIT_DELETE}${yafp_ctx_git_delete}"
    [ "$yafp_ctx_git_change" -gt 0 ] && \
        out="${out}${cGitChange}📝${YAFP_SYMBOL_GIT_CHANGE}${yafp_ctx_git_change}"
    [ "$yafp_ctx_git_new" -gt 0 ] && \
        out="${out}${cGitNew}🆕${YAFP_SYMBOL_GIT_NEW}${yafp_ctx_git_new}"

    printf "%s" "$out"
}


function theme_render_git_block() {
    [ "$yafp_ctx_git_has_repo" = "1" ] || return

    local remote_symbol
    local counts

    counts="$(theme_render_git_counts)"

    if [ "$yafp_ctx_git_remote" = "remote" ]; then
        remote_symbol="$YAFP_SYMBOL_REMOTE"
    else
        remote_symbol="$YAFP_SYMBOL_LOCAL"
    fi

    printf " on %s[%s%s%s%s%s%s%s%s]%s " \
        "$OMP_GIT_BRANCH_STYLE" \
        "$yafp_ctx_git_branch" \
        "$YAFP_SYMBOL_GIT_DIR${remote_symbol}${counts}" \
        "$OMP_GIT_BRANCH_STYLE" \
        "$cNormal"
}


function theme_render_status_ok_block() {
    local cmd

    cmd="$yafp_ctx_previous_command"

    printf "%s[%s%s%s%s%s%s]%s" \
        "$cStatusOk" \
        "$YAFP_SYMBOL_END" \
        "$yafp_ctx_timestamp" \
        "$YAFP_SYMBOL_CMD" \
        "$cmd" \
        "$YAFP_SYMBOL_ARROW" \
        "${cOkIcon}${YAFP_SYMBOL_OK}" \
        "$cNormal"
}


function theme_render_status_error_block() {
    local cmd

    cmd="$yafp_ctx_previous_command"

    printf " → %s %s%s%s" \
        "$YAFP_SYMBOL_ERROR" \
        "$OMP_EXIT_STYLE" \
        "$yafp_ctx_exit" \
        "$cNormal"
}


function theme_render_timestamp_next_block() {
    printf "%s[%s%s%s]%s" \
        "$cStatusNext" \
        "$YAFP_SYMBOL_SOON" \
        "$yafp_ctx_timestamp" \
        "$day" \
        "$cNormal"
}


function theme_render_info_lines() {
    return
}


function theme_render_main_block() {
    local cUserPS1
    local cHostPS1
    local cNormalPS1
    local cDirPS1

    cUserPS1="\[$(theme_ps1_user_color)\]"
    cHostPS1="\[$(theme_ps1_host_color)\]"
    cNormalPS1="\[$(ThemeColor \
        "$YAFP_COLOR_NORMAL_BG" \
        "$YAFP_COLOR_NORMAL_FG")\]"
    cDirPS1="\[$(ThemeColor \
        "$YAFP_COLOR_DIR_BG" \
        "$YAFP_COLOR_DIR_FG")\]"

    hour=${yafp_ctx_timestamp:11:2}
    if [ "$hour" -gt "06" -a "$hour" -lt "12" ]; then
        day=$YAFP_SYMBOL_MORNING
    elif [ "$hour" -ge "12" -a "$hour" -lt "18" ]; then
        day=$YAFP_SYMBOL_AFTERNOON
    else
        day=$YAFP_SYMBOL_NIGHT
    fi

    if [ -n "$SSH_CLIENT" ]; then
        emojiClient="💻 ${OMP_CLIENT_OS_STYLE}${CLIENT_OS_EMOJI}${OMP_RESET}"
    else 
        emojiClient="🖥️ ${OMP_CLIENT_OS_STYLE}LOCAL${OMP_RESET}"
    fi

    printf "%s %s %s\\\\u%s @ %s\\\\h%s ← %s ◎ %s%s%s ⌂ %s\\\\w%s" \
        "$SERVER_OS_EMOJI" \
        "$OMP_USER_ICON" \
        "$cUserPS1" \
        "$cNormalPS1" \
        "$cHostPS1" \
        "$cNormalPS1" \
        "$emojiClient" \
        "$OMP_COUNTRY_STYLE" \
        "$OMP_GEOIP_COUNTRY" \
        "$OMP_RESET" \
        "$cDirPS1" \
        "$cNormalPS1"

    if [ "$yafp_ctx_git_has_repo" = "1" ]; then
        theme_render_git_block
    fi

    printf " %s %s%s%s %s" \
        "$OMP_CLOCK_EMOJI" \
        "$OMP_TIMESTAMP_STYLE" \
        "$yafp_ctx_timestamp" \
        "$cNormalPS1" \
        "$day"

    if [ "$yafp_ctx_show_status" = "1" ]; then
        if [ "$yafp_ctx_exit" != "0" ]; then
            theme_render_status_error_block
        fi
    fi
}


function theme_render_ps1() {
    local ps1
    local cPromptPS1
    local promptMark

    #ps1="$(theme_render_main_block)"
    #cPromptPS1="\[$(theme_ps1_prompt_color)\]"

    #ps1="\[$(theme_ps1_prompt_color)\]"
    # ps1="\e[K"
    cPromptPS1="$(theme_render_main_block)"
    promptMark="$(theme_ps1_prompt_mark)"

    #ps1="${ps1}${cPromptPS1}\n${promptMark}\[\e[0m\e[K\] "
    ps1="${ps1}${cPromptPS1}\n${promptMark}\[\e[0m\e[K "

    printf "%s" "$ps1"
}


function theme_apply_terminal_title() {
    PS1="$PS1\[\e]0;[\\u@\\h:\\w]${title}\a"
}