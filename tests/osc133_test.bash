#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null && pwd)"
export TERM="${TERM:-xterm-256color}"
export YAFP_NO_INSTALL_HOOKS=1

# Load YAFP in this test shell, then disable interactive hooks so assertions are
# deterministic.
# shellcheck source=../yafp-ps1.bash
set +u
. "$ROOT_DIR/yafp-ps1.bash"
set -u
trap - DEBUG
PROMPT_COMMAND=

fail() {
    printf 'not ok - %s\n' "$1" >&2
    exit 1
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local label="$3"

    [ "$expected" = "$actual" ] || \
        fail "$label: expected [$expected], got [$actual]"
}

assert_nonempty() {
    local actual="$1"
    local label="$2"

    [ -n "$actual" ] || fail "$label: expected a value"
}

test_parse_bel() {
    yafp_osc133_parse $'\033]133;A\007'
    assert_eq "A" "$YAFP_OSC133_EVENT" "BEL event"
}

test_parse_st() {
    yafp_osc133_parse $'\033]133;B\033\\'
    assert_eq "B" "$YAFP_OSC133_EVENT" "ST event"
}

test_parse_exit_codes() {
    yafp_osc133_parse $'\033]133;D;0\007'
    assert_eq "D" "$YAFP_OSC133_EVENT" "D event"
    assert_eq "0" "$YAFP_OSC133_EXIT_CODE" "D;0 exit code"

    yafp_osc133_parse $'\033]133;D;1\007'
    assert_eq "1" "$YAFP_OSC133_EXIT_CODE" "D;1 exit code"
}

test_parse_extra_params() {
    yafp_osc133_parse $'\033]133;D;7;ignored=value\007'
    assert_eq "D" "$YAFP_OSC133_EVENT" "D event with extra params"
    assert_eq "7" "$YAFP_OSC133_EXIT_CODE" "D exit code with extra params"
}

test_reject_plain_text() {
    if yafp_osc133_parse "hello world"; then
        fail "plain text should not parse as OSC 133"
    fi
}

test_disabled_osc133_is_quiet() {
    local output
    YAFP_OSC133=0

    output="$(yafp_osc133_sequence "C")"
    assert_eq "" "$output" "disabled OSC 133 emits no command-start marker"

    output="$(yafp_osc133_ps1_sequence "A")"
    assert_eq "" "$output" "disabled OSC 133 emits no PS1 marker"

    YAFP_OSC133=1
}

test_lifecycle_complete_block() {
    YAFP_COMMAND_BLOCK_STATE="Idle"
    yafp_command_block_reset_current
    this_command="printf ok"

    yafp_command_block_handle_osc133 $'\033]133;A\007'
    assert_eq "PromptStarted" "$YAFP_COMMAND_BLOCK_STATE" "A starts prompt"

    yafp_command_block_handle_osc133 $'\033]133;B\007'
    assert_eq "PromptEnded" "$YAFP_COMMAND_BLOCK_STATE" "B ends prompt"

    yafp_command_block_handle_osc133 $'\033]133;C\007'
    assert_eq "CommandRunning" "$YAFP_COMMAND_BLOCK_STATE" "C starts command"
    assert_eq "printf ok" "$YAFP_COMMAND_BLOCK_COMMAND_TEXT" "command text"

    yafp_command_block_handle_osc133 $'\033]133;D;0\007'
    assert_eq "Idle" "$YAFP_COMMAND_BLOCK_STATE" "D returns to idle"
    assert_eq "success" "$YAFP_COMMAND_BLOCK_LAST_STATUS" "successful status"
    assert_eq "0" "$YAFP_COMMAND_BLOCK_LAST_EXIT_CODE" "successful exit"
    assert_nonempty "$YAFP_COMMAND_BLOCK_LAST_STARTED_AT" "started_at"
    assert_nonempty "$YAFP_COMMAND_BLOCK_LAST_FINISHED_AT" "finished_at"
    assert_nonempty "$YAFP_COMMAND_BLOCK_LAST_DURATION_MS" "duration_ms"
}

test_out_of_order_sequences() {
    YAFP_COMMAND_BLOCK_STATE="Idle"
    yafp_command_block_reset_current
    this_command="false"

    yafp_command_block_handle_osc133 $'\033]133;C\007'
    assert_eq "CommandRunning" "$YAFP_COMMAND_BLOCK_STATE" "C without A starts partial block"

    yafp_command_block_handle_osc133 $'\033]133;D;1;extra\007'
    assert_eq "Idle" "$YAFP_COMMAND_BLOCK_STATE" "D closes partial block"
    assert_eq "error" "$YAFP_COMMAND_BLOCK_LAST_STATUS" "nonzero status"
    assert_eq "1" "$YAFP_COMMAND_BLOCK_LAST_EXIT_CODE" "nonzero exit"

    local last_id="$YAFP_COMMAND_BLOCK_LAST_ID"
    yafp_command_block_handle_osc133 $'\033]133;D;0\007'
    assert_eq "$last_id" "$YAFP_COMMAND_BLOCK_LAST_ID" "D without active block is ignored"
}

test_cancelled_status() {
    YAFP_COMMAND_BLOCK_STATE="Idle"
    yafp_command_block_reset_current
    this_command="sleep 10"

    yafp_command_block_handle_osc133 $'\033]133;C\007'
    yafp_command_block_handle_osc133 $'\033]133;D;130\007'
    assert_eq "cancelled" "$YAFP_COMMAND_BLOCK_LAST_STATUS" "exit 130 is cancelled"
}

test_parse_bel
test_parse_st
test_parse_exit_codes
test_parse_extra_params
test_reject_plain_text
test_disabled_osc133_is_quiet
test_lifecycle_complete_block
test_out_of_order_sequences
test_cancelled_status

printf 'ok - OSC 133 parser and command block lifecycle\n'
