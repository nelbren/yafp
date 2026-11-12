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
# shellcheck disable=SC2317,SC2329
awk() { command awk "$1" <<< "$fixture"; }
fixture=$'MemTotal: 16384000 kB\nMemAvailable: 4096000 kB\nSwapTotal: 0 kB\nSwapFree: 0 kB'
[ "$(yafp_collect_memory_linux)" = $'12000 16000\n0 0' ] || fail 'Linux RAM without swap'
fixture=$'MemTotal: 16384000 kB\nSwapTotal: 4096000 kB\nSwapFree: 2048000 kB'
[ "$(yafp_collect_memory_linux)" = $'- -\n2000 4000' ] || fail 'missing MemAvailable'
printf 'ok - macOS probes (16 KiB pages), Linux, and missing dependencies\n'

unset -f awk
uname() { printf '%s\n' "$fixture_platform"; }
ps() {
    case "$2" in
        pid=,lstart=,time=,comm=)
            if [ "${fixture_second:-0}" -eq 0 ]; then
                printf '%s\n' ' 12 Mon Nov  9 12:00:00 2026 9000:00.00 old' \
                    ' 13 Mon Nov  9 12:00:00 2026 0:00.04 /tmp/medium process' \
                    ' 14 Mon Nov  9 12:00:00 2026 1000:59.99 fast' \
                    ' 15 Mon Nov  9 12:00:00 2026 0:00.00 reused' \
                    ' 16 Mon Nov  9 12:00:00 2026 0:01.00 busy' \
                    ' 17 Mon Nov  9 12:00:00 2026 0:02.00 exiting'
            else
                printf '%s\n' ' 12 Mon Nov  9 12:00:00 2026 9000:00.00 old' \
                    ' 13 Mon Nov  9 12:00:00 2026 0:00.09 /tmp/medium process' \
                    ' 14 Mon Nov  9 12:00:00 2026 1001:00.29 fast' \
                    ' 15 Mon Nov  9 12:00:01 2026 0:05.00 reused' \
                    ' 16 Mon Nov  9 12:00:00 2026 0:01.10 busy' \
                    ' 18 Mon Nov  9 12:00:01 2026 0:02.00 new'
            fi
            ;;
        rss=,pid=,comm=) printf '%s\n' '1024 12 small' '2048 13 large' ;;
        *) return 1 ;;
    esac
}
for fixture_platform in Linux Darwin; do
    [ "$(yafp_collect_top_processes rss)" = $'large\t2\t13\nsmall\t1\t12' ] || fail "RAM process ranking on $fixture_platform"
done
check_recent_macos_cpu() (
    # The sourced macOS collector calls this replacement between readings.
    # shellcheck disable=SC2317,SC2329
    sleep() {
        [ "$1" = 0.2 ] || return 1
        command sleep "$1"
        fixture_second=1
    }
    actual=$(yafp_collect_top_processes pcpu)
    expected=$'fast\t14\nbusy\t16\nmedium process\t13'
    [ "$(printf '%s\n' "$actual" | cut -f 1,3)" = "$expected" ] || fail "macOS recent CPU ranking: $actual"
    printf '%s\n' "$actual" | awk -F '\t' '$2 <= 0 { exit 1 }' || fail 'macOS CPU percentages must be positive'
)
check_recent_macos_cpu

check_recent_linux_cpu() (
    fixture_proc=$(mktemp -d)
    trap 'rm -rf -- "$fixture_proc"' EXIT
    write_process_stat() {
        local pid=$1 name=$2 user_ticks=$3 system_ticks=$4 start_ticks=$5
        mkdir -p "$fixture_proc/$pid"
        printf '%s (%s) S 0 0 0 0 0 0 0 0 0 0 %s %s 0 0 0 0 1 0 %s 0\n' \
            "$pid" "$name" "$user_ticks" "$system_ticks" "$start_ticks" > "$fixture_proc/$pid/stat"
    }
    # The sourced Linux collector calls these replacements.
    # shellcheck disable=SC2317,SC2329
    getconf() { [ "$1" = CLK_TCK ] && printf '100\n'; }
    # shellcheck disable=SC2317,SC2329
    sleep() {
        [ "$1" = 0.2 ] || return 1
        printf '100.25 0.00\n' > "$fixture_proc/uptime"
        write_process_stat 20 $'active ) (worker)\nthread' 120 25 2
        write_process_stat 30 medium 40 5 3
        write_process_stat 40 slow 13 0 4
        write_process_stat 50 reused 500 0 8
        write_process_stat 60 new 200 0 9
        rm "$fixture_proc/70/stat"
    }
    printf '100.00 0.00\n' > "$fixture_proc/uptime"
    write_process_stat 10 old 9000 0 1
    write_process_stat 20 active 100 10 2
    write_process_stat 30 medium 30 5 3
    write_process_stat 40 slow 10 0 4
    write_process_stat 50 previous 0 0 5
    write_process_stat 70 exiting 300 0 6

    expected=$'active ) (worker) thread\t140.0\t20\nmedium\t40.0\t30\nslow\t12.0\t40'
    actual=$(yafp_collect_top_cpu_linux "$fixture_proc")
    [ "$actual" = "$expected" ] || fail "Linux recent CPU ranking: $actual"
)
check_recent_linux_cpu
printf 'ok - recent Linux and macOS CPU usage and RAM process rankings\n'
