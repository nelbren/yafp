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

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    # Atomic publication; cache contents are never executed.
    umask 077
    yafp_collect_resources "$2" "$3" > "$1.tmp" && mv -f -- "$1.tmp" "$1"
fi
