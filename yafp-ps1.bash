#!/bin/bash
#
# yafp-ps1.bash
#
# v0.0.1 - 2020-09-17 - nelbren@nelbren.com
#

_pro_root() {
  PS1='$($base/yafp-git.bash && echo -e "\n")[\[\e[30;48;5;6m\]\u\[\e[0m\e[1;37m\]@\[\e[1;48;5;5m\]\h\[\e[0m\e[1;37m\]:\[\e[0m\e[30;48;5;3m\]\w\[\e[0m\e[38;5;1m\]#\[\e[0m\] '
}

_pro_user() {
  PS1='$($base/yafp-git.bash && echo -e "\n")[\[\e[30;48;5;6m\]\u\[\e[0m\e[1;37m\]@\[\e[0m\e[30;48;5;5m\]\h\[\e[0m\e[1;37m\]:\[\e[0m\e[30;48;5;3m\]\w\[\e[0m\]\$ '
}

_dev_root() {
  PS1='$($base/yafp-git.bash && echo -e "\n")[\[\e[30;48;5;6m\]\u\[\e[0m\e[1;37m\]@\[\e[1;48;5;2m\]\h\[\e[0m\e[1;37m\]:\[\e[0m\e[30;48;5;3m\]\w\[\e[0m\e[38;5;1m\]#\[\e[0m\] '
}

_dev_user() {
  PS1='$($base/yafp-git.bash && echo -e "\n")[\[\e[30;48;5;6m\]\u\[\e[0m\e[1;37m\]@\[\e[0m\e[30;48;5;2m\]\h\[\e[0m\e[1;37m\]:\[\e[0m\e[30;48;5;3m\]\w\[\e[0m\]\$ '
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

base=/usr/local/yafp

cfg=$base/yafp-cfg.bash
[ -x $cfg ] || exit 1
. $cfg

len=${#PRO}

dev=1
#if echo $HOSTNAME | grep -q $PRO; then
if [ "${HOSTNAME:0:len}" == "$PRO" ]; then
  dev=0
fi

if [ "$dev" == "1" ]; then
  _dev
else
  _pro
fi
