#!/usr/bin/env bash
# Local probes; this file runs only inside the worker.
export LC_ALL=C

yafp_collect_memory_macos() {
    local total pages swap
    total=$(sysctl -n hw.memsize 2>/dev/null) || return
    pages=$(vm_stat 2>/dev/null) || return
    printf '%s\n' "$pages" | awk -v total="$total" '
        /page size of/ { size=$8 }
        /Pages free:/ { free=$3+0 }
        /Pages inactive:/ { inactive=$3+0 }
        /Pages speculative:/ { speculative=$3+0 }
        END { if (size > 0 && total > 0)
            printf "%.0f %.0f\n", (total-(free+inactive+speculative)*size)/1048576, total/1048576 }
    '
    swap=$(sysctl -n vm.swapusage 2>/dev/null) || return
    printf '%s\n' "$swap" | awk '
        function mib(value, unit) {
            unit=substr(value,length(value)); value+=0
            if (unit=="G") return value*1024
            if (unit=="K") return value/1024
            if (unit=="T") return value*1048576
            return value
        }
        /total =/ { printf "%.0f %.0f\n", mib($6), mib($3) }
    '
}

yafp_collect_memory_linux() {
    awk '
        /^MemTotal:/ { total=$2 }
        /^MemAvailable:/ { available=$2; found=1 }
        /^SwapTotal:/ { swap=$2 }
        /^SwapFree:/ { swapfree=$2 }
        END {
            if (total>0 && found) printf "%.0f %.0f\n", (total-available)/1024, total/1024
            else print "- -"
            printf "%.0f %.0f\n", (swap-swapfree)/1024, swap/1024
        }
    ' /proc/meminfo 2>/dev/null
}

yafp_collect_cpu_linux() {
    local first second
    first=$(head -n 1 /proc/stat) || return
    sleep 0.2
    second=$(head -n 1 /proc/stat) || return
    printf '%s\n%s\n' "$first" "$second" | awk '
        { total=0; for(i=2;i<=9;i++) total+=$i; idle=$5+$6 }
        NR==1 { previous=total; previousidle=idle }
        END { delta=total-previous; if(delta>0)
            printf "%.0f\n", 100*(delta-idle+previousidle)/delta }
    '
}

yafp_collect_resources() {
    local platform memory cpu disk
    local ram_used=- ram_total=- swap_used=- swap_total=- disk_used=- disk_total=-
    platform=$(uname -s)
    case "$platform" in
        Darwin)
            memory=$(yafp_collect_memory_macos)
            # The second sample avoids the average since boot.
            cpu=$(top -l 2 -s 1 -n 0 2>/dev/null | awk '
                /CPU usage:/ { idle=$7; found=1 }
                END { if(found) printf "%.0f\n", 100-idle }
            ')
            ;;
        Linux)
            memory=$(yafp_collect_memory_linux)
            cpu=$(yafp_collect_cpu_linux)
            ;;
        *) memory=''; cpu=- ;;
    esac
    {
        IFS=' ' read -r ram_used ram_total
        IFS=' ' read -r swap_used swap_total
    } <<< "$memory"
    # The HOME volume includes user data on APFS.
    disk=$(df -Pk "${2:-$HOME}" 2>/dev/null | awk 'NR==2 { print $3, $2 }')
    IFS=' ' read -r disk_used disk_total <<< "$disk"
    printf '%s %s %s %s %s %s %s %s\n' "$1" \
        "${ram_used:--}" "${ram_total:--}" "${swap_used:--}" \
        "${swap_total:--}" "${cpu:--}" "${disk_used:--}" "${disk_total:--}"
}

yafp_linux_process_snapshot() {
    local proc_dir=$1 uptime path stat name pid
    local fields=()
    IFS=' ' read -r uptime _ < "$proc_dir/uptime" || return
    printf 'uptime\t%s\n' "$uptime"
    for path in "$proc_dir"/[0-9]*/stat; do
        stat=''
        # The process name can contain spaces, parentheses, and newlines.
        { IFS= read -r -d '' stat < "$path"; } 2>/dev/null || true
        [[ "$stat" == *') '* ]] || continue
        pid=${stat%% *}
        name=${stat#*' ('}
        name=${name%') '*}
        name=${name//[[:cntrl:]]/ }
        IFS=' ' read -r -a fields <<< "${stat##*') '}"
        [ "${#fields[@]}" -ge 20 ] || continue
        # After the name, field 3 (state) has index 0. Read utime, stime, and starttime.
        printf '%s\t%s\t%s\t%s\t%s\n' "$pid" "${fields[11]}" "${fields[12]}" "${fields[19]}" "$name"
    done
}

yafp_collect_top_cpu_linux() {
    local proc_dir=${1:-/proc} ticks_per_second first second
    ticks_per_second=$(getconf CLK_TCK 2>/dev/null) || return 0
    case "$ticks_per_second" in ''|0|*[!0-9]*) return 0 ;; esac
    first=$(yafp_linux_process_snapshot "$proc_dir") || return 0
    sleep 0.2 || return 0
    second=$(yafp_linux_process_snapshot "$proc_dir") || return 0
    printf '%s\n' "$first" "$second" | awk -F '\t' -v ticks_per_second="$ticks_per_second" '
        $1 == "uptime" {
            if (++sample == 1) started=$2
            else elapsed=$2-started
            next
        }
        sample == 1 { start[$1]=$4; ticks[$1]=$2+$3; next }
        sample == 2 && elapsed > 0 && ($1 in start) && start[$1] == $4 {
            delta=$2+$3-ticks[$1]
            if (delta >= 0) printf "%.9f\t%s\t%s\n", 100*delta/(elapsed*ticks_per_second), $1, $5
        }
    ' | sort -t $'\t' -k1,1nr -k2,2n | awk -F '\t' 'NR <= 3 { printf "%s\t%.1f\t%s\n", $3, $1, $2 }'
}

yafp_collect_top_cpu_macos() {
    local first second elapsed
    first=$(ps -axo pid=,lstart=,time=,comm= 2>/dev/null) || return 0
    second=$(
        TIMEFORMAT='%R'
        { time { sleep 0.2 && ps -axo pid=,lstart=,time=,comm= 2>/dev/null; }; } 2>&1
    ) || return 0
    elapsed=${second##*$'\n'}
    printf '%s\n--\n%s\n' "$first" "${second%$'\n'*}" | awk -v elapsed="$elapsed" '
        $0 == "--" { second=1; next }
        NF >= 8 && $1 ~ /^[0-9]+$/ && $1 > 0 && $7 ~ /^[0-9]+:[0-9][0-9][.][0-9][0-9]$/ {
            identity=$1 SUBSEP $2 SUBSEP $3 SUBSEP $4 SUBSEP $5 SUBSEP $6
            split($7, cpu, ":")
            seconds=60*cpu[1]+cpu[2]
            if (!second) { previous[identity]=seconds; next }
            if (elapsed <= 0 || !(identity in previous) || seconds < previous[identity]) next
            name=$0
            for (field=1; field<=7; field++) sub(/^[[:space:]]*[^[:space:]]+/, "", name)
            sub(/^[[:space:]]+/, "", name)
            sub(/^.*\//, "", name)
            gsub(/[[:cntrl:]]/, " ", name)
            printf "%.9f\t%s\t%s\n", 100*(seconds-previous[identity])/elapsed, $1, name
        }
    ' | sort -t $'\t' -k1,1nr -k2,2n | awk -F '\t' 'NR <= 3 { printf "%s\t%.1f\t%s\n", $3, $1, $2 }'
}

yafp_collect_top_processes() {
    local metric=$1 platform
    platform=$(uname -s)
    case "$platform:$metric" in
        Linux:pcpu) yafp_collect_top_cpu_linux ;;
        Darwin:pcpu) yafp_collect_top_cpu_macos ;;
        Darwin:rss|Linux:rss)
            ps -axo "$metric=,pid=,comm=" 2>/dev/null | awk '
                NF >= 3 && $1 ~ /^[0-9]+([.][0-9]+)?$/ && $2 ~ /^[0-9]+$/ && $2 > 0 {
                    name=$0
                    sub(/^[[:space:]]*[0-9.]+[[:space:]]+[0-9]+[[:space:]]+/, "", name)
                    sub(/^.*\//, "", name)
                    gsub(/[\t]/, " ", name)
                    if (name != "ps") printf "%s\t%s\t%s\n", $1, $2, name
                }
            ' | sort -t $'\t' -k1,1nr | awk -F '\t' '
                NR <= 3 { printf "%s\t%.0f\t%s\n", $3, $1/1024, $2 }
            '
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    # Atomic publication; cache contents are never executed.
    umask 077
    yafp_collect_resources "$2" "$3" > "$1.tmp" && mv -f -- "$1.tmp" "$1"
    yafp_collect_top_processes rss > "$1.processes.tmp" && mv -f -- "$1.processes.tmp" "$1.processes"
    yafp_collect_top_processes pcpu > "$1.cpu-processes.tmp" && mv -f -- "$1.cpu-processes.tmp" "$1.cpu-processes"
fi
