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
    if [ "$yafp_ctx_is_root" = "1" ]; then
        printf "#"
    else
        printf "\$"
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

    printf "%s[%s%s%s%s%s%s%s%s]%s" \
        "$cGit" \
        "$YAFP_SYMBOL_ON" \
        "$yafp_ctx_git_last_ts" \
        "$YAFP_SYMBOL_GIT_REPO" \
        "$yafp_ctx_git_repo" \
        "$YAFP_SYMBOL_GIT_SEP" \
        "$yafp_ctx_git_branch" \
        "$YAFP_SYMBOL_GIT_DIR${remote_symbol}${counts}" \
        "$cGit" \
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

    printf "%s[%s%s%s%s%s%s%s]%s" \
        "$cStatusError" \
        "$YAFP_SYMBOL_END" \
        "$yafp_ctx_timestamp" \
        "$YAFP_SYMBOL_CMD" \
        "$cmd" \
        "$YAFP_SYMBOL_ARROW" \
        "${cWarnIcon}${YAFP_SYMBOL_WARN}" \
        "${cError}${yafp_ctx_exit}" \
        "$cNormal"
}


function theme_render_timestamp_next_block() {
    hour=${yafp_ctx_timestamp:11:2}
    if [ "$hour" -gt "06" -a "$hour" -lt "12" ]; then
        day=$YAFP_SYMBOL_MORNING
    elif [ "$hour" -ge "12" -a "$hour" -lt "18" ]; then
        day=$YAFP_SYMBOL_AFTERNOON
    else
        day=$YAFP_SYMBOL_NIGHT
    fi

    printf "%s[%s%s%s]%s" \
        "$cStatusNext" \
        "$YAFP_SYMBOL_SOON" \
        "$yafp_ctx_timestamp" \
        "$day" \
        "$cNormal"
}


function theme_render_info_lines() {
    if [ "$yafp_ctx_git_has_repo" = "1" ]; then
        theme_render_git_block
        printf "\n"
    fi

    if [ "$yafp_ctx_show_status" = "1" ]; then
        if [ "$yafp_ctx_exit" = "0" ]; then
            theme_render_status_ok_block
        else
            theme_render_status_error_block
        fi
    fi
    theme_render_timestamp_next_block
    printf "\n"

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

    printf "[%s\\\\u%s@%s\\\\h%s:%s\\\\w%s]" \
        "$cUserPS1" \
        "$cNormalPS1" \
        "$cHostPS1" \
        "$cNormalPS1" \
        "$cDirPS1" \
        "$cNormalPS1"
}


function theme_render_ps1() {
    local ps1
    local cPromptPS1
    local promptMark

    ps1="$(theme_render_main_block)"
    cPromptPS1="\[$(theme_ps1_prompt_color)\]"
    promptMark="$(theme_ps1_prompt_mark)"

    ps1="${ps1}${cPromptPS1}${promptMark}\[\e[0m$(ps1k)\] "

    printf "%s" "$ps1"
}


function theme_apply_terminal_title() {
    PS1="$PS1\[\e]0;[\\u@\\h:\\w]${title}\a"
}