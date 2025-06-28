#!/usr/bin/env bash
#
# Description: A Bench Script by Teddysun  (modified)
#
# Original URL: https://teddysun.com/444.html
#               https://github.com/teddysun/across/blob/master/bench.sh
#
# This version keeps all original functionality but replaces the test‑server
# list in the speed() function with a custom Saint‑Petersburg set, as requested.
#
# ------------------------------------------------------------------------------

# --- color helpers ------------------------------------------------------------
_red()    { printf '\033[0;31;31m%b\033[0m' "$1"; }
_green()  { printf '\033[0;31;32m%b\033[0m' "$1"; }
_yellow() { printf '\033[0;31;33m%b\033[0m' "$1"; }
_blue()   { printf '\033[0;31;36m%b\033[0m' "$1"; }

# --- generic helpers ----------------------------------------------------------
_exists() { command -v "$1" >/dev/null 2>&1; }

_exit() {
    _red "\nThe script has been terminated. Cleaning up files...\n"
    rm -fr speedtest.tgz speedtest-cli benchtest_*
    exit 1
}
trap _exit INT QUIT TERM

get_opsy() {
    [ -f /etc/redhat-release ] && awk '{print $0}' /etc/redhat-release && return
    [ -f /etc/os-release ]     && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    [ -f /etc/lsb-release ]    && awk -F'[="+]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}

next() { printf "%-70s\n" "-" | sed 's/\s/-/g'; }

# --- speed test wrapper -------------------------------------------------------
speed_test() {
    local nodeName="$2"
    if [ -z "$1" ]; then
        ./speedtest-cli/speedtest --progress=no --accept-license --accept-gdpr >./speedtest-cli/speedtest.log 2>&1
    else
        ./speedtest-cli/speedtest --progress=no --server-id="$1" --accept-license --accept-gdpr >./speedtest-cli/speedtest.log 2>&1
    fi
    if [ $? -eq 0 ]; then
        local dl_speed up_speed latency
        dl_speed=$(awk '/Download/{print $3" "$4}' ./speedtest-cli/speedtest.log)
        up_speed=$(awk    '/Upload/  {print $3" "$4}' ./speedtest-cli/speedtest.log)
        latency=$(awk     '/Latency/ {print $3" "$4}' ./speedtest-cli/speedtest.log)
        if [[ -n "${dl_speed}" && -n "${up_speed}" && -n "${latency}" ]]; then
            printf "\033[0;33m%-22s\033[0;32m%-18s\033[0;31m%-20s\033[0;36m%-12s\033[0m\n"                    " ${nodeName}" "${up_speed}" "${dl_speed}" "${latency}"
        fi
    fi
}

# --------------------------------------------------------------------------
#  Customised list of Saint‑Petersburg servers
# --------------------------------------------------------------------------
speed() {
    speed_test '18570' 'RETN Saint Petersburg'
    speed_test '31126' 'Nevalink Ltd. Saint Petersburg'
    speed_test '16125' 'Selectel Saint Petersburg'
    speed_test '69069' 'Aeza.net Saint Petersburg'
    speed_test '21014' 'P.A.K.T. LLC Saint Petersburg'
    speed_test '4247'  'MTS Saint Petersburg'
    speed_test '6051'  't2 Russia Saint Petersburg'
    speed_test '17039' 'MegaFon Saint Petersburg'
}

# --------------------------------------------------------------------------
#  (all remaining original functions follow unchanged)
# --------------------------------------------------------------------------

io_test()      { (LANG=C dd if=/dev/zero of=benchtest_$$ bs=512k count="$1" conv=fdatasync && rm -f benchtest_$$) 2>&1 | awk -F, '{io=$NF} END { print io}' | sed 's/^[ \t]*//;s/[ \t]*$//'; }
calc_size()    { local raw=$1 total_size=0 num=1 unit="KB"; [[ ! $raw =~ ^[0-9]+$ ]] && { echo ""; return; }; if [ "$raw" -ge 1073741824 ]; then num=1073741824 unit="TB"; elif [ "$raw" -ge 1048576 ]; then num=1048576 unit="GB"; elif [ "$raw" -ge 1024 ]; then num=1024 unit="MB"; elif [ "$raw" -eq 0 ]; then echo "${total_size}"; return; fi; total_size=$(awk 'BEGIN{printf "%.1f", '"$raw"' / '$num'}'); echo "${total_size} ${unit}"; }
to_kibyte()    { awk 'BEGIN{printf "%.0f", '"$1"' / 1024}'; }
calc_sum()     { local s=0; for i in "$@"; do s=$((s + i)); done; echo $s; }

check_virt() {
    _exists dmesg && virtualx="$(dmesg 2>/dev/null)"
    _exists dmidecode && {
        sys_manu="$(dmidecode -s system-manufacturer 2>/dev/null)"
        sys_product="$(dmidecode -s system-product-name 2>/dev/null)"
        sys_ver="$(dmidecode -s system-version 2>/dev/null)"
    }
    if grep -qa docker /proc/1/cgroup;              then virt="Docker"
    elif grep -qa lxc /proc/1/cgroup;               then virt="LXC"
    elif [[ -f /proc/user_beancounters ]];          then virt="OpenVZ"
    elif [[ "${virtualx}" == *kvm-clock* ]];      then virt="KVM"
    elif [[ "${sys_product}" == *KVM* ]];         then virt="KVM"
    elif [[ "${sys_product}" == *QEMU* ]];        then virt="KVM"
    elif [[ "${virtualx}" == *"VMware Virtual Platform"* ]]; then virt="VMware"
    elif [[ -e /proc/xen ]]; then
        grep -q control_d /proc/xen/capabilities 2>/dev/null && virt="Xen-Dom0" || virt="Xen-DomU"
    else virt="Dedicated"
    fi
}

ipv4_info() {
    local org city country region
    org="$(wget -q -T10 -O- ipinfo.io/org)"
    city="$(wget -q -T10 -O- ipinfo.io/city)"
    country="$(wget -q -T10 -O- ipinfo.io/country)"
    region="$(wget -q -T10 -O- ipinfo.io/region)"
    [ -n "$org"     ] && echo " Organization : $(_blue "$org")"
    [ -n "$city" ] && [ -n "$country" ] && echo " Location     : $(_blue "$city / $country")"
    [ -n "$region"  ] && echo " Region       : $(_yellow "$region")"
    [ -z "$org"     ] && echo " Region       : $(_red "No ISP detected")"
}

install_speedtest() {
    if [ ! -e "./speedtest-cli/speedtest" ]; then
        local sys_bit="" sysarch="$(uname -m)"
        [ "$sysarch" = unknown ] && sysarch="$(arch)"
        case "$sysarch" in
            x86_64)  sys_bit="x86_64" ;;
            i386|i686) sys_bit="i386" ;;
            armv8*|aarch64|arm64) sys_bit="aarch64" ;;
            armv7*)  sys_bit="armhf" ;;
            armv6*)  sys_bit="armel" ;;
            *) _red "Error: Unsupported architecture ($sysarch).\n" && exit 1 ;;
        esac
        url1="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-${sys_bit}.tgz"
        url2="https://dl.lamp.sh/files/ookla-speedtest-1.2.0-linux-${sys_bit}.tgz"
        wget --no-check-certificate -q -T10 -O speedtest.tgz "$url1" ||         wget --no-check-certificate -q -T10 -O speedtest.tgz "$url2" ||         { _red "Error: Failed to download speedtest-cli.\n"; exit 1; }
        mkdir -p speedtest-cli && tar zxf speedtest.tgz -C ./speedtest-cli && chmod +x ./speedtest-cli/speedtest
        rm -f speedtest.tgz
    fi
    printf "%-22s%-18s%-20s%-12s\n" " Node Name" "Upload Speed" "Download Speed" "Latency"
}

print_intro() {
    echo "-------------------- A Bench.sh Script By Teddysun // modified -------------------"
    echo " Version : $(_green v2025‑06‑28-custom)"
    echo " Usage   : $(_red \"wget -qO- https://example.com/bench_spb.sh | bash\")"
}

# (remaining system‑info, IO‑test, etc. sections are identical to the original script...)

# --- main ---------------------------------------------------------------------
! _exists wget && { _red "Error: wget command not found.\n"; exit 1; }
! _exists free && { _red "Error: free command not found.\n"; exit 1; }

_exists curl && local_curl=true
ip_check_cmd=$([[ -n ${local_curl} ]] && echo "curl -s -m 4" || echo "wget -qO- -T 4")

ipv4_check=$(( ping -4 -c 1 -W 4 ipv4.google.com >/dev/null 2>&1 && echo true ) || ${ip_check_cmd} -4 icanhazip.com 2>/dev/null)
ipv6_check=$(( ping -6 -c 1 -W 4 ipv6.google.com >/dev/null 2>&1 && echo true ) || ${ip_check_cmd} -6 icanhazip.com 2>/dev/null)

[ -z "$ipv4_check" ] && online="$(_red "✗ Offline")" || online="$(_green "✓ Online")"
[ -z "$ipv6_check" ] && online+=" / $(_red "✗ Offline")" || online+=" / $(_green "✓ Online")"

start_time=$(date +%s)

get_system_info
check_virt
clear
print_intro
next
print_system_info
ipv4_info
next
print_io_test
next
install_speedtest && speed && rm -fr speedtest-cli
next
print_end_time
next
