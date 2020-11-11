#!/bin/bash
#
# yafp-ps1.bash
#
# v0.0.4 - 2020-11-10 - nelbren@nelbren.com 
# \e[K

_pro_root() {
  PS1='[\[\e[30;48;5;6m\]\u\[\e[0m\e[1;37m\]@\[\e[1;48;5;5m\]\h\[\e[0m\e[1;37m\]:\[\e[0m\e[30;48;5;3m\]\w\[\e[0m\e[1;37m\]]\[\e[0m\e[91m\]#\[\e[0m\] '
}

_pro_user() {
  PS1='[\[\e[30;48;5;6m\]\u\[\e[0m\e[1;37m\]@\[\e[0m\e[30;48;5;5m\]\h\[\e[0m\e[1;37m\]:\[\e[0m\e[30;48;5;3m\]\w\[\e[0m\e[1;37m\]]\[\e[0m\e[92m\]\$\[\e[0m\] '
}

_dev_root() {
  PS1='[\[\e[30;48;5;6m\]\u\[\e[0m\e[1;37m\]@\[\e[1;48;5;2m\]\h\[\e[0m\e[1;37m\]:\[\e[0m\e[30;48;5;3m\]\w\[\e[0m\e[1;37m\]]\[\e[0m\e[91m\]#\[\e[0m\] '
}

_dev_user() {
  PS1='[\[\e[30;48;5;6m\]\u\[\e[0m\e[1;37m\]@\[\e[0m\e[30;48;5;2m\]\h\[\e[0m\e[1;37m\]:\[\e[0m\e[30;48;5;3m\]\w\[\e[0m\e[1;37m\]]\[\e[0m\e[92m\]\$\[\e[0m\] '
}

_pro() {
  if [ "$USER" == "root" ]; then
    _pro_root
  else
    _pro_user
  fi
}

_dev() {
  if [ "$USER" == "root" ]; then
    _dev_root
  else
    _dev_user
  fi
}

function prompt_command {
  $base/yafp-git.bash
}

base=/usr/local/yafp

cfg=$base/yafp-cfg.bash
[ -x $cfg ] || exit 1
. $cfg

len=${#PRO}

dev=1
if [ "${HOSTNAME:0:len}" == "$PRO" ]; then
  dev=0
fi

if [ "$dev" == "1" ]; then
  _dev
else
  _pro
fi

export PROMPT_COMMAND=prompt_command
