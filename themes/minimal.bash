#!/bin/bash
#
# themes/minimal.bash
#

YAFP_THEME_NAME="minimal"
YAFP_THEME_VERSION="2.2"

YAFP_COLOR_GIT_CHANGE_BG="YELLOW"
YAFP_COLOR_GIT_CHANGE_FG="black"
YAFP_COLOR_GIT_CHANGE_ATTRS=""


theme_render_general_block() {
    local cUserPS1
    local cHostPS1
    local cNormalPS1local cDirPS1
    local cClientPS1
    local cCountryPS1
    local emojiClient
    local country_text

    cUserPS1="$(ps1_wrap "$(theme_ps1_user_color)")"
    cHostPS1="$(ps1_wrap "$(theme_ps1_host_color)")"
    cNormalPS1="$(theme_ps1_reset)"
    cDirPS1="$(ps1_wrap "$cDir")"
    cClientPS1="$(ps1_wrap "$cClient")"
    cCountryPS1="$(ps1_wrap "$cCountry")"
    cTimestampPS1="$(ps1_wrap "$cTimestamp")"

    if [ -n "$SSH_CLIENT" ]; then
        emojiClient="💻 ${cClientPS1}${CLIENT_OS_EMOJI}"
    else
        emojiClient="🖥️ ${cClientPS1}LOCAL"
    fi

    country_text="${OMP_GEOIP_COUNTRY:-🏠}"

    local parts=(
        "$SERVER_OS_EMOJI $YAFP_USER_ICON "
        "$cUserPS1\\u"
        "$cSeparator @ "
        "$cHostPS1\\h"
        "$cSeparator ← $emojiClient"
        "$cSeparator ◎ "
        "$cCountryPS1$country_text"
        "$cNormalPS1"
        "$cSeparator ⌂ "
        "$cDirPS1\\w"
        "$cSeparator"
    )

    printf '%s' "${parts[@]}"
}


theme_render_git_block() {
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

    if [ -z "$counts" ]; then
        text=""
    else
        text=" with "
    fi

    local parts=(
        "$cSeparator on "
        "$cGitBranchPS1"
        "$YAFP_SYMBOL_GIT_EMOJI"
        "$yafp_ctx_git_branch"
        "$YAFP_SYMBOL_GIT_DIR"
        "$remote_symbol"
        "${cSeparator}$text"
        "$counts"
    )

    printf '%s' "${parts[@]}"
}


theme_render_venv_block() {
    local cVenvPS1

    [ -n "$yafp_venv_segment" ] || return

    cVenvPS1="$(ps1_wrap "$cVenv")"

    local parts=(
        "$cSeparator $YAFP_SYMBOL_VENV_EMOJI "
        "${cVenvPS1}$yafp_venv_segment"
    )

    printf '%s' "${parts[@]}"
}


theme_render_timestamp() {
    local day
    local hour

    hour=${yafp_ctx_timestamp:11:2}
    if [ "$hour" -gt 6 ] && [ "$hour" -lt 12 ]; then
        day="$YAFP_SYMBOL_MORNING"
    elif [ "$hour" -ge 12 ] && [ "$hour" -lt 18 ]; then
        day="$YAFP_SYMBOL_AFTERNOON"
    else
        day="$YAFP_SYMBOL_NIGHT"
    fi

    local parts=(
        "$cSeparator $YAFP_CLOCK_EMOJI "
        "${cTimestamp}$yafp_ctx_timestamp"
        "$cSeparator $day"
    )

    printf '%s' "${parts[@]}"
}


theme_render_status_ok_block() {
    local cExitPS1
    local cNormalPS1

    cExitPS1="$(ps1_wrap "$cStatusOk")"
    cNormalPS1="$(theme_ps1_reset)"

    local parts=(
        "$cSeparator"
        " → $YAFP_SYMBOL_OK "
        "${cExitPS1}$yafp_ctx_exit"
        "$cFullReset"
    )

    printf '%s' "${parts[@]}"
}


theme_render_status_error_block() {
    local cExitPS1
    local cNormalPS1

    cExitPS1="$(ps1_wrap "$cExit")"
    cNormalPS1="$(theme_ps1_reset)"

    local parts=(
        "$cSeparator"
        " → $YAFP_SYMBOL_ERROR "
        "${cExitPS1}$yafp_ctx_exit"
        "$cFullReset"
    )

    printf '%s' "${parts[@]}"
}


theme_render_ps1() {
    local ps1
    local main
    local promptMark
    local cFullResetPS1="$(ps1_wrap "$cFullReset")"

    main="$(theme_render_main_block)"
    promptMark="$(theme_ps1_prompt_mark)"

    ps1="${main}\n"
    [[ "${YAFP_DEVEL:-0}" -eq 1 ]] && ps1+="$(yafp_dev_segment)"
    # ps1+="${promptMark}\[\e[0m\e[K\] "
    ps1+="${promptMark}${cFullResetPS1} "

    printf '%s' "$ps1"
}
