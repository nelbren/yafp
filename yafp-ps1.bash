#!/bin/bash
#
# yafp-ps1.bash
#
# v0.1.9 - 2025-03-12 - nelbren@nelbren.com
#

# https://www.cyberciti.biz/faq/bash-shell-change-the-color-of-my-shell-prompt-under-linux-or-unix/

function getColorIndex() {
  declare -a colorNames=(black red green yellow blue magenta cyan white)
  declare -a colorNAMES=(BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE)
  colorName=$1
  for index in "${!colorNames[@]}"; do
    if [[ "${colorNames[$index]}" = "${colorName}" ]]; then
      echo ${index}
    else
      if [[ "${colorNAMES[$index]}" = "${colorName}" ]]; then
        echo $((index+8))
      fi
    fi
  done
  return 0
}

function SetColor() {
  colorBG=$1
  colorFG=$2
  indexBG=$(getColorIndex $colorBG)
  indexFG=$(getColorIndex $colorFG)
  normal=1
  codes=""
  shift 2
  for atributo in "$@"; do
    if [ "$atributo" == "bold" ]; then
      codes=${codes}$(tput bold)
      normal=0
    fi
    if [ "$atributo" == "blink" ]; then
      codes=${codes}$(tput blink)
      normal=0
    fi
  done
  if [ "$normal" == "1" ]; then
    codes=${codes}$(tput sgr0)
  fi
  codes=${codes}$(tput setab $indexBG)$(tput setaf $indexFG)
  printf "$codes"
  if [ "$DEBUG" == "1" ]; then
    echo $colorBG $indexBG $colorFG $indexFG
  fi
}

testColors() {
  DEBUG="1"

  SetColor black white
  SetColor white black

  SetColor black RED
  SetColor red black

  SetColor WHITE red bold blink
  SetColor red white

  SetColor yellow BLACK
  SetColor YELLOW black

  SetColor white BLUE
  SetColor WHITE BLUE

  exit
}

setColors() {
  unameOut="$(uname -s)"
  case "${unameOut}" in
    Linux*)     machine=Linux;;
    Darwin*)    machine=Mac;;
    CYGWIN*)    machine=Cygwin;;
    MINGW*)     machine=MinGw;;
    MSYS_NT*)   machine=Git;;
    *)          machine="UNKNOWN:${unameOut}"
  esac
  cError="$(SetColor red YELLOW bold blink)"
  cStatusOk="$(SetColor green black)"
  cStatusError="$(SetColor red black)"
  cNormal="$(SetColor black white)"
  cStatusNext=$(SetColor cyan black)
  cTimestamp="$(SetColor black white)"
  cVenv="$(SetColor blue WHITE)"
  cStatusGit=$(SetColor white black)
  cRepo=$(SetColor white black)
  if [ "$machine" == "MinGw" ]; then
    cError="$(SetColor red yellow)"
  fi
  cReset="\e[K"
}

#testColors

function yafp_venv_and_git() {
  if [ -n "$yafp_venv" ]; then
    codes="${cVenv}[🐍${yafp_venv}]${cNormal}"
    printf "${codes}"
  fi
  git -C . rev-parse 2>/dev/null 1>&2
  if [ "$?" == "128" ]; then
    #printf "\e[K\n"
    return
  fi
  # Based on: https://raw.githubusercontent.com/pablopunk/bashy/master/bashy
  git_repo=$(git remote get-url origin 2>/dev/null)
  if [ -z "$git_repo" ]; then
    # Based on: https://stackoverflow.com/questions/15715825/how-do-you-get-the-git-repositorys-name-in-some-git-repository
    git_repo=$(basename `git rev-parse --show-toplevel`)
    remo="⇣" #⭣⬇
  else
    remo="⚡" #⬍
  fi

  gitstatus="$(git status --porcelain 2>/dev/null)"
  [ "$?" == "0" ] || return
  branch="$(git symbolic-ref --short HEAD)" || branch="unnamed"
  repo=$(basename -s .git $git_repo)

  lastGitTS=$(git log -1 --stat --date=format:'%Y-%m-%d %H:%M:%S' | grep Date | cut -d":" -f2-)
  lastGitTS=$(echo $lastGitTS)

  # https://www.vertex42.com/ExcelTips/unicode-symbols.html
  symbol_clean="$(SetColor GREEN black bold)✅≡"
  symbol_delete="$(SetColor RED black bold blink)-"
  symbol_new="$(SetColor CYAN black bold blink)+"
  symbol_change="$(SetColor YELLOW black bold blink)±"

  delete=0; change=0; new=0

  IFS=$'\n'
  for line in $gitstatus; do
    [[ $line =~ ^[[:space:]]D ]] && delete=$((delete+1))
    [[ $line =~ ^[[:space:]]M ]] && change=$((change+1))
    [[ $line =~ ^\?\? ]] && new=$((new+1))
  done
  unset IFS

  symbols=''

  [ $delete -gt 0 ] && symbols="$symbols$symbol_delete${delete}🟥"
  [ $change -gt 0 ] && symbols="$symbols$symbol_change${change}🟨"
  [ $new -gt 0 ] && symbols="$symbols$symbol_new${new}🟦"

  [ -z "$symbols" ] && symbols="$symbol_clean"
  [[ -z "$yafp_venv" ]] && n='\n' || n=''

  codes="${cStatusGit}[🔛${lastGitTS}${cRepo}💾${repo}ᚼ${branch}💻${remo}📁${symbols}${cStatusGit}]${cNormal}"
  printf "${codes}${cReset}\n"
}

function yafp_err() {
  previous_timestamp=$timestamp
  timestamp="$(date +'%Y-%m-%d %H:%M:%S')"
  if [ "$previous_command" != "prompt_command_yafp" ]; then
    # Fix: Issue with time command execution mixing with PS1 control characters
    if [ "${previous_command:0:4}" == "PS1=" ]; then
      previous_command=""
    fi
    if echo "${previous_command}" | grep -q "%"; then
      previous_command=$(echo "$previous_command" | sed "s/%/%%/g")
    fi
    if [ "$yafp_exit" == "0" ]; then
      codes="${cStatusOk}[🔚${previous_timestamp}🚀${previous_command}→✅]${cNormal}"
    else
      codes="${cStatusError}[🔚${previous_timestamp}🚀${previous_command}${cStatusError}→❌${cError}${yafp_exit}${cNormal}${cStatusError}]${cNormal}"
    fi
    title="[${previous_command} => exit code ${yafp_exit}]"
    printf "${codes}"
  fi
  hour=${timestamp:11:2}
  if [ "$hour" -gt "06" -a "$hour" -lt "12" ]; then
    day="🌇"
  elif [ "$hour" -ge "12" -a "$hour" -lt "18" ]; then
    day="🌆"
  else
    day="🌃" # ↓
  fi
  codes="${cStatusNext}[🔜${timestamp}${day}]${cNormal}"
  printf "${codes}${cReset}\n"
}

_pro_or_dev() {
  if [ "$dev" == "1" ]; then
    cHost="\[$(SetColor green black)\]"
  else
    cHost="\[$(SetColor magenta black)\]"
  fi
  if [ "$USER" == "root" ]; then
    cUser="\[$(SetColor red black)\]"
    cPrompt="\[$(SetColor black RED)\]"
    promptMark='#'
  else
    cUser="\[$(SetColor cyan black)\]"
    cPrompt="\[$(SetColor black GREEN)\]"
    promptMark='\$'
  fi
  cNormalPS1="\[$(SetColor black WHITE)\]"
  cDirPS1="\[$(SetColor yellow black)\]"

  yafp_PS1="[${cUser}\u${cNormalPS1}@${cHost}\h${cNormalPS1}:${cDirPS1}\w${cNormalPS1}]"
}

function add_title_to_terminal() {
  PS1="$PS1\[\e]0;[\u@\h:\w]${title}\a"
}

function ps1k() {
  if [ "$yafp_exit" == "0" ]; then
    YEL=0
  else
    L=${#yafp_exit}
    YEL=$((L+3))
  fi
  myhost=${HOSTNAME%.*}
  mypwd=$(dirs +0)
  [ $((${#USER}+${#myhost}+${#mypwd}+6+${YEL})) -gt $(tput cols) ] && echo -en "\e[K\]"
}

function prompt_command_yafp() {
  yafp_exit=$?
  [[ "$YAFP_PVENV" == "1" ]] && yafp_venv=${VIRTUAL_ENV##*/} || yafp_venv=""
  [ "$YAFP_REPOS" == "1" ] && yafp_venv_and_git
  yafp_err
  PS1="$yafp_PS1"
  [ "$YAFP_ERROR" == "0" ] && yafp_exit=0
  PS1="${PS1}${cPrompt}${promptMark}\[\e[0m$(ps1k)\]\] "
  [ "$YAFP_TITLE" == "1" ] && add_title_to_terminal
}

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cfg=$SCRIPT_DIR/yafp-cfg.bash
[ -x $cfg ] || exit 1
. $cfg

setColors

dev=1
[ "${HOSTNAME:0:${#PRO}}" == "$PRO" ] && dev=0

_pro_or_dev

# https://stackoverflow.com/questions/6109225/echoing-the-last-command-run-in-bash
trap 'previous_command=$this_command; this_command=$BASH_COMMAND' DEBUG
export PROMPT_COMMAND=prompt_command_yafp
