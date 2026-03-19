#!/bin/bash
#
# yafp-ps1.bash
#
# Main engine of YAFP
#

function getColorIndex() {
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


function SetColor() {
    local colorBG
    local colorFG
    local indexBG
    local indexFG
    local normal
    local codes
    local atributo

    colorBG="$1"
    colorFG="$2"

    indexBG=$(getColorIndex "$colorBG")
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

    codes="${codes}$(tput setab "$indexBG")$(tput setaf "$indexFG")"
    printf "%s" "$codes"
}


function ThemeColor() {
    local bg
    local fg
    local attrs

    bg="$1"
    fg="$2"
    attrs="$3"

    if [ -n "$attrs" ]; then
        # shellcheck disable=SC2086
        SetColor "$bg" "$fg" $attrs
    else
        SetColor "$bg" "$fg"
    fi
}


function load_machine() {
    local unameOut

    unameOut="$(uname -s)"

    case "${unameOut}" in
        Linux*) machine=Linux ;;
        Darwin*) machine=Mac ;;
        CYGWIN*) machine=Cygwin ;;
        MINGW*) machine=MinGw ;;
        MSYS_NT*) machine=Git ;;
        *) machine="UNKNOWN:${unameOut}" ;;
    esac
}


function load_theme() {
    local theme_file

    theme_file="${SCRIPT_DIR}/themes/${YAFP_THEME}.bash"

    if [ ! -f "$theme_file" ]; then
        theme_file="${SCRIPT_DIR}/themes/default.bash"
    fi

    [ -f "$theme_file" ] || return 1
    . "$theme_file"
}


function yafp_collect_context() {
    yafp_ctx_exit="$1"
    yafp_ctx_user="$USER"
    yafp_ctx_host="$HOSTNAME"
    yafp_ctx_pwd="$PWD"
    yafp_ctx_timestamp="$(date +'%Y-%m-%d %H:%M:%S')"
    yafp_ctx_previous_command="$previous_command"
    yafp_ctx_previous_timestamp="$previous_timestamp"

    yafp_ctx_is_root=0
    yafp_ctx_is_dev=1
    yafp_ctx_show_status=1

    if [ "$yafp_ctx_user" = "root" ]; then
        yafp_ctx_is_root=1
    fi

    if [ "${HOSTNAME:0:${#PRO}}" = "$PRO" ]; then
        yafp_ctx_is_dev=0
    fi

    if [ "$YAFP_PVENV" = "1" ]; then
        yafp_ctx_venv="${VIRTUAL_ENV##*/}"
    else
        yafp_ctx_venv=""
    fi

    if [ -z "$yafp_ctx_previous_command" ]; then
        yafp_ctx_show_status=0
    fi

    case "$yafp_ctx_previous_command" in
        prompt_command_yafp|theme_*|yafp_*|ps1k)
            yafp_ctx_show_status=0
            ;;
    esac

    if [ "${yafp_ctx_previous_command:0:4}" = "PS1=" ]; then
        yafp_ctx_show_status=0
        yafp_ctx_previous_command=""
    fi

    if printf "%s" "$yafp_ctx_previous_command" | grep -q "%"; then
        yafp_ctx_previous_command=$(
            printf "%s" "$yafp_ctx_previous_command" | sed 's/%/%%/g'
        )
    fi
}


function yafp_collect_git_context() {
    local git_repo_url
    local gitstatus
    local line

    yafp_ctx_git_has_repo=0
    yafp_ctx_git_repo=""
    yafp_ctx_git_branch=""
    yafp_ctx_git_remote=""
    yafp_ctx_git_last_ts=""
    yafp_ctx_git_new=0
    yafp_ctx_git_change=0
    yafp_ctx_git_delete=0

    git -C . rev-parse 2>/dev/null 1>&2 || return

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
}


function ps1k() {
    local yel
    local myhost
    local mypwd

    if [ "$yafp_ctx_exit" = "0" ]; then
        yel=0
    else
        yel=$((${#yafp_ctx_exit} + 3))
    fi

    myhost=${HOSTNAME%.*}
    mypwd=$(dirs +0)

    if [ $((${#USER} + ${#myhost} + ${#mypwd} + 6 + yel)) \
        -gt "$(tput cols)" ]; then
        echo -en "\e[K"
    fi
}


function prompt_command_yafp() {
    local last_exit=$?
    local last_command

    last_command="$previous_command"

    yafp_collect_context "$last_exit"
    yafp_ctx_previous_command="$last_command"
    yafp_collect_git_context

    theme_render_info_lines

    PS1="$(theme_render_ps1)"

    if [ "$YAFP_TITLE" = "1" ]; then
        title="[${yafp_ctx_previous_command} => exit code ${yafp_ctx_exit}]"
        theme_apply_terminal_title
    fi

    previous_timestamp="$yafp_ctx_timestamp"
}


SCRIPT_DIR=$(
    cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd
)

cfg="${SCRIPT_DIR}/yafp-cfg.bash"

[ -f "$cfg" ] || return 1
. "$cfg"

load_machine
load_theme || return 1
theme_build

previous_command=""
this_command=""
previous_timestamp=""

trap 'previous_command=$this_command; this_command=$BASH_COMMAND' DEBUG
PROMPT_COMMAND=prompt_command_yafp
export PROMPT_COMMAND