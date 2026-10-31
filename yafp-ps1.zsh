#!/usr/bin/env zsh
#
# yafp-ps1.zsh
#
# Main engine of YAFP
#

YAFP_VERSION=0.3.5

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

YAFP_COLOR_STATUS_WARNING_BG="intense-yellow"
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

YAFP_COLOR_CMD_ERROR_BG="transparent"
YAFP_COLOR_CMD_ERROR_FG="RED"

# Check / warning blocks
YAFP_COLOR_OK_ICON_BG="green"
YAFP_COLOR_OK_ICON_FG="white"

YAFP_COLOR_WARN_ICON_BG="intense-yellow"
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

YAFP_COLOR_GIT_STAGED_BG="intense-yellow"
YAFP_COLOR_GIT_STAGED_FG="black"
YAFP_COLOR_GIT_STAGED_ATTRS="bold"

# Remote synchronization status
YAFP_COLOR_REMOTE_NEUTRAL_BG="transparent"
YAFP_COLOR_REMOTE_NEUTRAL_FG="BLACK"

YAFP_COLOR_REMOTE_OK_BG="transparent"
YAFP_COLOR_REMOTE_OK_FG="GREEN"

YAFP_COLOR_REMOTE_CONNECTION_BG="normal-green"
YAFP_COLOR_REMOTE_CONNECTION_FG="WHITE"

YAFP_COLOR_REMOTE_ACKNOWLEDGED_BG="transparent"
YAFP_COLOR_REMOTE_ACKNOWLEDGED_FG="RED"

YAFP_COLOR_REMOTE_PENDING_BG="intense-yellow"
YAFP_COLOR_REMOTE_PENDING_FG="black"

YAFP_COLOR_REMOTE_PROBLEM_BG="RED"
YAFP_COLOR_REMOTE_PROBLEM_FG="WHITE"
YAFP_COLOR_REMOTE_PROBLEM_ATTRS="bold"

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
YAFP_SYMBOL_GIT_STAGED_EMOJI="📦"


YAFP_SYMBOL_VENV_EMOJI="🐍"


# Semantic command blocks / OSC 133
YAFP_OSC133=${YAFP_OSC133:-1}
YAFP_COMMAND_BLOCK_STATE=${YAFP_COMMAND_BLOCK_STATE:-Idle}
YAFP_COMMAND_BLOCK_ID=${YAFP_COMMAND_BLOCK_ID:-0}
YAFP_COMMAND_BLOCK_CURRENT_ID=${YAFP_COMMAND_BLOCK_CURRENT_ID:-}
YAFP_COMMAND_BLOCK_PROMPT_TEXT=${YAFP_COMMAND_BLOCK_PROMPT_TEXT:-}
YAFP_COMMAND_BLOCK_COMMAND_TEXT=${YAFP_COMMAND_BLOCK_COMMAND_TEXT:-}
YAFP_COMMAND_BLOCK_STDOUT_TEXT=${YAFP_COMMAND_BLOCK_STDOUT_TEXT:-}
YAFP_COMMAND_BLOCK_STDERR_TEXT=${YAFP_COMMAND_BLOCK_STDERR_TEXT:-}
YAFP_COMMAND_BLOCK_EXIT_CODE=${YAFP_COMMAND_BLOCK_EXIT_CODE:-}
YAFP_COMMAND_BLOCK_STARTED_AT=${YAFP_COMMAND_BLOCK_STARTED_AT:-}
YAFP_COMMAND_BLOCK_FINISHED_AT=${YAFP_COMMAND_BLOCK_FINISHED_AT:-}
YAFP_COMMAND_BLOCK_DURATION_MS=${YAFP_COMMAND_BLOCK_DURATION_MS:-}
YAFP_COMMAND_BLOCK_STATUS=${YAFP_COMMAND_BLOCK_STATUS:-unknown}
YAFP_COMMAND_BLOCK_START_BUFFER_POSITION=${YAFP_COMMAND_BLOCK_START_BUFFER_POSITION:-}
YAFP_COMMAND_BLOCK_END_BUFFER_POSITION=${YAFP_COMMAND_BLOCK_END_BUFFER_POSITION:-}
YAFP_COMMAND_BLOCK_LAST_ID=${YAFP_COMMAND_BLOCK_LAST_ID:-}
YAFP_COMMAND_BLOCK_LAST_COMMAND_TEXT=${YAFP_COMMAND_BLOCK_LAST_COMMAND_TEXT:-}
YAFP_COMMAND_BLOCK_LAST_EXIT_CODE=${YAFP_COMMAND_BLOCK_LAST_EXIT_CODE:-}
YAFP_COMMAND_BLOCK_LAST_STARTED_AT=${YAFP_COMMAND_BLOCK_LAST_STARTED_AT:-}
YAFP_COMMAND_BLOCK_LAST_FINISHED_AT=${YAFP_COMMAND_BLOCK_LAST_FINISHED_AT:-}
YAFP_COMMAND_BLOCK_LAST_DURATION_MS=${YAFP_COMMAND_BLOCK_LAST_DURATION_MS:-}
YAFP_COMMAND_BLOCK_LAST_STATUS=${YAFP_COMMAND_BLOCK_LAST_STATUS:-unknown}
YAFP_COMMAND_BLOCK_LAST_START_BUFFER_POSITION=${YAFP_COMMAND_BLOCK_LAST_START_BUFFER_POSITION:-}
YAFP_COMMAND_BLOCK_LAST_END_BUFFER_POSITION=${YAFP_COMMAND_BLOCK_LAST_END_BUFFER_POSITION:-}


# Theme build
theme_build() {
    emulate -L zsh -o KSH_ARRAYS
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
        "$YAFP_COLOR_STATUS_WARNING_BG" \
        "$YAFP_COLOR_STATUS_WARNING_FG")"

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

    cGitStaged="$(theme_color \
        "$YAFP_COLOR_GIT_STAGED_BG" \
        "$YAFP_COLOR_GIT_STAGED_FG" \
        "$YAFP_COLOR_GIT_STAGED_ATTRS")"

    cRemoteOk="$(theme_color \
        "$YAFP_COLOR_REMOTE_OK_BG" \
        "$YAFP_COLOR_REMOTE_OK_FG")"

    # Exact banner colors do not depend on the terminal's ANSI palette.
    cRemoteConnection=$'\033[0;48;2;0;128;0;38;2;255;255;255m'

    cRemoteAcknowledged="$(theme_color \
        "$YAFP_COLOR_REMOTE_ACKNOWLEDGED_BG" \
        "$YAFP_COLOR_REMOTE_ACKNOWLEDGED_FG")"

    cRemoteNeutral="$(theme_color \
        "$YAFP_COLOR_REMOTE_NEUTRAL_BG" \
        "$YAFP_COLOR_REMOTE_NEUTRAL_FG")"

    cRemoteCountdownNormal="$(theme_color \
        "$YAFP_COLOR_REMOTE_NEUTRAL_BG" \
        white)"

    cRemoteCountdownBright="$(theme_color \
        "$YAFP_COLOR_REMOTE_NEUTRAL_BG" \
        WHITE)"

    cRemotePending=$'\033[0;48;2;255;255;0;38;2;0;0;0m'
    cGitStaged=$cRemotePending

    cRemoteProblem="$(theme_color \
        "$YAFP_COLOR_REMOTE_PROBLEM_BG" \
        "$YAFP_COLOR_REMOTE_PROBLEM_FG" \
        "$YAFP_COLOR_REMOTE_PROBLEM_ATTRS")"

    cClient="$(theme_color \
        "$YAFP_COLOR_CLIENT_BG" \
        "$YAFP_COLOR_CLIENT_FG")"

    cCountry="$(theme_color \
        "$YAFP_COLOR_COUNTRY_BG" \
        "$YAFP_COLOR_COUNTRY_FG")"

    cGitBranch="$(theme_color \
        "$YAFP_COLOR_GIT_BRANCH_BG" \
        "$YAFP_COLOR_GIT_BRANCH_FG")"

    cExit=$cCmdError

    cReset=$'\033[0m'
    cClearLine=$'\033[K'
    cFullReset="${cReset}$cClearLine"
}

theme_reset_all() {
    emulate -L zsh -o KSH_ARRAYS
    ps1_wrap $'\033[0m'
}

theme_color() {
    emulate -L zsh -o KSH_ARRAYS
    # theme_reset_all
    themeColor "$1" "$2" "$3"
}


theme_ps1_color() {
    emulate -L zsh -o KSH_ARRAYS
    printf '%s' "$(ps1_wrap "$(themeColor "$1" "$2" "$3")")"
}


theme_reset() {
    emulate -L zsh -o KSH_ARRAYS
    themeColor "$YAFP_COLOR_NORMAL_BG" "$YAFP_COLOR_NORMAL_FG"
}


theme_ps1_reset() {
    emulate -L zsh -o KSH_ARRAYS
    printf '%s' "$(ps1_wrap "$(theme_reset)")"
}


theme_ps1_user_color() {
    emulate -L zsh -o KSH_ARRAYS
    if [ "$yafp_ctx_is_root" = "1" ]; then
        themeColor "$YAFP_COLOR_ROOT_BG" \
                   "$YAFP_COLOR_ROOT_FG"
    else
        themeColor "$YAFP_COLOR_USER_BG" \
                   "$YAFP_COLOR_USER_FG"
    fi
}


theme_ps1_host_color() {
    emulate -L zsh -o KSH_ARRAYS
    if [ "$yafp_ctx_is_dev" = "1" ]; then
        themeColor "$YAFP_COLOR_HOST_DEV_BG" \
                   "$YAFP_COLOR_HOST_DEV_FG"
    else
        themeColor "$YAFP_COLOR_HOST_PRO_BG" \
                   "$YAFP_COLOR_HOST_PRO_FG"
    fi
}


theme_ps1_prompt_color() {
    emulate -L zsh -o KSH_ARRAYS
    if [ "$yafp_ctx_is_root" = "1" ]; then
        themeColor "$YAFP_COLOR_PROMPT_ROOT_BG" \
            "$YAFP_COLOR_PROMPT_ROOT_FG"
    else
        themeColor "$YAFP_COLOR_PROMPT_USER_BG" \
            "$YAFP_COLOR_PROMPT_USER_FG"
    fi
}


yafp_timer_backend_init() {
    emulate -L zsh -o KSH_ARRAYS
    zmodload zsh/datetime
    YAFP_TIMER_BACKEND=EPOCHREALTIME
}


theme_render_git_counts() {
    emulate -L zsh -o KSH_ARRAYS
    local out=""
    local cGitDeletePS1
    local cGitChangePS1
    local cGitNewPS1
    local cGitStagedPS1
    local cNormalPS1

    # Frame every populated counter block before measuring staged indicators.
    if [ "${yafp_ctx_git_delete:-0}" -le 0 ] &&
       [ "${yafp_ctx_git_change:-0}" -le 0 ] &&
       [ "${yafp_ctx_git_new:-0}" -le 0 ] &&
       [ "${yafp_ctx_git_staged:-0}" -le 0 ]; then
        return 0
    fi
    local frame="$cSeparator" frame_ps1
    [ "${YAFP_THEME_NAME:-}" != default ] || frame=$cGit
    frame_ps1="%{$frame%}"
    printf '%s↦[' "$frame_ps1"

    cGitDeletePS1="$(ps1_wrap "$cGitDelete")"
    cGitChangePS1="$(ps1_wrap "$cGitChange")"
    cGitNewPS1="$(ps1_wrap "$cGitNew")"
    cGitStagedPS1="$(ps1_wrap "$cGitStaged")"
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

    if [ "${yafp_ctx_git_staged:-0}" -gt 0 ]; then
        printf '%s' "$out"
        out=""
        theme_render_staged_expansion
        out+="$cGitStagedPS1"
        out+="$YAFP_SYMBOL_GIT_STAGED_EMOJI"
        out+="${yafp_ctx_git_staged}${cNormalPS1}"
    fi

    printf '%s%s]%s' "$out" "$frame_ps1" "$cNormalPS1"
}


theme_remote_expansion_visible() {
    emulate -L zsh -o KSH_ARRAYS
    if [ "${yafp_ctx_git_remote_connection_announcement:-0}" -eq 1 ]; then
        return 0
    fi

    case "${yafp_ctx_git_remote_state:-}" in
        no-commits|no-upstream|ahead|behind|diverged) return 0 ;;
        error)
            [ "${YAFP_REMOTE_OFFLINE_ACKNOWLEDGED:-0}" -ne 1 ]
            return
            ;;
        *) return 1 ;;
    esac
}


YAFP_REMOTE_EXPANSION_MARKER="__YAFP_REMOTE_INDICATOR__"
YAFP_STAGED_EXPANSION_MARKER="__YAFP_STAGED_INDICATOR__"


yafp_text_display_width() {
    emulate -L zsh -o KSH_ARRAYS
    local char
    local code
    local index
    local text="$1"
    local width=0

    for ((index = 0; index < ${#text}; index++)); do
        char="${text: index:1}"
        printf -v code '%d' "'$char"
        if ((
            (code >= 0x0300 && code <= 0x036f) ||
            (code >= 0x1ab0 && code <= 0x1aff) ||
            (code >= 0x1dc0 && code <= 0x1dff) ||
            (code >= 0x20d0 && code <= 0x20ff) ||
            code == 0x200d ||
            (code >= 0xfe00 && code <= 0xfe0f) ||
            (code >= 0xfe20 && code <= 0xfe2f)
        )); then
            continue
        fi
        if ((
            (code >= 0x1100 && code <= 0x115f) ||
            code == 0x2329 || code == 0x232a ||
            (code >= 0x2e80 && code <= 0xa4cf) ||
            (code >= 0xac00 && code <= 0xd7a3) ||
            (code >= 0xf900 && code <= 0xfaff) ||
            (code >= 0xfe10 && code <= 0xfe19) ||
            (code >= 0xfe30 && code <= 0xfe6f) ||
            (code >= 0xff00 && code <= 0xff60) ||
            (code >= 0xffe0 && code <= 0xffe6) ||
            (code >= 0x1f300 && code <= 0x1faff)
        )); then
            width=$((width + 2))
        else
            width=$((width + 1))
        fi
    done
    yafp_display_width=$width
}


yafp_expansion_terminal_columns() {
    emulate -L zsh -o KSH_ARRAYS
    yafp_expansion_columns="${COLUMNS:-80}"
    if ! [[ "$yafp_expansion_columns" =~ ^[0-9]+$ ]] ||
       [ "$yafp_expansion_columns" -le 0 ]; then
        yafp_expansion_columns=80
    fi
}


yafp_strip_terminal_styles() {
    emulate -L zsh -o KSH_ARRAYS
    local LC_ALL=C
    local terminal_style=$'\033''(\[[0-?]*[ -/]*[@-~]|[()][0-2A-Z])'
    yafp_plain_text="$1"
    while [[ "$yafp_plain_text" =~ $terminal_style ]]; do
        yafp_plain_text="${yafp_plain_text/"$MATCH"/}"
    done
}


yafp_measure_indicator_column() {
    emulate -L zsh -o KSH_ARRAYS
    local marker="$1" rendered="$2" prefix
    yafp_indicator_column=0
    [[ "$rendered" = *"$marker"* ]] || return 0
    prefix="${rendered%%"$marker"*}"
    prefix="${prefix//$YAFP_REMOTE_EXPANSION_MARKER/}"
    prefix="${prefix//$YAFP_STAGED_EXPANSION_MARKER/}"
    # Single prompt expansion handles native escapes without evaluating data.
    prefix="${(%)prefix}"
    prefix="${prefix##*$'\n'}"
    yafp_strip_terminal_styles "$prefix"
    yafp_text_display_width "$yafp_plain_text"
    yafp_expansion_terminal_columns
    yafp_indicator_column=$((yafp_display_width % yafp_expansion_columns + 1))
}


theme_prepare_expansion_columns() {
    emulate -L zsh -o KSH_ARRAYS
    local measured

    yafp_ctx_git_remote_indicator_column=0
    yafp_ctx_git_staged_indicator_column=0
    if [ "${yafp_ctx_git_staged:-0}" -le 0 ] &&
       ! theme_remote_expansion_visible; then
        return 0
    fi
    measured="$(YAFP_MEASURE_EXPANSIONS=1 theme_render_main_block)"
    yafp_measure_indicator_column \
        "$YAFP_REMOTE_EXPANSION_MARKER" "$measured"
    yafp_ctx_git_remote_indicator_column=$yafp_indicator_column
    yafp_measure_indicator_column \
        "$YAFP_STAGED_EXPANSION_MARKER" "$measured"
    yafp_ctx_git_staged_indicator_column=$yafp_indicator_column
}


theme_select_expansion_message() {
    emulate -L zsh -o KSH_ARRAYS
    local long_message="$1"
    local short_message="$2"
    local indicator_column="${3:-0}"
    local indicator_width="${4:-1}"
    local banner_width
    local end
    local fit_columns
    local left
    local start

    yafp_expansion_terminal_columns
    fit_columns=$yafp_expansion_columns
    if [ "$indicator_column" -gt 0 ]; then
        fit_columns=$((fit_columns - 8))
        ((fit_columns >= 1)) || fit_columns=1
    fi
    yafp_expansion_message=""
    local candidate
    for candidate in "$long_message" "$short_message"; do
        yafp_text_display_width "( ${candidate} )"
        banner_width=$yafp_display_width
        left=$(((banner_width - indicator_width) / 2))
        ((left >= 0)) || left=0
        start=$((indicator_column - left))
        ((start >= 1)) || start=1
        end=$((start + banner_width - 1))

        if [ "$end" -le "$fit_columns" ]; then
            yafp_expansion_message="$candidate"
            return 0
        fi
    done
}


theme_reserve_staged_expansion_row() {
    emulate -L zsh -o KSH_ARRAYS
    [ "${yafp_ctx_git_staged:-0}" -gt 0 ] && printf '\n'
    return 0
}


theme_render_staged_expansion() {
    emulate -L zsh -o KSH_ARRAYS
    local banner
    local control
    local count="${yafp_ctx_git_staged:-0}"
    local indicator_width
    local left
    local reset
    local rows=1
    local unit="files"
    local verb="are"

    [ "$count" -gt 0 ] || return 0
    if [ "${YAFP_MEASURE_EXPANSIONS:-0}" -eq 1 ]; then
        printf '%s' "$YAFP_STAGED_EXPANSION_MARKER"
        return 0
    fi
    if [ "$count" -eq 1 ]; then
        unit="file"
        verb="is"
    fi

    indicator_width=$((2 + ${#count}))
    theme_select_expansion_message \
        "⚠ COMMIT PENDING: ${count} staged ${unit} ${verb} ready to commit" \
        "⚠ COMMIT PENDING: ${count}" \
        "${yafp_ctx_git_staged_indicator_column:-0}" \
        "$indicator_width"
    [ -n "$yafp_expansion_message" ] || return 0
    banner="( ${yafp_expansion_message} )"
    yafp_text_display_width "$banner"
    left=$(((yafp_display_width - indicator_width) / 2))
    [ "$left" -ge 0 ] || left=0
    theme_remote_expansion_visible && rows=2
    control=$'\033[s\033['"${rows}"'A'
    [ "$left" -eq 0 ] || control+=$'\033['"${left}"D
    reset="$(theme_reset)"
    printf '%s' \
        "$(ps1_wrap "${control}${cRemotePending}${banner}${reset}"$'\033[u')"
}


theme_reserve_remote_expansion_row() {
    emulate -L zsh -o KSH_ARRAYS
    theme_remote_expansion_visible && printf '\n'
    return 0
}


theme_render_remote_expansion() {
    emulate -L zsh -o KSH_ARRAYS
    local banner
    local color
    local control
    local indicator_width
    local left
    local message
    local reset
    local unit
    local verb

    if [ "${YAFP_MEASURE_EXPANSIONS:-0}" -eq 1 ]; then
        theme_remote_expansion_visible &&
            printf '%s' "$YAFP_REMOTE_EXPANSION_MARKER"
        return 0
    fi

    if [ "${yafp_ctx_git_remote_connection_announcement:-0}" -eq 1 ]; then
        message="✓ INTERNET CONNECTION"
        color="$cRemoteConnection"
        case "${yafp_ctx_git_remote_state:-}" in
            ahead) indicator_width=$((1 + ${#yafp_ctx_git_ahead})) ;;
            behind) indicator_width=$((1 + ${#yafp_ctx_git_behind})) ;;
            diverged)
                indicator_width=$((2 + ${#yafp_ctx_git_ahead} + ${#yafp_ctx_git_behind}))
                ;;
            current) indicator_width=3 ;;
            *) return 0 ;;
        esac
    else
        case "${yafp_ctx_git_remote_state:-}" in
        no-commits)
            indicator_width=2
            theme_select_expansion_message \
                "⚠ NO COMMITS: create the initial commit" \
                "⚠ NO COMMITS" \
                "${yafp_ctx_git_remote_indicator_column:-0}" \
                "$indicator_width"
            message="$yafp_expansion_message"
            color="$cRemotePending"
            ;;
        no-upstream)
            indicator_width=2
            theme_select_expansion_message \
                "⚠ NO UPSTREAM: configure tracking before pushing" \
                "⚠ NO UPSTREAM" \
                "${yafp_ctx_git_remote_indicator_column:-0}" \
                "$indicator_width"
            message="$yafp_expansion_message"
            color="$cRemotePending"
            ;;
        ahead)
            unit="commits"
            verb="have"
            if [ "${yafp_ctx_git_ahead:-0}" -eq 1 ]; then
                unit="commit"
                verb="has"
            fi
            indicator_width=$((1 + ${#yafp_ctx_git_ahead}))
            theme_select_expansion_message \
                "⚠ REMOTE NOT UPDATED: ${yafp_ctx_git_ahead} local ${unit} ${verb} not been pushed to ${yafp_ctx_git_upstream//\%/%%}" \
                "⚠ PUSH PENDING: ${yafp_ctx_git_ahead}" \
                "${yafp_ctx_git_remote_indicator_column:-0}" \
                "$indicator_width"
            message="$yafp_expansion_message"
            color="$cRemotePending"
            ;;
        behind)
            unit="commits"
            verb="are missing"
            if [ "${yafp_ctx_git_behind:-0}" -eq 1 ]; then
                unit="commit"
                verb="is missing"
            fi
            indicator_width=$((1 + ${#yafp_ctx_git_behind}))
            theme_select_expansion_message \
                "☒ OUTDATED REPOSITORY: ${yafp_ctx_git_behind} ${unit} ${verb} from ${yafp_ctx_git_upstream//\%/%%}" \
                "☒ PULL PENDING: ${yafp_ctx_git_behind}" \
                "${yafp_ctx_git_remote_indicator_column:-0}" \
                "$indicator_width"
            message="$yafp_expansion_message"
            color="$cRemoteProblem"
            ;;
        diverged)
            indicator_width=$((2 + ${#yafp_ctx_git_ahead} + ${#yafp_ctx_git_behind}))
            theme_select_expansion_message \
                "☒ DIVERGED REPOSITORY: local +${yafp_ctx_git_ahead} / remote +${yafp_ctx_git_behind} relative to ${yafp_ctx_git_upstream//\%/%%}" \
                "☒ DIVERGED: ⇡${yafp_ctx_git_ahead} ⇣${yafp_ctx_git_behind}" \
                "${yafp_ctx_git_remote_indicator_column:-0}" \
                "$indicator_width"
            message="$yafp_expansion_message"
            color="$cRemoteProblem"
            ;;
        error)
            [ "${YAFP_REMOTE_OFFLINE_ACKNOWLEDGED:-0}" -eq 0 ] || return 0
            message="☒ REMOTE CHECK FAILED"
            color="$cRemoteProblem"
            indicator_width=3
            ;;
        *) return 0 ;;
        esac
    fi

    [ -n "$message" ] || return 0
    theme_select_expansion_message "$message" "$message" \
        "${yafp_ctx_git_remote_indicator_column:-0}" "$indicator_width"
    [ -n "$yafp_expansion_message" ] || return 0
    banner="( ${message} )"
    yafp_text_display_width "$banner"
    left=$(((yafp_display_width - indicator_width) / 2))
    [ "$left" -ge 0 ] || left=0
    control=$'\033[s\033[1A'
    [ "$left" -eq 0 ] || control+=$'\033['"${left}"D
    reset="$(theme_reset)"
    printf '%s' \
        "$(ps1_wrap "${control}${color}${banner}${reset}"$'\033[u')"
}


theme_render_git_remote_status() {
    emulate -L zsh -o KSH_ARRAYS
    local color
    local countdown
    local countdown_color
    local indicator
    local out=""
    local reset

    local frame="$cSeparator" frame_ps1
    [ "${YAFP_THEME_NAME:-}" != default ] || frame=$cGit
    frame_ps1="%{$frame%}"
    reset="$(theme_ps1_reset)"

    if [[ "${yafp_ctx_git_remote_refresh_in:-}" =~ ^[0-9]+$ ]]; then
        yafp_remote_countdown_indicator "$yafp_ctx_git_remote_refresh_in"
        countdown="$yafp_remote_countdown_text"
        if [ -n "$countdown" ]; then
            case "$yafp_remote_countdown_tone" in
                bright) countdown_color="$cRemoteCountdownBright" ;;
                normal) countdown_color="$cRemoteCountdownNormal" ;;
                *) countdown_color="$cRemoteNeutral" ;;
            esac
            out+="$(ps1_wrap "$countdown_color")"
            out+="$countdown"
            out+="$(theme_ps1_reset)"
        fi
    fi

    if [ "${yafp_ctx_git_remote_refreshing:-0}" -eq 1 ]; then
        out+="$(ps1_wrap "$cRemotePending")⟳"
    fi

    out+="$(theme_render_remote_expansion)"

    case "${yafp_ctx_git_remote_state:-}" in
        current)
            if [ "${yafp_ctx_git_remote_connection_announcement:-0}" -eq 1 ]; then
                color="$cRemoteConnection"
            else
                color="$cRemoteOk"
            fi
            indicator="✓🌐︎"
            ;;
        no-commits)
            color="$cRemotePending"
            indicator="○0"
            ;;
        no-upstream)
            color="$cRemotePending"
            indicator="⇡?"
            ;;
        ahead)
            color="$cRemotePending"
            indicator="⇡${yafp_ctx_git_ahead}"
            ;;
        behind)
            color="$cRemoteProblem"
            indicator="⇣${yafp_ctx_git_behind}"
            ;;
        diverged)
            color="$cRemoteProblem"
            indicator="⇡${yafp_ctx_git_ahead}⇣${yafp_ctx_git_behind}"
            ;;
        checking)
            color="$cRemotePending"
            indicator="…"
            ;;
        error)
            if [ "${YAFP_REMOTE_OFFLINE_ACKNOWLEDGED:-0}" -eq 1 ]; then
                color="$cRemoteAcknowledged"
            else
                color="$cRemoteProblem"
            fi
            indicator="☒🌐︎"
            ;;
        *)
            if [ -n "$out" ]; then
                printf '%s↦[%s%s]%s' "$frame_ps1" "$out" "$frame_ps1" "$reset"
            fi
            return 0
            ;;
    esac

    printf '%s↦[%s%s%s%s]%s' "$frame_ps1" "$out" "$(ps1_wrap "$color")" \
        "$indicator" "$frame_ps1" "$reset"
}


yafp_remote_countdown_indicator() {
    emulate -L zsh -o KSH_ARRAYS
    local remaining="${1:-0}"
    local interval="${YAFP_REMOTE_CHECK_INTERVAL:-300}"
    local level

    yafp_remote_countdown_text=""
    yafp_remote_countdown_tone="dim"

    if [ "${YAFP_REMOTE_COUNTDOWN_STYLE:-numeric}" != "symbols" ]; then
        yafp_remote_countdown_text="($remaining)"
        return
    fi

    if ! [[ "$remaining" =~ ^[0-9]+$ && "$interval" =~ ^[1-9][0-9]*$ ]]; then
        yafp_remote_countdown_text="($remaining)"
        return
    fi

    if (( remaining == 0 )); then
        return
    fi

    level=$(( (remaining * 8 + interval - 1) / interval ))
    (( level > 8 )) && level=8

    case "$yafp_remote_countdown_color_index" in
        0) yafp_remote_countdown_tone="bright" ;;
        1) yafp_remote_countdown_tone="normal" ;;
    esac

    case "$level" in
        1) yafp_remote_countdown_text='⡀' ;;
        2) yafp_remote_countdown_text='⣀' ;;
        3) yafp_remote_countdown_text='⣄' ;;
        4) yafp_remote_countdown_text='⣤' ;;
        5) yafp_remote_countdown_text='⣦' ;;
        6) yafp_remote_countdown_text='⣶' ;;
        7) yafp_remote_countdown_text='⣷' ;;
        8) yafp_remote_countdown_text='⣿' ;;
    esac
}


yafp_remote_countdown_advance_color() {
    emulate -L zsh -o KSH_ARRAYS
    local remaining="${1:-}"
    local interval="${YAFP_REMOTE_CHECK_INTERVAL:-300}"

    [ "${YAFP_REMOTE_COUNTDOWN_STYLE:-numeric}" = "symbols" ] || return
    [[ "$remaining" =~ ^[1-9][0-9]*$ ]] || return
    [[ "$interval" =~ ^[1-9][0-9]*$ ]] || return

    yafp_remote_countdown_color_index=$((
        (yafp_remote_countdown_color_index + 1) % 3
    ))
}


theme_apply_terminal_title() {
    emulate -L zsh -o KSH_ARRAYS
    local title_text="${title:-}"
    # Strip terminal controls from untrusted command text.
    title_text="${title_text//$'\033'/}"
    title_text="${title_text//$'\007'/}"
    printf '\033]0;[%s@%s:%s]%s\007' "$USER" "$HOST" "$PWD" "$title_text"
}


theme_ps1_prompt_mark() {
    emulate -L zsh -o KSH_ARRAYS
    printf '%s%s%s' "$(ps1_wrap "$(theme_ps1_prompt_color)")" "$YAFP_USER_PROMPT_SYMBOL" "$(theme_ps1_reset)"
}


theme_render_main_block() {
    emulate -L zsh -o KSH_ARRAYS
    theme_render_general_block

    if [ "$yafp_ctx_git_has_repo" = "1" ]; then
        theme_render_git_block
    fi

    if [ -n "$yafp_venv_segment" ]; then
        theme_render_venv_block
    fi

    if [ "${YAFP_CLOCK:-0}" -eq 1 ] ; then
        theme_render_timestamp
    fi

    if [ "${YAFP_ERROR:-0}" -eq 1 ] && \
       [ "$yafp_ctx_show_status" = "1" ]; then
        if [ "$yafp_ctx_exit" = "0" ]; then
            theme_render_status_ok_block
        else
            theme_render_status_error_block
        fi
    fi
}

# -o-

yafp_timer_backend_emoji() {
    emulate -L zsh -o KSH_ARRAYS
    printf '⚡'
}


yafp_now_ms() {
    [[ "${YAFP_DEVEL:-0}" != 0 ]] || return 0
    emulate -L zsh -o KSH_ARRAYS
    local outvar="$1"
    local -F now="$EPOCHREALTIME"
    printf -v "$outvar" '%.0f' "$(( now * 1000 ))"
}


yafp_wall_ms() {
    emulate -L zsh -o KSH_ARRAYS
    local outvar="$1"
    local -F now="$EPOCHREALTIME"
    printf -v "$outvar" '%.0f' "$(( now * 1000 ))"
}


yafp_osc133_sequence() {
    emulate -L zsh -o KSH_ARRAYS
    [ "${YAFP_OSC133:-1}" -eq 1 ] || return 0
    printf '\033]133;%s\007' "$1"
}


yafp_osc133_ps1_sequence() {
    emulate -L zsh -o KSH_ARRAYS
    [ "${YAFP_OSC133:-1}" -eq 1 ] || return 0
    ps1_wrap "$(printf '\033]133;%s\007' "$1")"
}


yafp_osc133_parse() {
    emulate -L zsh -o KSH_ARRAYS
    local input="$1"
    local payload
    local rest
    local code

    YAFP_OSC133_EVENT=""
    YAFP_OSC133_EXIT_CODE=""

    case "$input" in
        $'\033]133;'*)
            payload="${input#$'\033]133;'}"
            ;;
        *)
            return 1
            ;;
    esac

    if [[ "$payload" = *$'\007'* ]]; then
        payload="${payload%%$'\007'*}"
    elif [[ "$payload" = *$'\033\\'* ]]; then
        payload="${payload%%$'\033'*}"
    else
        return 1
    fi

    YAFP_OSC133_EVENT="${payload%%;*}"
    rest="$payload"
    [ "$rest" != "$YAFP_OSC133_EVENT" ] && rest="${rest#*;}" || rest=""

    case "$YAFP_OSC133_EVENT" in
        A|B|C)
            return 0
            ;;
        D)
            code="${rest%%;*}"
            if [[ "$code" =~ ^[0-9]+$ ]]; then
                YAFP_OSC133_EXIT_CODE="$code"
            fi
            return 0
            ;;
        *)
            YAFP_OSC133_EVENT=""
            return 1
            ;;
    esac
}


yafp_command_block_reset_current() {
    emulate -L zsh -o KSH_ARRAYS
    YAFP_COMMAND_BLOCK_CURRENT_ID=""
    YAFP_COMMAND_BLOCK_PROMPT_TEXT=""
    YAFP_COMMAND_BLOCK_COMMAND_TEXT=""
    YAFP_COMMAND_BLOCK_STDOUT_TEXT=""
    YAFP_COMMAND_BLOCK_STDERR_TEXT=""
    YAFP_COMMAND_BLOCK_EXIT_CODE=""
    YAFP_COMMAND_BLOCK_STARTED_AT=""
    YAFP_COMMAND_BLOCK_FINISHED_AT=""
    YAFP_COMMAND_BLOCK_DURATION_MS=""
    YAFP_COMMAND_BLOCK_STATUS="unknown"
    YAFP_COMMAND_BLOCK_START_BUFFER_POSITION=""
    YAFP_COMMAND_BLOCK_END_BUFFER_POSITION=""
}


yafp_command_block_begin() {
    emulate -L zsh -o KSH_ARRAYS
    YAFP_COMMAND_BLOCK_ID=$((YAFP_COMMAND_BLOCK_ID + 1))
    YAFP_COMMAND_BLOCK_CURRENT_ID="$YAFP_COMMAND_BLOCK_ID"
    YAFP_COMMAND_BLOCK_STATE="PromptStarted"
    YAFP_COMMAND_BLOCK_STATUS="unknown"
    YAFP_COMMAND_BLOCK_PROMPT_TEXT="${PS1:-}"
    YAFP_COMMAND_BLOCK_COMMAND_TEXT=""
    YAFP_COMMAND_BLOCK_EXIT_CODE=""
    YAFP_COMMAND_BLOCK_STARTED_AT=""
    YAFP_COMMAND_BLOCK_FINISHED_AT=""
    YAFP_COMMAND_BLOCK_DURATION_MS=""
    YAFP_COMMAND_BLOCK_START_BUFFER_POSITION="${HISTCMD:-}"
    YAFP_COMMAND_BLOCK_END_BUFFER_POSITION=""
}


yafp_command_block_prompt_end() {
    emulate -L zsh -o KSH_ARRAYS
    if [ "$YAFP_COMMAND_BLOCK_STATE" = "Idle" ]; then
        yafp_command_block_begin
    fi
    YAFP_COMMAND_BLOCK_STATE="PromptEnded"
}


yafp_command_block_command_start() {
    emulate -L zsh -o KSH_ARRAYS
    local command_text="$1"

    if [ "$YAFP_COMMAND_BLOCK_STATE" = "Idle" ]; then
        yafp_command_block_begin
    fi

    if [ "$YAFP_COMMAND_BLOCK_STATE" != "CommandRunning" ]; then
        yafp_wall_ms YAFP_COMMAND_BLOCK_STARTED_AT
        YAFP_COMMAND_BLOCK_COMMAND_TEXT="$command_text"
        YAFP_COMMAND_BLOCK_STATE="CommandRunning"
        YAFP_COMMAND_BLOCK_STATUS="unknown"
    fi
}


yafp_command_block_finish() {
    emulate -L zsh -o KSH_ARRAYS
    local exit_code="$1"

    if [ "$YAFP_COMMAND_BLOCK_STATE" = "Idle" ]; then
        return
    fi

    YAFP_COMMAND_BLOCK_EXIT_CODE="$exit_code"
    yafp_wall_ms YAFP_COMMAND_BLOCK_FINISHED_AT
    if [ -n "$YAFP_COMMAND_BLOCK_STARTED_AT" ]; then
        YAFP_COMMAND_BLOCK_DURATION_MS=$(( \
            ${YAFP_COMMAND_BLOCK_FINISHED_AT:-0} - \
            ${YAFP_COMMAND_BLOCK_STARTED_AT:-0} \
        ))
    fi

    if [ "$exit_code" = "130" ]; then
        YAFP_COMMAND_BLOCK_STATUS="cancelled"
    elif [ "$exit_code" = "0" ]; then
        YAFP_COMMAND_BLOCK_STATUS="success"
    elif [[ "$exit_code" =~ ^[0-9]+$ ]]; then
        YAFP_COMMAND_BLOCK_STATUS="error"
    else
        YAFP_COMMAND_BLOCK_STATUS="unknown"
    fi

    YAFP_COMMAND_BLOCK_END_BUFFER_POSITION="${HISTCMD:-}"
    YAFP_COMMAND_BLOCK_LAST_ID="$YAFP_COMMAND_BLOCK_CURRENT_ID"
    YAFP_COMMAND_BLOCK_LAST_COMMAND_TEXT="$YAFP_COMMAND_BLOCK_COMMAND_TEXT"
    YAFP_COMMAND_BLOCK_LAST_EXIT_CODE="$YAFP_COMMAND_BLOCK_EXIT_CODE"
    YAFP_COMMAND_BLOCK_LAST_STARTED_AT="$YAFP_COMMAND_BLOCK_STARTED_AT"
    YAFP_COMMAND_BLOCK_LAST_FINISHED_AT="$YAFP_COMMAND_BLOCK_FINISHED_AT"
    YAFP_COMMAND_BLOCK_LAST_DURATION_MS="$YAFP_COMMAND_BLOCK_DURATION_MS"
    YAFP_COMMAND_BLOCK_LAST_STATUS="$YAFP_COMMAND_BLOCK_STATUS"
    YAFP_COMMAND_BLOCK_LAST_START_BUFFER_POSITION="$YAFP_COMMAND_BLOCK_START_BUFFER_POSITION"
    YAFP_COMMAND_BLOCK_LAST_END_BUFFER_POSITION="$YAFP_COMMAND_BLOCK_END_BUFFER_POSITION"

    YAFP_COMMAND_BLOCK_STATE="Idle"
}


yafp_command_block_handle_osc133() {
    emulate -L zsh -o KSH_ARRAYS
    local sequence="$1"

    yafp_osc133_parse "$sequence" || return 1

    case "$YAFP_OSC133_EVENT" in
        A) yafp_command_block_begin ;;
        B) yafp_command_block_prompt_end ;;
        C) yafp_command_block_command_start "$this_command" ;;
        D) yafp_command_block_finish "${YAFP_OSC133_EXIT_CODE:-}" ;;
    esac
}








getColorIndex() {
    emulate -L zsh -o KSH_ARRAYS
    local colorName="$1" index
    local colorNames=(black red green yellow blue magenta cyan white)
    local colorNAMES=(BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE)
    for ((index=0; index<8; index++)); do
        if [[ "${colorNames[$index]}" = "$colorName" ]]; then
            printf '%s' "$index"; return 0
        fi
        if [[ "${colorNAMES[$index]}" = "$colorName" ]]; then
            printf '%s' "$((index+8))"; return 0
        fi
    done
    printf '0'
}


setColor() {
    emulate -L zsh -o KSH_ARRAYS
    local colorBG="$(yafp_theme_background_color "$1")" colorFG="$2"
    local indexBG indexFG codes=$'\033[0m' attr
    indexFG=$(getColorIndex "$colorFG")
    shift 2
    for attr in "$@"; do
        case "$attr" in
            bold) codes+=$'\033[1m' ;;
            blink) codes+=$'\033[5m' ;;
        esac
    done
    if [[ "$colorBG" != transparent ]]; then
        indexBG=$(getColorIndex "$colorBG")
        if (( indexBG >= 8 )); then
            codes+=$'\033['"$((100+indexBG-8))m"
        else
            codes+=$'\033['"$((40+indexBG))m"
        fi
    fi
    if (( indexFG >= 8 )); then
        codes+=$'\033['"$((90+indexFG-8))m"
    else
        codes+=$'\033['"$((30+indexFG))m"
    fi
    printf '%s' "$codes"
}


yafp_theme_background_color() {
    emulate -L zsh -o KSH_ARRAYS
    local color="$1"

    case "$color" in
        transparent) printf '%s' "$color"; return ;;
        normal-green) printf '%s' 'green'; return ;;
        intense-yellow) printf '%s' 'YELLOW'; return ;;
        black|BLACK) color=black ;;
        red|RED) color=red ;;
        green|GREEN) color=green ;;
        yellow|YELLOW) color=yellow ;;
        blue|BLUE) color=blue ;;
        magenta|MAGENTA) color=magenta ;;
        cyan|CYAN) color=cyan ;;
        white|WHITE) color=white ;;
        *) printf '%s' "$color"; return ;;
    esac

    if [ "${YAFP_DARKC:-1}" -eq 1 ]; then
        printf '%s' "$color"
        return
    fi

    case "$color" in
        black) printf 'BLACK' ;;
        red) printf 'RED' ;;
        green) printf 'GREEN' ;;
        yellow) printf 'YELLOW' ;;
        blue) printf 'BLUE' ;;
        magenta) printf 'MAGENTA' ;;
        cyan) printf 'CYAN' ;;
        white) printf 'WHITE' ;;
    esac
}


themeColor() {
    emulate -L zsh -o KSH_ARRAYS
    local bg
    local fg
    local attrs

    bg="$1"
    fg="$2"
    attrs="${3:-}"

    if [ -n "$attrs" ]; then
        # shellcheck disable=SC2086
        setColor "$bg" "$fg" $attrs
    else
        setColor "$bg" "$fg"
    fi
}


load_theme() {
    emulate -L zsh -o KSH_ARRAYS
    local theme_file

    yafp_timer_backend_init
    YAFP_TIMER_BACKEND_EMOJI="$(yafp_timer_backend_emoji)"

    theme_file="${SCRIPT_DIR}/themes/${YAFP_THEME}.zsh"

    if [ ! -f "$theme_file" ]; then
        theme_file="${SCRIPT_DIR}/themes/default.zsh"
    fi

    [ -f "$theme_file" ] || return 1
    . "$theme_file"
}


ps1_wrap() {
    emulate -L zsh -o KSH_ARRAYS
    printf '%%{%s%%}' "$1"
}


set_SERVER_OS_EMOJI() {
    emulate -L zsh -o KSH_ARRAYS
    local platform
    local os_id
    local emoji

    platform=$(uname -s)
    os_id=""
    emoji="❓"

    case "$platform" in
        Darwin)
            emoji=""
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
    emulate -L zsh -o KSH_ARRAYS
    local emoji

    case "$CLIENT_OS" in
        WINDOWS) emoji="🪟" ;;
        MACOS)   emoji="" ;;
        LINUX)   emoji="🐧" ;;
        WSL2)    emoji="🐧▶🪟" ;;
        CYGWIN)  emoji="⬘▶🪟" ;;
        GITBASH) emoji="⬙▶🪟" ;;
        *)       emoji="❓" ;;
    esac

    CLIENT_OS_EMOJI="$emoji"
}


set_YAFP_USER() {
    emulate -L zsh -o KSH_ARRAYS
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
    emulate -L zsh -o KSH_ARRAYS
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
    emulate -L zsh -o KSH_ARRAYS
    [[ "${YAFP_CLOCK:-0}" -ne 0 ]] || return
    local h
    local m
    local base
    local half

    strftime -s h '%I' "$EPOCHSECONDS"
    strftime -s m '%M' "$EPOCHSECONDS"

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
    emulate -L zsh -o KSH_ARRAYS
    set_SERVER_OS_EMOJI
    set_CLIENT_OS_EMOJI
    set_YAFP_USER
    set_YAFP_GEOIP_COUNTRY
    set_YAFP_CLOCK_EMOJI
}


yaft_general_context() {
    emulate -L zsh -o KSH_ARRAYS
    yafp_now_ms t_general_begin
    yafp_ctx_exit="$1"
    yafp_ctx_user="$USER"
    yafp_ctx_host="$HOST"
    yafp_ctx_pwd="$PWD"
    [[ "${YAFP_CLOCK:-0}" = 1 ]] && strftime -s yafp_ctx_timestamp '%Y-%m-%d %H:%M:%S' "$EPOCHSECONDS"
    yafp_ctx_is_root=0
    yafp_ctx_is_dev=1
    yafp_ctx_show_status=1
    (( EUID == 0 )) && yafp_ctx_is_root=1
    [[ -n "${PRO:-}" && "$HOST" = "$PRO"* ]] && yafp_ctx_is_dev=0
    yafp_now_ms t_general_end
}


yafp_git_check() {
    emulate -L zsh -o KSH_ARRAYS
    if [[ "$PWD" != "$YAFP_GIT_LAST_PWD" ]] ||
       [[ "$YAFP_GIT_INSIDE" = 0 && -d .git ]]; then
        if [[ -d .git ]]; then
            YAFP_GIT_INSIDE=1
        else
            # Resolve repository status through Git.
            git rev-parse --is-inside-work-tree \
                >/dev/null 2>&1 && YAFP_GIT_INSIDE=1 || YAFP_GIT_INSIDE=0
        fi
        YAFP_GIT_LAST_PWD="$PWD"
    fi
}


yafp_remote_lock_cleanup() {
    emulate -L zsh -o KSH_ARRAYS
    local lock_dir="$1"

    rm -f "${lock_dir}/pid" >/dev/null 2>&1 || true
    rmdir "$lock_dir" >/dev/null 2>&1 || true
}


yafp_remote_check_is_running() {
    emulate -L zsh -o KSH_ARRAYS
    local lock_dir="$1"
    local lock_pid=""

    [ -d "$lock_dir" ] && [ -r "${lock_dir}/pid" ] || return 1
    IFS= read -r lock_pid < "${lock_dir}/pid" || return 1
    [ "$lock_pid" = "starting" ] ||
        { [[ "$lock_pid" =~ ^[0-9]+$ ]] && kill -0 "$lock_pid" 2>/dev/null; }
}


yafp_remote_check_worker() {
    emulate -L zsh -o KSH_ARRAYS
    local repo_root="$1"
    local local_ref="$2"
    local upstream="$3"
    local remote_name="$4"
    local cache_file="$5"
    local lock_dir="$6"
    local ahead=0
    local behind=0
    local checked_at
    local counts
    local current_oid=""
    local current_upstream_oid=""
    local state="error"
    local temp_file
    local quoted_lock_dir
    local write_status=0

    if [ ! -d "$lock_dir" ]; then
        mkdir "$lock_dir" 2>/dev/null || return 0
    fi
    printf -v quoted_lock_dir '%q' "$lock_dir"
    # Expand the shell-escaped local path while it is still in scope.
    trap "yafp_remote_lock_cleanup $quoted_lock_dir" EXIT
    trap 'exit 1' HUP INT TERM

    if GIT_TERMINAL_PROMPT=0 GIT_ASKPASS='' SSH_ASKPASS='' \
       GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-${GIT_SSH:-ssh}} -o BatchMode=yes" \
       git -C "$repo_root" -c credential.interactive=never \
           fetch --quiet --no-tags -- "$remote_name"; then
        counts="$(git -C "$repo_root" rev-list --left-right --count \
            "$local_ref...$upstream" 2>/dev/null)"
        if read -r ahead behind <<< "$counts" &&
           [[ "$ahead" =~ ^[0-9]+$ ]] && [[ "$behind" =~ ^[0-9]+$ ]]; then
            if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
                state="diverged"
            elif [ "$behind" -gt 0 ]; then
                state="behind"
            elif [ "$ahead" -gt 0 ]; then
                state="ahead"
            else
                state="current"
            fi
        else
            ahead=0
            behind=0
        fi
    fi

    current_oid="$(git -C "$repo_root" rev-parse "$local_ref" 2>/dev/null)"
    current_upstream_oid="$(
        git -C "$repo_root" rev-parse "$upstream" 2>/dev/null
    )"
    checked_at="$EPOCHSECONDS"
    temp_file="${cache_file}.$$.tmp"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$checked_at" "$state" "$ahead" "$behind" \
        "$local_ref" "$upstream" "$current_oid" \
        "$current_upstream_oid" > "$temp_file" &&
        mv -f "$temp_file" "$cache_file" || write_status=$?

    yafp_remote_lock_cleanup "$lock_dir"
    trap - EXIT HUP INT TERM
    return "$write_status"
}


yafp_remote_check_start() {
    emulate -L zsh -o KSH_ARRAYS
    unsetopt BGNICE
    local repo_root="$1"
    local local_ref="$2"
    local upstream="$3"
    local remote_name="$4"
    local cache_file="$5"
    local lock_dir="${cache_file}.lock"
    local interval="${YAFP_REMOTE_CHECK_INTERVAL:-300}"
    local lock_mtime=""
    local lock_pid=""
    local lock_pid_file="${lock_dir}/pid"
    local now
    local stale_after
    local worker_pid

    if [ -d "$lock_dir" ]; then
        if [ ! -r "$lock_pid_file" ]; then
            yafp_remote_lock_cleanup "$lock_dir"
        else
            IFS= read -r lock_pid < "$lock_pid_file" || lock_pid=""
            if [[ "$lock_pid" =~ ^[0-9]+$ ]] &&
               ! kill -0 "$lock_pid" 2>/dev/null; then
                yafp_remote_lock_cleanup "$lock_dir"
            elif [ "$lock_pid" != 'starting' ] &&
                 ! [[ "$lock_pid" =~ ^[0-9]+$ ]]; then
                yafp_remote_lock_cleanup "$lock_dir"
            fi
        fi
    fi

    if [ -d "$lock_dir" ]; then
        lock_mtime="$(stat -c %Y "$lock_dir" 2>/dev/null ||
            stat -f %m "$lock_dir" 2>/dev/null)"
        now="$EPOCHSECONDS"
        stale_after=$((interval * 2))
        [ "$stale_after" -ge 600 ] || stale_after=600
        if [[ "$lock_mtime" =~ ^[0-9]+$ ]] &&
           [ $((now - lock_mtime)) -ge "$stale_after" ]; then
            yafp_remote_lock_cleanup "$lock_dir"
        else
            return 0
        fi
    fi

    mkdir "$lock_dir" 2>/dev/null || return 0
    printf 'starting\n' 2>/dev/null > "$lock_pid_file" || {
        yafp_remote_lock_cleanup "$lock_dir"
        return 0
    }

    yafp_remote_check_worker \
        "$repo_root" "$local_ref" "$upstream" "$remote_name" \
        "$cache_file" "$lock_dir" >/dev/null 2>&1 &!
    worker_pid=$!
    if [ -d "$lock_dir" ]; then
        printf '%s\n' "$worker_pid" 2>/dev/null > "$lock_pid_file" || true
    fi
}


yafp_zsh_codex_start_worker() {
    emulate -L zsh -o KSH_ARRAYS
    unsetopt BG_NICE
    bash "$YAFP_ROOT/scripts/unix/codex/collect.bash" \
        "$YAFP_CODEX_DIR/sample" "$SECONDS" </dev/null >/dev/null 2>&1 &!
    YAFP_CODEX_PID=$!
}


yafp_zsh_resources_start_worker() {
    emulate -L zsh -o KSH_ARRAYS
    unsetopt BG_NICE
    # &! disowns at job creation, avoiding notifications and a disown race.
    bash "$YAFP_ROOT/scripts/unix/resources/collect.bash" \
        "$YAFP_RESOURCE_DIR/sample" "$SECONDS" "$HOME" \
        </dev/null >/dev/null 2>&1 &!
    YAFP_RESOURCE_PID=$!
}


yafp_git_command_action() {
    emulate -L zsh -o KSH_ARRAYS
    local command_text="$1"
    local index=0
    local words=()

    words=("${(@z)command_text}")
    [ "${#words[@]}" -gt 1 ] || return 1

    if [ "${words[0]}" = "command" ]; then
        index=1
    fi
    case "${words[$index]:-}" in
        git|git.exe) ;;
        *) return 1 ;;
    esac
    index=$((index + 1))

    while [ "$index" -lt "${#words[@]}" ]; do
        case "${words[$index]}" in
            -C|-c|--git-dir|--work-tree|--namespace|--exec-path)
                index=$((index + 2))
                ;;
            --git-dir=*|--work-tree=*|--namespace=*|--exec-path=*|--bare|--no-pager)
                index=$((index + 1))
                ;;
            -*)
                index=$((index + 1))
                ;;
            push|fetch|pull)
                printf '%s\n' "${words[$index]}"
                return 0
                ;;
            *)
                return 1
                ;;
        esac
    done

    return 1
}


yafp_is_git_sync_command() {
    emulate -L zsh -o KSH_ARRAYS
    yafp_git_command_action "$1" >/dev/null
}


yafp_is_git_pull_command() {
    emulate -L zsh -o KSH_ARRAYS
    local action

    action="$(yafp_git_command_action "$1")" || return 1
    [ "$action" = "pull" ]
}


yafp_should_force_remote_refresh() {
    emulate -L zsh -o KSH_ARRAYS
    local command_text="$1"
    local exit_code="$2"
    local command_key

    yafp_is_git_sync_command "$command_text" || return 1
    command_key="${YAFP_COMMAND_SERIAL:-0}:${command_text}"
    [ "$command_key" != "${YAFP_GIT_SYNC_LAST_COMMAND_KEY:-}" ] || return 1
    YAFP_GIT_SYNC_LAST_COMMAND_KEY="$command_key"

    [ "$exit_code" -eq 0 ]
}


yafp_current_commit() {
    emulate -L zsh -o KSH_ARRAYS
    git -C "$YAFP_ROOT" rev-parse --verify HEAD 2>/dev/null
}


yafp-reload() {
    emulate -L zsh -o KSH_ARRAYS
    . "$YAFP_SCRIPT_PATH"
}


yafp_maybe_auto_reload() {
    emulate -L zsh -o KSH_ARRAYS
    local command_text="$1"
    local exit_code="$2"
    local current_commit

    [ "${YAFP_AUTO_RELOAD:-1}" = 1 ] || return 1
    [ "$exit_code" -eq 0 ] || return 1
    [ -n "${YAFP_LOADED_COMMIT:-}" ] || return 1
    yafp_is_git_pull_command "$command_text" || return 1

    current_commit="$(yafp_current_commit)" || return 1
    [ -n "$current_commit" ] || return 1
    [ "$current_commit" != "$YAFP_LOADED_COMMIT" ] || return 1

    yafp-reload
}


yafp_record_command_stats() {
    emulate -L zsh -o KSH_ARRAYS
    local command_text="$1"
    local exit_code="$2"
    local command_key

    [ -n "$command_text" ] || return 1
    command_key="${YAFP_COMMAND_SERIAL:-0}:${command_text}"
    [ "$command_key" != "${YAFP_COMMAND_STATS_LAST_KEY:-}" ] || return 1
    YAFP_COMMAND_STATS_LAST_KEY="$command_key"

    YAFP_COMMANDS_TOTAL=$((YAFP_COMMANDS_TOTAL + 1))
    if [ "$exit_code" -eq 0 ]; then
        YAFP_COMMANDS_SUCCEEDED=$((YAFP_COMMANDS_SUCCEEDED + 1))
    else
        YAFP_COMMANDS_FAILED=$((YAFP_COMMANDS_FAILED + 1))
    fi
}


yafp_remote_context() {
    emulate -L zsh -o KSH_ARRAYS
    local repo_root="$1"
    local branch="$2"
    local force_refresh="${3:-0}"
    local interval="${YAFP_REMOTE_CHECK_INTERVAL:-300}"
    local ahead
    local behind
    local cache_file
    local cache_age=0
    local cached_local_ref
    local cached_local_oid
    local cached_upstream_oid
    local cached_upstream
    local checked_at=0
    local current_oid
    local current_oids
    local current_upstream_oid
    local git_dir
    local local_ref
    local now
    local remote_name
    local state
    local upstream
    local valid_cache=0

    yafp_ctx_git_remote_state=""
    yafp_ctx_git_ahead=0
    yafp_ctx_git_behind=0
    yafp_ctx_git_upstream=""
    yafp_ctx_git_remote_refreshing=0
    yafp_ctx_git_remote_refresh_in=""
    yafp_ctx_git_remote_connection_announcement=0

    [[ "$interval" =~ ^[0-9]+$ ]] && [ "$interval" -gt 0 ] || return 0
    [ -n "$branch" ] && [ "$branch" != "unnamed" ] || return 0

    local_ref="$(git -C "$repo_root" symbolic-ref -q HEAD 2>/dev/null)" || local_ref=""
    upstream="$(git -C "$repo_root" rev-parse --abbrev-ref \
        --symbolic-full-name '@{upstream}' 2>/dev/null)" || upstream=""
    remote_name="$(git -C "$repo_root" config --get \
        "branch.${branch}.remote" 2>/dev/null)" || remote_name=""

    [ -n "$local_ref" ] || return 0
    if [ -z "$upstream" ]; then
        if ! git -C "$repo_root" rev-parse --verify -q HEAD >/dev/null 2>&1; then
            yafp_ctx_git_remote_state="no-commits"
            return 0
        fi
        # Only branches with a remote need a tracking warning; never fetch here.
        if [ -n "$(git -C "$repo_root" remote 2>/dev/null)" ]; then
            yafp_ctx_git_remote_state="no-upstream"
        fi
        return 0
    fi
    [ -n "$remote_name" ] && [ "$remote_name" != "." ] || return 0

    git_dir="$(git -C "$repo_root" rev-parse --absolute-git-dir 2>/dev/null)"
    current_oids="$(
        git -C "$repo_root" rev-parse "$local_ref" "$upstream" 2>/dev/null
    )"
    current_oid="${current_oids%%$'\n'*}"
    current_upstream_oid="${current_oids#*$'\n'}"
    [ "$current_oids" != "$current_oid" ] || current_upstream_oid=""
    [ -n "$git_dir" ] && [ -n "$current_oid" ] &&
        [ -n "$current_upstream_oid" ] || return 0

    cache_file="${git_dir}/yafp-remote-status"
    now="$EPOCHSECONDS"

    if [ -r "$cache_file" ]; then
        IFS=$'\t' read -r checked_at state ahead behind \
            cached_local_ref cached_upstream cached_local_oid \
            cached_upstream_oid < "$cache_file"
        if [[ "$checked_at" =~ ^[0-9]+$ ]] &&
           [[ "$ahead" =~ ^[0-9]+$ ]] && [[ "$behind" =~ ^[0-9]+$ ]] &&
           [ "$cached_local_ref" = "$local_ref" ] &&
           [ "$cached_upstream" = "$upstream" ] &&
           [ "$cached_local_oid" = "$current_oid" ] &&
           [ "$cached_upstream_oid" = "$current_upstream_oid" ]; then
            valid_cache=1
            yafp_ctx_git_remote_state="$state"
            yafp_ctx_git_ahead="$ahead"
            yafp_ctx_git_behind="$behind"
            yafp_ctx_git_upstream="$upstream"
            cache_age=$((now - checked_at))
            [ "$cache_age" -ge 0 ] || cache_age=0
            yafp_ctx_git_remote_refresh_in=$((interval - cache_age))
            if [ "$yafp_ctx_git_remote_refresh_in" -lt 0 ]; then
                yafp_ctx_git_remote_refresh_in=0
            fi
        fi
    fi

    if [ "$force_refresh" -eq 1 ] ||
       [ "$valid_cache" -eq 0 ] ||
       [ $((now - checked_at)) -ge "$interval" ]; then
        yafp_remote_check_start \
            "$repo_root" "$local_ref" "$upstream" "$remote_name" \
            "$cache_file"
        if [ "$valid_cache" -eq 0 ]; then
            yafp_ctx_git_remote_state="checking"
            yafp_ctx_git_upstream="$upstream"
        else
            yafp_ctx_git_remote_refreshing=1
            yafp_ctx_git_remote_refresh_in=0
        fi
    fi

    if [ "$valid_cache" -eq 1 ] &&
       yafp_remote_check_is_running "${cache_file}.lock"; then
        yafp_ctx_git_remote_refreshing=1
        yafp_ctx_git_remote_refresh_in=0
    fi

    case "$yafp_ctx_git_remote_state" in
        error)
            YAFP_REMOTE_CONNECTIVITY_STATE=offline
            ;;
        current|ahead|behind|diverged)
            YAFP_REMOTE_OFFLINE_ACKNOWLEDGED=0
            if [ "$valid_cache" -eq 1 ] &&
               [ "$yafp_ctx_git_remote_refreshing" -eq 0 ] &&
               [ "$checked_at" -ge "${YAFP_SESSION_STARTED_AT:-0}" ]; then
                if [ "${YAFP_REMOTE_CONNECTIVITY_STATE:-unknown}" != online ]; then
                    yafp_ctx_git_remote_connection_announcement=1
                fi
                YAFP_REMOTE_CONNECTIVITY_STATE=online
            fi
            ;;
    esac
}


yafp_remote_state_label() {
    emulate -L zsh -o KSH_ARRAYS
    local state="$1"
    local ahead="${2:-0}"
    local behind="${3:-0}"

    case "$state" in
        no-commits) printf '%s' '○0 No commits' ;;
        no-upstream) printf '%s' '⇡? No upstream' ;;
        current) printf '%s' '✓ Up to date' ;;
        ahead) printf '⇡%s Ahead' "$ahead" ;;
        behind) printf '⇣%s Behind' "$behind" ;;
        diverged) printf '⇡%s⇣%s Diverged' "$ahead" "$behind" ;;
        checking) printf '%s' '… Checking' ;;
        error) printf '%s' '☒🌐︎ Remote check failed' ;;
        *) printf '%s' '— unavailable' ;;
    esac
}


yafp_remote_state_tone() {
    emulate -L zsh -o KSH_ARRAYS
    if [ "${2:-0}" -eq 1 ]; then
        printf '%s' 'YELLOW'
        return
    fi

    case "$1" in
        current) printf '%s' 'GREEN' ;;
        no-commits|no-upstream|ahead|checking) printf '%s' 'YELLOW' ;;
        behind|diverged|error) printf '%s' 'RED' ;;
        *) printf '%s' '' ;;
    esac
}


yafp_remote_timer_style() {
    emulate -L zsh -o KSH_ARRAYS
    local remaining="$1"
    local interval="$2"

    if [ $((remaining * 100)) -ge $((interval * 66)) ]; then
        yafp_status_timer_emoji="🟢"
        yafp_status_timer_tone="GREEN"
    elif [ $((remaining * 100)) -ge $((interval * 33)) ]; then
        yafp_status_timer_emoji="🟡"
        yafp_status_timer_tone="YELLOW"
    else
        yafp_status_timer_emoji="🔴"
        yafp_status_timer_tone="RED"
    fi
}


yafp_braille_progress_symbol() {
    emulate -L zsh -o KSH_ARRAYS
    case "$1" in
        1) printf '%s' '⡀' ;;
        2) printf '%s' '⣀' ;;
        3) printf '%s' '⣄' ;;
        4) printf '%s' '⣤' ;;
        5) printf '%s' '⣦' ;;
        6) printf '%s' '⣶' ;;
        7) printf '%s' '⣷' ;;
        8) printf '%s' '⣿' ;;
    esac
}


yafp_status_start_color() {
    emulate -L zsh -o KSH_ARRAYS
    local tone="$1"

    [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ -n "$tone" ] || return
    themeColor transparent "$tone"
}


yafp_status_reset_color() {
    emulate -L zsh -o KSH_ARRAYS
    [ -t 1 ] && [ -z "${NO_COLOR:-}" ] || return
    tput sgr0
}


yafp_next_check_tone() {
    emulate -L zsh -o KSH_ARRAYS
    printf '%s' 'YELLOW'
}


yafp_current_time_tone() {
    emulate -L zsh -o KSH_ARRAYS
    printf '%s' 'WHITE'
}


yafp_format_local_time() {
    emulate -L zsh -o KSH_ARRAYS
    strftime '%H:%M:%S' "$1" 2>/dev/null || printf '%s' 'unavailable'
}


yafp_remote_status_report() {
    emulate -L zsh -o KSH_ARRAYS
    local state="$1"
    local ahead="${2:-0}"
    local behind="${3:-0}"
    local refreshing="${4:-0}"
    local remaining="${5:-}"
    local interval="${6:-0}"
    local now="${7:-0}"
    local elapsed
    local filled
    local index
    local next_check
    local partial
    local percent
    local progress=""
    local progress_units
    local state_tone
    local state_label

    state_label="$(yafp_remote_state_label "$state" "$ahead" "$behind")"
    if [ "$refreshing" -eq 1 ]; then
        state_label="⟳ Refreshing · last: ${state_label}"
    fi
    state_tone="$(yafp_remote_state_tone "$state" "$refreshing")"
    printf '%s' '🌐︎       Remote: '
    yafp_status_start_color "$state_tone"
    printf '%s' "$state_label"
    yafp_status_reset_color
    printf '\n'

    if ! [[ "$interval" =~ ^[1-9][0-9]*$ &&
            "$remaining" =~ ^[0-9]+$ && "$now" =~ ^[0-9]+$ ]]; then
        printf '%s\n' '⏱        Timer: unavailable'
        printf '%s\n' '🕘 Current time: unavailable'
        printf '%s\n' '🕒   Next check: unavailable'
        return
    fi

    [ "$remaining" -le "$interval" ] || remaining="$interval"
    yafp_remote_timer_style "$remaining" "$interval"
    elapsed=$((interval - remaining))
    percent=$(((elapsed * 100 + interval / 2) / interval))
    if [ "${YAFP_STATUS_PROGRESS_STYLE:-blocks}" = "symbols" ]; then
        progress_units=$(((percent * 80 + 50) / 100))
        filled=$((progress_units / 8))
        partial=$((progress_units % 8))
        for ((index = 0; index < filled; index++)); do
            progress+="⣿"
        done
        if [ "$partial" -gt 0 ]; then
            progress+="$(yafp_braille_progress_symbol "$partial")"
            index=$((filled + 1))
        else
            index="$filled"
        fi
        for ((; index < 10; index++)); do
            progress+=" "
        done
    else
        filled=$(((percent * 10 + 50) / 100))
        for ((index = 0; index < 10; index++)); do
            if [ "$index" -lt "$filled" ]; then
                progress+="█"
            else
                progress+="░"
            fi
        done
    fi

    next_check="$(yafp_format_local_time $((now + remaining)))"
    printf '%s        Timer: ' "$yafp_status_timer_emoji"
    yafp_status_start_color "$yafp_status_timer_tone"
    printf '%s %s%% · %s/%ss elapsed · %ss remaining' \
        "$progress" "$percent" "$elapsed" "$interval" "$remaining"
    yafp_status_reset_color
    printf '\n'
    printf '%s' '🕘 Current time: '
    yafp_status_start_color "$(yafp_current_time_tone)"
    printf '%s' "$(yafp_format_local_time "$now")"
    yafp_status_reset_color
    printf '\n'
    printf '%s' '🕒   Next check: '
    yafp_status_start_color "$(yafp_next_check_tone)"
    printf '%s' "$next_check"
    yafp_status_reset_color
    printf '\n'
}


yafp-status() {
    emulate -L zsh -o KSH_ARRAYS
    local branch
    local interval="${YAFP_REMOTE_CHECK_INTERVAL:-300}"
    local now
    local repo_root

    command -v git >/dev/null 2>&1 || {
        yafp_remote_status_report "" 0 0 0 "" "$interval" 0
        return 0
    }
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || repo_root=""
    branch="$(git symbolic-ref --short HEAD 2>/dev/null)" || branch=""
    if [ -z "$repo_root" ] || [ -z "$branch" ]; then
        yafp_remote_status_report "" 0 0 0 "" "$interval" 0
        return 0
    fi

    yafp_remote_context "$repo_root" "$branch"
    now="$EPOCHSECONDS"
    yafp_remote_status_report \
        "${yafp_ctx_git_remote_state:-}" \
        "${yafp_ctx_git_ahead:-0}" \
        "${yafp_ctx_git_behind:-0}" \
        "${yafp_ctx_git_remote_refreshing:-0}" \
        "${yafp_ctx_git_remote_refresh_in:-}" \
        "$interval" "$now"
}


yafp-refresh() {
    emulate -L zsh -o KSH_ARRAYS
    local branch
    local repo_root

    command -v git >/dev/null 2>&1 || return 0
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 0
    branch="$(git symbolic-ref --short HEAD 2>/dev/null)" || return 0
    yafp_remote_context "$repo_root" "$branch" 1
}


yafp-ack() {
    emulate -L zsh -o KSH_ARRAYS
    local branch
    local repo_root

    command -v git >/dev/null 2>&1 || {
        printf '%s\n' 'No remote error alert to acknowledge.'
        return 0
    }
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || repo_root=""
    branch="$(git symbolic-ref --short HEAD 2>/dev/null)" || branch=""
    if [ -z "$repo_root" ] || [ -z "$branch" ]; then
        printf '%s\n' 'No remote error alert to acknowledge.'
        return 0
    fi

    yafp_remote_context "$repo_root" "$branch"
    if [ "${yafp_ctx_git_remote_state:-}" != error ]; then
        printf '%s\n' 'No remote error alert to acknowledge.'
        return 0
    fi

    YAFP_REMOTE_OFFLINE_ACKNOWLEDGED=1
    printf '%s\n' 'Remote error alert acknowledged.'
}


yafp-msgs() {
    emulate -L zsh -o KSH_ARRAYS
    local color
    local message
    local severity

    while IFS='|' read -r severity message; do
        case "$severity" in
            green) color="$cRemoteConnection" ;;
            yellow) color="$cRemotePending" ;;
            red) color="$cRemoteProblem" ;;
        esac
        printf '%s%s%s\n' "$color" "( ${message} )" $'\033[0m'
    done <<'EOF'
green|✓ INTERNET CONNECTION
yellow|⚠ REMOTE NOT UPDATED: 1 local commit has not been pushed to origin/main
yellow|⚠ PUSH PENDING: 1
yellow|⚠ COMMIT PENDING: 1 staged file is ready to commit
yellow|⚠ COMMIT PENDING: 1
red|☒ OUTDATED REPOSITORY: 1 commit is missing from origin/main
red|☒ PULL PENDING: 1
red|☒ DIVERGED REPOSITORY: local +1 / remote +1 relative to origin/main
red|☒ DIVERGED: ⇡1 ⇣1
red|☒ REMOTE CHECK FAILED
EOF
}


yafp-help() {
    emulate -L zsh -o KSH_ARRAYS
    local description
    local name

    while IFS='|' read -r name description; do
        yafp_status_start_color YELLOW
        printf '%s' "$name"
        yafp_status_reset_color
        yafp_status_start_color white
        printf '%s' ' • '
        yafp_status_reset_color
        yafp_status_start_color WHITE
        printf '%s' "$description"
        yafp_status_reset_color
        printf '\n'
    done <<'EOF'
yafp-status|Show remote status and refresh timer.
yafp-refresh|Request an immediate remote refresh.
yafp-ack|Acknowledge the current remote error alert.
yafp-reload|Reload YAFP in the current shell.
yafp-stats|Show command execution statistics.
yafp-msgs|Show all prompt banners in severity order.
yafp-help|Show available YAFP commands.
yafp-codex|Show cached Codex quota and authentication status.
yafp-resources|Show the latest RAM, swap, CPU, and disk sample.
EOF
}


yafp-stats() {
    emulate -L zsh -o KSH_ARRAYS
    local count_width=${#YAFP_COMMANDS_TOTAL}
    local failed_percent=0
    local separator
    local separator_width=$((20 + count_width))
    local succeeded_percent=0

    printf -v separator '%*s' "$separator_width" ''
    separator=${separator// /━}

    if [ "$YAFP_COMMANDS_TOTAL" -gt 0 ]; then
        succeeded_percent=$((
            (YAFP_COMMANDS_SUCCEEDED * 100 + YAFP_COMMANDS_TOTAL / 2) /
            YAFP_COMMANDS_TOTAL
        ))
        failed_percent=$((100 - succeeded_percent))
    fi

    yafp_status_start_color GREEN
    printf '✓ %-10s %*d (%03d%%)' 'Succeeded:' "$count_width" \
        "$YAFP_COMMANDS_SUCCEEDED" "$succeeded_percent"
    yafp_status_reset_color
    printf '\n'
    yafp_status_start_color RED
    printf '☒ %-10s %*d (%03d%%)' 'Failed:' "$count_width" \
        "$YAFP_COMMANDS_FAILED" "$failed_percent"
    yafp_status_reset_color
    printf '\n'
    yafp_status_start_color white
    printf '%s' "$separator"
    yafp_status_reset_color
    printf '\n'
    yafp_status_start_color WHITE
    printf '∑ %-10s %*d (100%%)' 'Total:' "$count_width" \
        "$YAFP_COMMANDS_TOTAL"
    yafp_status_reset_color
    printf '\n'
}






yafp-demo() {
    emulate -L zsh -o KSH_ARRAYS
    local sleep_segs=4
    while true; do
        yafp-status
        printf '\nPrompt preview:\n'
        yafp_prompt_preview
        printf '\nControl+C to break this ♾️  loop 🔁 (%ss)\n\n' \
            "$sleep_segs"
        sleep "$sleep_segs"
    done
}


yafp_git_status_counts() {
    emulate -L zsh -o KSH_ARRAYS
    local gitstatus="$1"
    local index_state
    local line
    local worktree_state
    local xy

    yafp_ctx_git_new=0
    yafp_ctx_git_change=0
    yafp_ctx_git_delete=0
    yafp_ctx_git_staged=0

    while IFS= read -r line; do
        [ "${#line}" -ge 2 ] || continue
        xy="${line:0:2}"
        if [ "$xy" = "??" ]; then
            yafp_ctx_git_new=$((yafp_ctx_git_new + 1))
            continue
        fi
        case "$xy" in
            DD|AU|UD|UA|DU|AA|UU) continue ;;
        esac

        index_state="${line:0:1}"
        worktree_state="${line:1:1}"
        case "$index_state" in
            A|C|D|M|R|T)
                yafp_ctx_git_staged=$((yafp_ctx_git_staged + 1))
                ;;
        esac
        case "$worktree_state" in
            D) yafp_ctx_git_delete=$((yafp_ctx_git_delete + 1)) ;;
            M|T) yafp_ctx_git_change=$((yafp_ctx_git_change + 1)) ;;
        esac
    done <<< "$gitstatus"
}


yafp_git_context() {
    emulate -L zsh -o KSH_ARRAYS
    local last_exit="${1:-0}"
    local force_remote_refresh=0

    yafp_git_segment=""
    yafp_ctx_git_has_repo=0
    yafp_ctx_git_repo=""
    yafp_ctx_git_branch=""
    yafp_ctx_git_remote=""
    yafp_ctx_git_last_ts=""
    yafp_ctx_git_new=0
    yafp_ctx_git_change=0
    yafp_ctx_git_delete=0
    yafp_ctx_git_staged=0
    yafp_ctx_git_remote_state=""
    yafp_ctx_git_ahead=0
    yafp_ctx_git_behind=0
    yafp_ctx_git_upstream=""
    yafp_ctx_git_remote_refreshing=0
    yafp_ctx_git_remote_refresh_in=""
    yafp_ctx_git_remote_connection_announcement=0

    yafp_now_ms t_git_begin
    if [ "${YAFP_REPOS:-0}" -eq 0 ]; then
        yafp_now_ms t_git_end
        return
    fi

    if ! command -v git >/dev/null 2>&1; then
        yafp_now_ms t_git_end
        return 0
    fi
    yafp_git_check

    if [ "${YAFP_GIT_INSIDE}" -eq 0 ]; then
        yafp_now_ms t_git_end
        return 0
    fi

    local git_repo_url
    local gitstatus
    local repo_root
    local line

    yafp_ctx_git_has_repo=1
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"

    if [ "${YAFP_INITIAL_REMOTE_CHECK_PENDING:-1}" -eq 1 ]; then
        force_remote_refresh=1
        YAFP_INITIAL_REMOTE_CHECK_PENDING=0
    fi

    if yafp_should_force_remote_refresh "${this_command:-}" "$last_exit"; then
        force_remote_refresh=1
    fi

    git_repo_url=$(git remote get-url origin 2>/dev/null) || git_repo_url=""

    if [ -z "$git_repo_url" ]; then
        yafp_ctx_git_repo="${repo_root:t}"
        yafp_ctx_git_remote="local"
    else
        yafp_ctx_git_repo="${git_repo_url:t}"
        yafp_ctx_git_repo="${yafp_ctx_git_repo%.git}"
        yafp_ctx_git_remote="remote"
    fi

    yafp_ctx_git_branch="$(git symbolic-ref --short HEAD 2>/dev/null)"
    if [ -z "$yafp_ctx_git_branch" ]; then
        yafp_ctx_git_branch="unnamed"
    fi

    yafp_ctx_git_last_ts="$(git log -1 --format=%cd --date=format:'%Y-%m-%d %H:%M:%S' 2>/dev/null)" || yafp_ctx_git_last_ts=""

    yafp_remote_context \
        "$repo_root" "$yafp_ctx_git_branch" "$force_remote_refresh"

    gitstatus="$(git status --porcelain 2>/dev/null)"

    yafp_git_status_counts "$gitstatus"
    yafp_now_ms t_git_end
}


yafp_venv_context() {
    emulate -L zsh -o KSH_ARRAYS
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
    emulate -L zsh -o KSH_ARRAYS
    yafp_now_ms t_err_begin
    yafp_ctx_exit="$1"
    yafp_ctx_previous_command="${this_command:-}"
    yafp_ctx_previous_timestamp="${previous_timestamp:-}"
    previous_timestamp="${yafp_ctx_timestamp:-}"
    yafp_err_segment="${yafp_ctx_previous_command} ✖ ${yafp_ctx_exit}"
    yafp_now_ms t_err_end
}


yafp_dev_segment() {
    emulate -L zsh -o KSH_ARRAYS
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
        "$(ps1_wrap $'\033[0m\033[K')"$'\n'
    )

    printf '%s' "${parts[@]}"
}




yafp_prompt_preview() {
    emulate -L zsh -o KSH_ARRAYS
    local last_exit="${yafp_ctx_exit:-0}" preview
    local this_command='' previous_timestamp="${previous_timestamp:-}"
    local YAFP_PROMPT_RENDERING=1
    yafp_now_ms t_all_begin
    yaft_general_context "$last_exit"
    (( ${+functions[yafp_resources_context]} )) && yafp_resources_context
    (( ${+functions[yafp_codex_context]} )) && yafp_codex_context
    yafp_git_context "$last_exit"
    yafp_venv_context
    yafp_err_context "$last_exit"
    yafp_now_ms t_all_end
    preview="$(yafp_zsh_wrap_styles "$(theme_render_ps1)")"
    print -r -- "${(%)preview}"
}


yafp_prompt_command() {
    local last_exit=$? last_pipeline=("${pipestatus[@]}")
    emulate -L zsh -o KSH_ARRAYS
    typeset -ga YAFP_LAST_PIPESTATUS=("${last_pipeline[@]}")
    YAFP_PROMPT_RENDERING=1
    if [[ "${YAFP_COMMAND_PENDING:-0}" = 1 ]]; then
        yafp_record_command_stats "${this_command:-}" "$last_exit" || true
        if [[ "${YAFP_OSC133:-1}" = 1 ]]; then
            yafp_command_block_finish "$last_exit"
            yafp_osc133_sequence "D;$last_exit"
        fi
        YAFP_COMMAND_PENDING=0
    fi
    yafp_now_ms t_all_begin
    yaft_general_context "$last_exit"
    (( ${+functions[yafp_resources_context]} )) && yafp_resources_context
    (( ${+functions[yafp_codex_context]} )) && yafp_codex_context
    yafp_git_context "$last_exit"
    yafp_venv_context
    yafp_err_context "$last_exit"
    if [[ "${YAFP_TITLE:-0}" = 1 ]]; then
        title="[${yafp_ctx_previous_command} => exit code ${yafp_ctx_exit}]"
        theme_apply_terminal_title
    fi
    yafp_now_ms t_all_end
    YAFP_ZSH_PROMPT="$(yafp_zsh_wrap_styles "$(theme_render_ps1)")"
    yafp_remote_countdown_advance_color "${yafp_ctx_git_remote_refresh_in:-}"
    if [[ "${YAFP_OSC133:-1}" = 1 ]]; then
        yafp_command_block_begin
        YAFP_COMMAND_BLOCK_PROMPT_TEXT="$YAFP_ZSH_PROMPT"
        YAFP_ZSH_PROMPT="$(yafp_osc133_ps1_sequence A)${YAFP_ZSH_PROMPT}$(yafp_osc133_ps1_sequence B)"
        yafp_command_block_prompt_end
    fi
    # Parameter expansion is deliberately one pass: data cannot execute code.
    PROMPT='${YAFP_ZSH_PROMPT}'
    yafp_maybe_auto_reload "${this_command:-}" "$last_exit" || true
    this_command=''
    YAFP_PROMPT_RENDERING=0
    # Hook errors must not prevent other precmd hooks from running.
    return 0
}



yafp_zsh_wrap_styles() {
    emulate -L zsh -o KSH_ARRAYS
    local LC_ALL=C
    local text="$1" out='' char pair rest
    local index=0 invisible=0
    local ansi=$'^\033(\\[[0-?]*[ -/]*[@-~]|[()][0-2A-Z])'
    while (( index < ${#text} )); do
        char="${text: index:1}"
        pair="${text: index:2}"
        case "$pair" in
            '%%') out+="$pair"; ((index+=2)); continue ;;
            '%{') invisible=1; out+="$pair"; ((index+=2)); continue ;;
            '%}') invisible=0; out+="$pair"; ((index+=2)); continue ;;
        esac
        if [[ "$char" == $'\033' && "$invisible" == 0 ]]; then
            rest="${text: index}"
            if [[ "$rest" =~ "$ansi" ]]; then
                out+="%{$MATCH%}"
                ((index+=${#MATCH}))
                continue
            fi
        fi
        out+="$char"
        ((index++))
    done
    printf '%s' "$out"
}

yafp_preexec() {
    emulate -L zsh -o KSH_ARRAYS
    previous_command="${this_command:-}"
    this_command="${3:-$1}"
    YAFP_COMMAND_PENDING=1
    YAFP_COMMAND_SERIAL=$(( ${YAFP_COMMAND_SERIAL:-0} + 1 ))
    if [[ "${YAFP_OSC133:-1}" = 1 ]]; then
        yafp_command_block_command_start "$this_command"
        yafp_osc133_sequence C
    fi
    return 0
}

yafp_zshexit() {
    emulate -L zsh -o KSH_ARRAYS
    (( ${+functions[yafp_resources_cleanup]} )) && yafp_resources_cleanup
    (( ${+functions[yafp_codex_cleanup]} )) && yafp_codex_cleanup
    [[ "${YAFP_STATS_ON_EXIT:-1}" = 1 ]] && yafp-stats
    return 0
}

# Loading is scoped so KSH_ARRAYS and other implementation options never leak.
() {
    emulate -L zsh -o KSH_ARRAYS
    SCRIPT_DIR="${${(%):-%x}:A:h}"
    YAFP_ROOT="$SCRIPT_DIR"
    YAFP_SCRIPT_PATH="${SCRIPT_DIR}/yafp-ps1.zsh"
    local cfg="${YAFP_CONFIG_FILE:-${SCRIPT_DIR}/yafp-cfg.zsh}"
    if [[ ! -f "$cfg" ]]; then
        printf 'Missing configuration file: %s\nRun: cp %s/yafp-cfg.zsh.example %s\n' "$cfg" "$SCRIPT_DIR" "$cfg" >&2
        return 1
    fi
    autoload -Uz is-at-least
    is-at-least 5.9 || {
        print -u2 -r -- 'YAFP requires zsh 5.9 or later.'
        return 1
    }
    . "$cfg" || return 1
    zmodload zsh/datetime || return 1
    YAFP_REMOTE_CHECK_INTERVAL=${YAFP_REMOTE_CHECK_INTERVAL:-300}
    YAFP_RESOURCE_CHECK_INTERVAL=${YAFP_RESOURCE_CHECK_INTERVAL:-0}
    YAFP_REMOTE_COUNTDOWN_STYLE=${YAFP_REMOTE_COUNTDOWN_STYLE:-numeric}
    YAFP_STATUS_PROGRESS_STYLE=${YAFP_STATUS_PROGRESS_STYLE:-blocks}
    YAFP_DARKC=${YAFP_DARKC:-1}
    YAFP_AUTO_RELOAD=${YAFP_AUTO_RELOAD:-1}
    YAFP_STATS_ON_EXIT=${YAFP_STATS_ON_EXIT:-1}
    YAFP_COMMANDS_TOTAL=${YAFP_COMMANDS_TOTAL:-0}
    YAFP_COMMANDS_SUCCEEDED=${YAFP_COMMANDS_SUCCEEDED:-0}
    YAFP_COMMANDS_FAILED=${YAFP_COMMANDS_FAILED:-0}
    YAFP_INITIAL_REMOTE_CHECK_PENDING=${YAFP_INITIAL_REMOTE_CHECK_PENDING:-1}
    YAFP_SESSION_STARTED_AT=${YAFP_SESSION_STARTED_AT:-$EPOCHSECONDS}
    YAFP_REMOTE_CONNECTIVITY_STATE=${YAFP_REMOTE_CONNECTIVITY_STATE:-unknown}
    YAFP_REMOTE_OFFLINE_ACKNOWLEDGED=${YAFP_REMOTE_OFFLINE_ACKNOWLEDGED:-0}
    yafp_remote_countdown_color_index=${yafp_remote_countdown_color_index:-0}
    YAFP_LOADED_COMMIT="$(yafp_current_commit)" || YAFP_LOADED_COMMIT=''
    load_vars
    if [[ -r "$YAFP_ROOT/scripts/unix/resources/context.bash" ]]; then
        . "$YAFP_ROOT/scripts/unix/resources/context.bash"
    fi
    if [[ -r "$YAFP_ROOT/scripts/unix/codex/context.bash" ]]; then
        . "$YAFP_ROOT/scripts/unix/codex/context.bash"
    fi
    load_theme || return 1
    theme_build
    previous_command=${previous_command:-}
    this_command=${this_command:-}
    previous_timestamp=${previous_timestamp:-}
    YAFP_PROMPT_RENDERING=0
    if [ -r "${SCRIPT_DIR}/scripts/unix/metrics/startup.bash" ]; then
        # shellcheck source=scripts/unix/metrics/startup.bash
        . "${SCRIPT_DIR}/scripts/unix/metrics/startup.bash"
        yafp_record_startup "$YAFP_ROOT" zsh
    fi

    if [[ "${YAFP_NO_INSTALL_HOOKS:-0}" != 1 && -o interactive ]]; then
        autoload -Uz add-zsh-hook
        add-zsh-hook preexec yafp_preexec
        add-zsh-hook precmd yafp_prompt_command
        add-zsh-hook zshexit yafp_zshexit
    fi
    return 0
} || return 1

if [[ "${YAFP_NO_INSTALL_HOOKS:-0}" != 1 && -o interactive ]]; then
    setopt PROMPT_PERCENT PROMPT_SUBST
    unsetopt PROMPT_BANG
fi
