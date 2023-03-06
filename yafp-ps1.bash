#!/bin/bash
#
# yafp-ps1.bash
#
# v0.1.5 - 2023-03-05 - nelbren@nelbren.com
#

function yafp_git() {
  git -C . rev-parse 2>/dev/null 1>&2
  [ "$?" == "128" ] && return
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

  cnormal='\e[0m\e[97m'
  crepo='\e[7;49;97m'
  cbranch='\e[30;48;5;7m'
  # https://www.vertex42.com/ExcelTips/unicode-symbols.html
  symbol_clean='\e[7;49;92m✅≡'
  symbol_delete='\e[7;49;91m-'
  symbol_new='\e[7;49;96m+'
  symbol_change='\e[7;49;93m±'

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

  printf "$cnormal[$crepo$repo$cnormal${cbranch}ᚼ${branch}💻${remo}📁$symbols$cnormal]$n"
}

_pro_or_dev() {
  # https://github.com/nelbren/npres/blob/master/lib/super-tiny-colors.bash
  if [ "$dev" == "1" ]; then
    c_host='\[\e[0m\e[30;48;5;2m\]'
  else
    c_host='\[\e[0m\e[30;48;5;5m\]'
  fi
  if [ "$USER" == "root" ]; then
    c_user='\[\e[0m\e[7;49;91m\]'
    c_prompt='\[\e[0m\e[91m\]'
    c_mark='#'
  else
    c_user='\[\e[0m\e[30;48;5;6m\]'
    c_prompt='\[\e[0m\e[92m\]'
    c_mark='\$'
  fi

  yafp_PS1="[${c_user}\u\[\e[0m\e[1;37m\]@${c_host}\h\[\e[0m\e[1;37m\]:\[\e[0m\e[30;48;5;3m\]\w\[\e[0m\e[1;37m\]]"
}

function add_title_to_terminal() {
  if [ "$yafp_exit" == "0" ]; then
    PS1="$PS1\[\e]0;[\u@\h:\w]\a"
  else
    PS1="$PS1\[\e]0;[\u@\h:\w] - exit code $yafp_exit\a"
  fi
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
  [ $((${#USER}+${#myhost}+${#mypwd}+6+${YEL})) -gt $(tput cols) ] && echo -en "\e[K"
}

function prompt_command_yafp() {
  yafp_exit=$?
  [[ "$YAFP_PVENV" == "1" ]] && yafp_venv=${VIRTUAL_ENV##*/} || yafp_venv=""
  [ "$YAFP_REPOS" == "1" ] && yafp_git
  [ -n "$yafp_venv" ] && printf "(\e[44;93m$yafp_venv\e[0m)\n"
  #[ -n "$yafp_venv" ] && PS1="${PS1}{\[\e[44;93m\]$yafp_venv\[\e[0m\]}"
  PS1="$yafp_PS1"
  [ "$YAFP_ERROR" == "0" ] && yafp_exit=0
  [ "$yafp_exit" != "0" ] && PS1="${PS1}(\[\e[1;48;5;1m\]$yafp_exit\[\e[0m\])"
  PS1="${PS1}${c_prompt}${c_mark}\[\e[0m$(ps1k)\] "
  [ "$YAFP_TITLE" == "1" ] && add_title_to_terminal
}

cfg=/usr/local/yafp/yafp-cfg.bash
[ -x $cfg ] || exit 1
. $cfg

dev=1
[ "${HOSTNAME:0:${#PRO}}" == "$PRO" ] && dev=0

_pro_or_dev

export PROMPT_COMMAND=prompt_command_yafp
