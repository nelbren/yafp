#!/bin/bash
#
# themes/default.bash
#

YAFP_THEME_NAME="default"
YAFP_THEME_VERSION="2.2"


theme_render_git_block() {
    local remote_symbol
    local counts

    counts="$(theme_render_git_counts)"

    if [ "$yafp_ctx_git_remote" = "remote" ]; then
        remote_symbol="$YAFP_SYMBOL_REMOTE"
    else
        remote_symbol="$YAFP_SYMBOL_LOCAL"
    fi

    local parts=(
        "${cGit}["
        "$YAFP_SYMBOL_ON"
        "$yafp_ctx_git_last_ts"
        "$YAFP_SYMBOL_GIT_REPO"
        "$yafp_ctx_git_repo"
        "$YAFP_SYMBOL_GIT_SEP"
        "$yafp_ctx_git_branch"
        "$YAFP_SYMBOL_GIT_DIR${remote_symbol}${counts}"
        "$cGit]"
    )

    printf '%s' "${parts[@]}"
}


theme_render_venv_block() {
    local cVenvPS1

    [ -n "$yafp_venv_segment" ] || return

    cVenvPS1="$(ps1_wrap "$cVenv")"

    local parts=(
        "${cVenvPS1}[$yafp_venv_segment]"
    )

    printf '%s' "${parts[@]}"
}


theme_render_timestamp() {
    hour=${yafp_ctx_timestamp:11:2}
    if [ "$hour" -gt "06" -a "$hour" -lt "12" ]; then
        day=$YAFP_SYMBOL_MORNING
    elif [ "$hour" -ge "12" -a "$hour" -lt "18" ]; then
        day=$YAFP_SYMBOL_AFTERNOON
    else
        day=$YAFP_SYMBOL_NIGHT
    fi

    local parts=(
        "${cStatusNext}["
        "$YAFP_SYMBOL_SOON"
        "$yafp_ctx_timestamp"
        "$day]\n"
    )

    printf '%s' "${parts[@]}"
}


theme_render_general_block() {
    local cUserPS1
    local cHostPS1
    local cNormalPS1
    local cDirPS1

    cUserPS1="\[$(theme_ps1_user_color)\]"
    cHostPS1="\[$(theme_ps1_host_color)\]"
    cNormalPS1="\[$(themeColor \
        "$YAFP_COLOR_NORMAL_BG" \
        "$YAFP_COLOR_NORMAL_FG")\]"
    cDirPS1="\[$(themeColor \
        "$YAFP_COLOR_DIR_BG" \
        "$YAFP_COLOR_DIR_FG")\]"

    local parts=(
        "[$cUserPS1\\u"
        "${cSeparator}@"
        "$cHostPS1\\h"
        "$cSeparator:"
        "$cDirPS1\\w"
        "${cSeparator}]"
    )

    printf '%s' "${parts[@]}"
}


theme_render_status_ok_block() {
    theme_render_status_error_block
}

theme_render_status_error_block() {
    local cmd
    local cErrorPS1
    local symbol

    cmd="$yafp_ctx_previous_command"

    if [ "$yafp_ctx_exit" -eq 0 ]; then
        cErrorPS1="$(ps1_wrap "$cCmdOk")"
        symbolError=$YAFP_SYMBOL_OK
    else
        cErrorPS1="$(ps1_wrap "$cCmdError")"
        symbolError=$YAFP_SYMBOL_WARN
    fi

    local parts=(
        "${cErrorPS1}["
        "$YAFP_SYMBOL_END"
        "$yafp_ctx_previous_timestamp"
        "$YAFP_SYMBOL_CMD"
        "$cmd"
        "$YAFP_SYMBOL_ARROW"
        "$symbolError"
        "$yafp_ctx_exit"
        "${cErrorPS1}]"
        "$cFullReset\n"
    )

    printf '%s' "${parts[@]}"
}


theme_render_main_block() {
    if [ "$yafp_ctx_git_has_repo" = "1" ]; then
        theme_render_git_block
    fi

    if [ -n "$yafp_venv_segment" ]; then
        theme_render_venv_block
    fi

    if [[ "$yafp_ctx_git_has_repo" = "1" ||
          -n "$yafp_venv_segment" ]]; then
        printf "$cFullReset\n"
    fi

    if [ "${YAFP_ERROR:-0}" -eq 1 ]; then
        theme_render_status_error_block
    fi

    theme_render_timestamp

    theme_render_general_block
}


theme_render_ps1() {
    local ps1=""
    local main
    local promptMark
    local cFullResetPS1="$(ps1_wrap "$cFullReset")"

    # ps1="${ps1}${cPromptPS1}${promptMark}\[\e[0m$(ps1k)\] "

    main="$(theme_render_main_block)"
    promptMark="$(theme_ps1_prompt_mark)"

    [[ "${YAFP_DEVEL:-0}" -eq 1 ]] && ps1+="$(yafp_dev_segment)"
    ps1+="${main}"
    ps1+="${promptMark}${cFullResetPS1} "

    printf '%s' "$ps1"
}