# On-demand local Git report shared by Bash and zsh.
yafp_git_report() {
    if [ -n "${ZSH_VERSION:-}" ]; then emulate -L zsh -o KSH_ARRAYS; fi
    local gitstatus line xy file_path report reset=$'\033[0m'
    local deleted="${cGitDelete}${YAFP_SYMBOL_GIT_DELETE_EMOJI}"
    local changed="${cGitChange}${YAFP_SYMBOL_GIT_CHANGE_EMOJI}"
    local new="${cGitNew}${YAFP_SYMBOL_GIT_NEW_EMOJI}"
    local staged="${cGitStaged}${YAFP_SYMBOL_GIT_STAGED_EMOJI}"
    local conflict=$'\033[93m'
    if [ -n "${NO_COLOR:-}" ]; then
        deleted=$YAFP_SYMBOL_GIT_DELETE_EMOJI
        changed=$YAFP_SYMBOL_GIT_CHANGE_EMOJI
        new=$YAFP_SYMBOL_GIT_NEW_EMOJI
        staged=$YAFP_SYMBOL_GIT_STAGED_EMOJI
        conflict=''
        reset=''
    fi

    if ! command -v git >/dev/null 2>&1; then
        report='Git is unavailable.'
    elif ! gitstatus="$(command git --no-optional-locks -c core.quotePath=false status --porcelain=v1 2>/dev/null)"; then
        report='Git status unavailable in this directory.'
    elif [ -z "$gitstatus" ]; then
        report=' Working tree clean.'
    else
        # Keep case patterns outside command substitution for macOS Bash 3.2.
        report=''
        while IFS= read -r line; do
            xy=${line:0:2}
            file_path=${line:3}
            case "$xy" in
                '??') report+="$new $file_path$reset"$'\n'; continue ;;
                DD|AU|UD|UA|DU|AA|UU) report+="$conflict $file_path$reset (conflict)"$'\n'; continue ;;
            esac
            case "${xy:1:1}" in
                D) report+="$deleted $file_path$reset"$'\n' ;;
                M|T) report+="$changed $file_path$reset"$'\n' ;;
            esac
            case "${xy:0:1}" in
                A|C|D|M|R|T) report+="$staged $file_path$reset"$'\n' ;;
            esac
        done <<< "$gitstatus"
        report=${report%$'\n'}
    fi
    yafp_preview_frame "$report" '' fit-content ' yafp-git'
}
