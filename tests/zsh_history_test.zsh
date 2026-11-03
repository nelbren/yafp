#!/usr/bin/env zsh
emulate -LR zsh -o KSH_ARRAYS
ROOT_DIR="${0:A:h:h}"
. "$ROOT_DIR/scripts/unix/history/context.zsh"
fail() { print -u2 -r -- "not ok - $1"; exit 1; }

for text in 'echo hello' 'echo español' 'echo café' 'echo '; do
    if yafp_zsh_history_has_width_risk "$text"; then fail "Unnecessary redraw candidate: $text"; fi
done
for text in 'echo ⚠️' 'echo ☁️' 'echo ❤️' 'echo 👨‍👩‍👧' 'echo 🇭🇳' 'echo 1️⃣' 'echo 👍🏽' 'echo ⚠'; do
    yafp_zsh_history_has_width_risk "$text" || fail "Missing width candidate: $text"
done

redraws=0
zle() {
    [[ "$1" == .redisplay ]] || fail "Unexpected widget: $1"
    redraws=$((redraws + 1))
}
YAFP_ZSH_HISTORY_REDRAW=1
BUFFER='' CURSOR=0
yafp_zsh_history_line_init
BUFFER='echo plain' CURSOR=4
yafp_zsh_history_line_set
[[ "$redraws" == 0 ]] || fail 'ASCII history redrew'
BUFFER='echo ⚠️' CURSOR=3
yafp_zsh_history_line_set
[[ "$redraws" == 1 && "$BUFFER" == 'echo ⚠️' && "$CURSOR" == 3 ]] || fail 'Emoji redraw changed the command or cursor'
BUFFER='echo plain' CURSOR=4
yafp_zsh_history_line_set
[[ "$redraws" == 2 ]] || fail 'Leaving an emoji entry did not redraw'
yafp_zsh_history_line_set
[[ "$redraws" == 2 ]] || fail 'Ordinary history kept redrawing'
YAFP_ZSH_HISTORY_REDRAW=0
BUFFER='echo ⚠️'
yafp_zsh_history_line_set
[[ "$redraws" == 2 ]] || fail 'Disabled mitigation redrew'
YAFP_ZSH_HISTORY_REDRAW=1
BUFFER='echo ⚠️'
yafp_zsh_history_line_set
yafp_zsh_history_line_init
[[ "$YAFP_ZSH_HISTORY_UNICODE" == 1 ]] || fail 'Initial buffer was not detected'
BUFFER=''
yafp_zsh_history_line_init
[[ "$YAFP_ZSH_HISTORY_UNICODE" == 0 ]] || fail 'Risk state leaked to another command'

saved_path=$PATH
PATH=/nonexistent
BUFFER='echo ⚠️'
yafp_zsh_history_line_set
PATH=$saved_path
[[ "$redraws" == 4 ]] || fail 'Redraw needed an external process'
print 'ok - zsh Unicode history candidates, transitions, opt-out, and unchanged input'
