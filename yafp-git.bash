#!/bin/bash
#
# yafp-git.bash
#
# v0.0.2 - 2020-10-16 - nelbren@nelbren.com
#
# Based on: https://raw.githubusercontent.com/pablopunk/bashy/master/bashy

origin_repo=$(git remote get-url origin 2>/dev/null)
if [ -z "$origin_repo" ]; then
  exit 1 # for use with yafp-ps1.bash
fi

repo=$(basename $origin_repo)
branch="$(git symbolic-ref --short HEAD)" || branch="unnamed"
gitstatus="$(git status --porcelain)"

normal="\e[0m\e[97m"
crepo="\e[7;49;97m"
cbranch="\e[30;48;5;7m"
symbol_clean="\e[7;49;92m≡"
symbol_delete="\e[7;49;91m-"
symbol_new="\e[7;49;96m+"
symbol_change="\e[7;49;93m±"

delete=0; change=0; new=0

for line in $gitstatus; do
  [[ $line =~ ^D ]] && delete=$((delete+1))
  [[ $line =~ ^M ]] && change=$((change+1))
  [[ $line =~ ^\?\? ]] && new=$((new+1))
done

[ $delete -gt 0 ] && symbols="$symbols$symbol_delete$delete"
[ $change -gt 0 ] && symbols="$symbols$symbol_change$change"
[ $new -gt 0 ] && symbols="$symbols$symbol_new$new"

[ -z "$symbols" ] && symbols="$symbol_clean"

echo -e "$normal[$crepo$repo$normal$cbranch@$branch:$symbols$normal]"
