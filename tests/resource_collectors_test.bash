#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "$0")/.." && pwd)"
. "$ROOT_DIR/scripts/unix/resources/collect.bash"
fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }

# Values depend on the kernel page size, including on Apple Silicon.
sysctl() {
    case "$*" in
        '-n hw.memsize') printf '17179869184\n' ;;
        '-n vm.swapusage') printf 'total = 4.00G  used = 512.00M  free = 3584.00M (encrypted)\n' ;;
    esac
}
# One stub covers success and failure without redefining the same function.
vm_stat_fails=0
vm_stat() {
    [ "$vm_stat_fails" -eq 0 ] || return 1
    printf '%s\n' 'Mach Virtual Memory Statistics: (page size of 16384 bytes)' \
        'Pages free: 131072.' 'Pages inactive: 131072.' 'Pages speculative: 0.'
}
[ "$(yafp_collect_memory_macos)" = $'12288 16384\n512 4096' ] || fail 'RAM/swap macOS'
vm_stat_fails=1
[ -z "$(yafp_collect_memory_macos)" ] || fail 'failed probe invented a RAM value'

# Replace /proc input so the fixtures can also run on macOS.
awk() { command awk "$1" <<< "$fixture"; }
fixture=$'MemTotal: 16384000 kB\nMemAvailable: 4096000 kB\nSwapTotal: 0 kB\nSwapFree: 0 kB'
[ "$(yafp_collect_memory_linux)" = $'12000 16000\n0 0' ] || fail 'Linux RAM without swap'
fixture=$'MemTotal: 16384000 kB\nSwapTotal: 4096000 kB\nSwapFree: 2048000 kB'
[ "$(yafp_collect_memory_linux)" = $'- -\n2000 4000' ] || fail 'missing MemAvailable'
printf 'ok - macOS probes (16 KiB pages), Linux, and missing dependencies\n'
