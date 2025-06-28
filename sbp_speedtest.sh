#!/usr/bin/env bash
#
# Description: Speedtest script for Saint Petersburg servers
# Author: Aleksandr Miheichev
# Version: 1.1.0 (2025-06-28)
#
# Exit on error, undefined variable, and pipeline failures
set -euo pipefail

# Set script directory for relative paths
if [[ ${BASH_SOURCE+set} == set && -n ${BASH_SOURCE[0]} ]]; then
    # запущен как файл: ./sbp_speedtest.sh
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
else
    # запущен по конвейеру:  wget … | bash
    SCRIPT_DIR="${PWD}"
fi
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/speedtest-spb"
LOG_FILE="${CACHE_DIR}/speedtest.log"
SPEEDTEST_BIN="${SCRIPT_DIR}/speedtest-cli/speedtest"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ────────── жирный шрифт, только если вывод идёт в терминал ──────────
if [[ -t 1 ]]; then
    BOLD=$(tput bold)
    NORMAL=$(tput sgr0)
else
    BOLD=""
    NORMAL=""
fi

# Logging functions
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}" >&2
}

info() { log "INFO" "${YELLOW}$1${NC}"; }
error() { log "ERROR" "${RED}$1${NC}"; exit 1; }
success() { log "SUCCESS" "${GREEN}$1${NC}"; }

# Cleanup function
cleanup() {
    local exit_code=$?
    info "Cleaning up temporary files..."
    rm -f "${SCRIPT_DIR}/speedtest.tgz"
    rm -f "${CACHE_DIR}/speedtest.tmp"
    [ -d "${SCRIPT_DIR}/speedtest-cli" ] && rm -rf "${SCRIPT_DIR}/speedtest-cli"
    
    if [ $exit_code -eq 0 ]; then
        success "Script completed successfully"
    else
        error "Script failed with exit code $exit_code"
    fi
    exit $exit_code
}

# Set up trap to call cleanup on script exit
trap cleanup EXIT INT TERM QUIT

# Create cache directory
mkdir -p "${CACHE_DIR}"

# Check for required commands
for cmd in wget awk grep tr; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        error "Required command '$cmd' not found. Please install it first."
    fi
done

_red() {
    printf '\033[0;31;31m%b\033[0m' "$1"
}

_green() {
    printf '\033[0;31;32m%b\033[0m' "$1"
}

_yellow() {
    printf '\033[0;31;33m%b\033[0m' "$1"
}

_blue() {
    printf '\033[0;31;36m%b\033[0m' "$1"
}

_exists() {
    local cmd="$1"
    if eval type type >/dev/null 2>&1; then
        eval type "$cmd" >/dev/null 2>&1
    elif command >/dev/null 2>&1; then
        command -v "$cmd" >/dev/null 2>&1
    else
        which "$cmd" >/dev/null 2>&1
    fi
}

_exit() {
    _red "\nThe script has been terminated. Cleaning up temporary files...\n"
    # clean up only existing files
    [ -f "speedtest.tgz" ] && rm -f speedtest.tgz
    [ -d "speedtest-cli" ] && rm -rf speedtest-cli
    rm -f benchtest_* 2>/dev/null
    exit 1
}

get_opsy() {
    local os_info
    
    if [ -f /etc/os-release ]; then
        os_info=$(awk -F'[="]' '/^PRETTY_NAME=/{print $3}' /etc/os-release)
    elif [ -f /etc/redhat-release ]; then
        os_info=$(</etc/redhat-release)
    elif [ -f /etc/lsb-release ]; then
        os_info=$(awk -F'[="]+' '/^DISTRIB_DESCRIPTION=/{print $2}' /etc/lsb-release)
    fi
    
    # Удаляем лишние пробелы и выводим результат
    echo "${os_info# }" | sed 's/^[ \t]*//;s/[ \t]*$//'
}

next() {
    # Создаем строку из 70 дефисов
    printf '%.0s-' {1..70}
    echo  # добавляем перевод строки
}

# Время жизни кэша в секундах (1 час)
CACHE_TTL=3600

# Получение данных из кэша
get_cached_result() {
    local server_id="$1"
    local cache_file="${CACHE_DIR}/speed_${server_id}.cache"
    
    if [ -f "$cache_file" ]; then
        local cache_age
        cache_age=$(($(date +%s) - $(stat -c %Y "$cache_file")))
        
        if [ "$cache_age" -lt "$CACHE_TTL" ]; then
            readarray -t result < "$cache_file"
            echo "${result[0]}:${result[1]}:${result[2]}"
            return 0
        fi
    fi
    return 1
}

# Сохранение в кэш
cache_result() {
    local server_id="$1"
    local dl_speed="$2"
    local up_speed="$3"
    local latency="$4"
    
    mkdir -p "$CACHE_DIR"
    printf "%s\n%s\n%s\n" "$dl_speed" "$up_speed" "$latency" > "${CACHE_DIR}/speed_${server_id}.cache"
}

# Функция тестирования скорости с кэшированием
speed_test() {
    local node_id="${1:-}"
    local node_name="$2"
    local col1_width="${3:-40}"
    local cache_key="${node_id:-default}"
    
    # Пробуем получить из кэша
    if cached_result=$(get_cached_result "$cache_key"); then
        IFS=':' read -r dl_speed up_speed latency <<< "$cached_result"
        info "Using cached results for ${node_name}"
    else
        # Выполняем тест
        info "Running speed test for ${node_name}..."
        
        local speedtest_cmd=("${SPEEDTEST_BIN}" --progress=no --accept-license --accept-gdpr)
        [ -n "$node_id" ] && speedtest_cmd+=(--server-id="$node_id")
        
        if ! "${speedtest_cmd[@]}" > "${CACHE_DIR}/speedtest.tmp" 2>&1; then
            error "Speedtest failed for ${node_name}"
        fi
        
        # Извлекаем данные из вывода
        local output
        output=$(<"${CACHE_DIR}/speedtest.tmp")
        
        # Используем один вызов awk для всех данных
        readarray -t metrics < <(awk '
            /Download:/ {print $3 " " $4}
            /Upload:/ {print $3 " " $4}
            /Latency:/ {print $3 " " $4}
        ' <<< "$output")
        
        [ "${#metrics[@]}" -lt 3 ] && error "Failed to parse speedtest output"
        
        dl_speed="${metrics[0]}"
        up_speed="${metrics[1]}"
        latency="${metrics[2]}"
        
        # Кэшируем результаты
        cache_result "$cache_key" "$dl_speed" "$up_speed" "$latency"
    fi
    
    # Выводим результаты
    printf "${YELLOW}%-${col1_width}s${GREEN}%-18s${RED}%-20s${BLUE}%-12s${NC}\n" \
        " ${node_name}" "${up_speed}" "${dl_speed}" "${latency}"
}

# Функция для вычисления максимальной длины строки в массиве
max_string_length() {
    local max=0
    local len
    
    # Используем ассоциативный массив для хранения серверов
declare -A servers=(
    ['']='Speedtest.net (Auto)'
    ['18570']='RETN Saint Petersburg'
    ['31126']='Nevalink Ltd. Saint Petersburg'
    ['16125']='Selectel Saint Petersburg'
    ['69069']='Aeza.net Saint Petersburg'
    ['21014']='P.A.K.T. LLC Saint Petersburg'
    ['4247']='MTS Saint Petersburg'
    ['6051']='t2 Russia Saint Petersburg'
    ['17039']='MegaFon Saint Petersburg'
)
    
    # Находим максимальную длину названия сервера
    for name in "${servers[@]}"; do
        len="${#name}"
        [ "$len" -gt "$max" ] && max="$len"
    done
    
    echo $((max + 2))  # Добавляем отступ для лучшей читаемости
}

speed() {
    # Используем ассоциативный массив для хранения серверов
    declare -A servers=(
        ['']='Speedtest.net (Auto)'
        ['18570']='RETN Saint Petersburg'
        ['31126']='Nevalink Ltd. Saint Petersburg'
        ['16125']='Selectel Saint Petersburg'
        ['69069']='Aeza.net Saint Petersburg'
        ['21014']='P.A.K.T. LLC Saint Petersburg'
        ['4247']='MTS Saint Petersburg'
        ['6051']='t2 Russia Saint Petersburg'
        ['17039']='MegaFon Saint Petersburg'
    )
    
    # Вычисляем максимальную длину названия сервера
    local col1_width
    col1_width=$(max_string_length)
    
    # Выводим заголовок с выравниванием по рассчитанной ширине
    printf "${YELLOW}%-${col1_width}s${GREEN}%-18s${RED}%-20s${BLUE}%-12s${NC}\n" \
        " Node Name" "Upload Speed" "Download Speed" "Latency"
    
    # Проходим по серверам в отсортированном порядке
    for server_id in "${!servers[@]}"; do
        # Пропускаем автоопределение, выведем его первым
        [ -z "$server_id" ] && continue
        speed_test "$server_id" "${servers[$server_id]}" "$col1_width"
    done
    
    # Тестируем автоопределение последним
    speed_test "" "${servers['']}" "$col1_width"
}

io_test() {
    (LANG=C dd if=/dev/zero of=benchtest_$$ bs=512k count="$1" conv=fdatasync && rm -f benchtest_$$) 2>&1 | awk -F '[,，]' '{io=$NF} END { print io}' | sed 's/^[ \t]*//;s/[ \t]*$//'
}

calc_size() {
    local raw=$1
    local total_size=0
    local num=1
    local unit="KB"
    if ! [[ ${raw} =~ ^[0-9]+$ ]]; then
        echo ""
        return
    fi
    if [ "${raw}" -ge 1073741824 ]; then
        num=1073741824
        unit="TB"
    elif [ "${raw}" -ge 1048576 ]; then
        num=1048576
        unit="GB"
    elif [ "${raw}" -ge 1024 ]; then
        num=1024
        unit="MB"
    elif [ "${raw}" -eq 0 ]; then
        echo "${total_size}"
        return
    fi
    total_size=$(awk 'BEGIN{printf "%.1f", '"$raw"' / '$num'}')
    echo "${total_size} ${unit}"
}

# since calc_size converts kilobyte to MB, GB and TB
# to_kibyte converts zfs size from bytes to kilobyte
to_kibyte() {
    local raw=$1
    awk 'BEGIN{printf "%.0f", '"$raw"' / 1024}'
}

calc_sum() {
    local arr=("$@")
    local s
    s=0
    for i in "${arr[@]}"; do
        s=$((s + i))
    done
    echo ${s}
}

check_virt() {
    _exists "dmesg" && virtualx="$(dmesg 2>/dev/null)"
    if _exists "dmidecode"; then
        sys_manu="$(dmidecode -s system-manufacturer 2>/dev/null)"
        sys_product="$(dmidecode -s system-product-name 2>/dev/null)"
        sys_ver="$(dmidecode -s system-version 2>/dev/null)"
    else
        sys_manu=""
        sys_product=""
        sys_ver=""
    fi
    if grep -qa docker /proc/1/cgroup; then
        virt="Docker"
    elif grep -qa lxc /proc/1/cgroup; then
        virt="LXC"
    elif grep -qa container=lxc /proc/1/environ; then
        virt="LXC"
    elif [[ -f /proc/user_beancounters ]]; then
        virt="OpenVZ"
    elif [[ "${virtualx}" == *kvm-clock* ]]; then
        virt="KVM"
    elif [[ "${sys_product}" == *KVM* ]]; then
        virt="KVM"
    elif [[ "${sys_manu}" == *QEMU* ]]; then
        virt="KVM"
    elif [[ "${cname}" == *KVM* ]]; then
        virt="KVM"
    elif [[ "${cname}" == *QEMU* ]]; then
        virt="KVM"
    elif [[ "${virtualx}" == *"VMware Virtual Platform"* ]]; then
        virt="VMware"
    elif [[ "${sys_product}" == *"VMware Virtual Platform"* ]]; then
        virt="VMware"
    elif [[ "${virtualx}" == *"Parallels Software International"* ]]; then
        virt="Parallels"
    elif [[ "${virtualx}" == *VirtualBox* ]]; then
        virt="VirtualBox"
    elif [[ -e /proc/xen ]]; then
        if grep -q "control_d" "/proc/xen/capabilities" 2>/dev/null; then
            virt="Xen-Dom0"
        else
            virt="Xen-DomU"
        fi
    elif [ -f "/sys/hypervisor/type" ] && grep -q "xen" "/sys/hypervisor/type"; then
        virt="Xen"
    elif [[ "${sys_manu}" == *"Microsoft Corporation"* ]]; then
        if [[ "${sys_product}" == *"Virtual Machine"* ]]; then
            if [[ "${sys_ver}" == *"7.0"* || "${sys_ver}" == *"Hyper-V" ]]; then
                virt="Hyper-V"
            else
                virt="Microsoft Virtual Machine"
            fi
        fi
    else
        virt="Dedicated"
    fi
}

ipv4_info() {
    local org city country region
    org="$(wget -q -T10 -O- http://ipinfo.io/org)"
    city="$(wget -q -T10 -O- http://ipinfo.io/city)"
    country="$(wget -q -T10 -O- http://ipinfo.io/country)"
    region="$(wget -q -T10 -O- http://ipinfo.io/region)"
    if [[ -n "${org}" ]]; then
        echo " Organization       : $(_blue "${org}")"
    fi
    if [[ -n "${city}" && -n "${country}" ]]; then
        echo " Location           : $(_blue "${city} / ${country}")"
    fi
    if [[ -n "${region}" ]]; then
        echo " Region             : $(_yellow "${region}")"
    fi
    if [[ -z "${org}" ]]; then
        echo " Region             : $(_red "No ISP detected")"
    fi
}

install_speedtest() {
    if [ ! -e "./speedtest-cli/speedtest" ]; then
        sys_bit=""
        local sysarch
        sysarch="$(uname -m)"
        if [ "${sysarch}" = "unknown" ] || [ "${sysarch}" = "" ]; then
            sysarch="$(arch)"
        fi
        if [ "${sysarch}" = "x86_64" ]; then
            sys_bit="x86_64"
        fi
        if [ "${sysarch}" = "i386" ] || [ "${sysarch}" = "i686" ]; then
            sys_bit="i386"
        fi
        if [ "${sysarch}" = "armv8" ] || [ "${sysarch}" = "armv8l" ] || [ "${sysarch}" = "aarch64" ] || [ "${sysarch}" = "arm64" ]; then
            sys_bit="aarch64"
        fi
        if [ "${sysarch}" = "armv7" ] || [ "${sysarch}" = "armv7l" ]; then
            sys_bit="armhf"
        fi
        if [ "${sysarch}" = "armv6" ]; then
            sys_bit="armel"
        fi
        [ -z "${sys_bit}" ] && _red "Error: Unsupported system architecture (${sysarch}).\n" && exit 1
        url1="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-${sys_bit}.tgz"
        url2="https://dl.lamp.sh/files/ookla-speedtest-1.2.0-linux-${sys_bit}.tgz"
        if wget --no-check-certificate -q -T10 -O speedtest.tgz "${url1}" || 
           wget --no-check-certificate -q -T10 -O speedtest.tgz "${url2}"; then
            if ! mkdir -p speedtest-cli || 
               ! tar zxf speedtest.tgz -C ./speedtest-cli || 
               ! chmod +x ./speedtest-cli/speedtest; then
                _red "Error: Failed to extract or set permissions for speedtest-cli.\n"
                rm -f speedtest.tgz
                exit 1
            fi
            rm -f speedtest.tgz
        else
            _red "Error: Failed to download speedtest-cli from all mirrors.\n"
            exit 1
        fi
    fi
    printf "%-40s%-18s%-20s%-12s\n" " Node Name" "Upload Speed" "Download Speed" "Latency"
}

print_intro() {
    local border
    # Создаем строку из 70 дефисов
    printf -v border '%.0s-' {1..70}
    
    echo "${border}"
    echo "  ${BOLD}Speedtest for Saint Petersburg Servers${NORMAL}"
    echo "  Version: ${GREEN}v1.1.0${NC} (2025-06-28)"
    echo "  Usage:   ${BLUE}curl -sL https://git.io/speedtest-spb | bash${NC}"
    echo "  Source:  ${BLUE}https://github.com/aleksandr-miheichev/speedtest-Saint-Petersburg${NC}"
    echo "  Cache:   ${YELLOW}${CACHE_DIR}${NC}"
    echo "${border}"
}

# Get System information
get_system_info() {
    cname=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
    cores=$(awk -F: '/^processor/ {core++} END {print core}' /proc/cpuinfo)
    freq=$(awk -F'[ :]' '/cpu MHz/ {print $4;exit}' /proc/cpuinfo)
    ccache=$(awk -F: '/cache size/ {cache=$2} END {print cache}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
    cpu_aes=$(grep -i 'aes' /proc/cpuinfo)
    cpu_virt=$(grep -Ei 'vmx|svm' /proc/cpuinfo)
    tram=$(
        LANG=C
        free | awk '/Mem/ {print $2}'
    )
    tram=$(calc_size "$tram")
    uram=$(
        LANG=C
        free | awk '/Mem/ {print $3}'
    )
    uram=$(calc_size "$uram")
    swap=$(
        LANG=C
        free | awk '/Swap/ {print $2}'
    )
    swap=$(calc_size "$swap")
    uswap=$(
        LANG=C
        free | awk '/Swap/ {print $3}'
    )
    uswap=$(calc_size "$uswap")
    up=$(awk '{a=$1/86400;b=($1%86400)/3600;c=($1%3600)/60} {printf("%d days, %d hour %d min\n",a,b,c)}' /proc/uptime)
    load="N/A"
    if _exists "w"; then
        load=$(LANG=C w 2>/dev/null | awk -F'load average:' '/load/ {print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//')
    elif _exists "uptime"; then
        load=$(LANG=C uptime 2>/dev/null | awk -F'load average:' '/load/ {print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//')
    fi
    opsy=$(get_opsy)
    arch=$(uname -m)
    if _exists "getconf"; then
        lbit=$(getconf LONG_BIT)
    else
        echo "${arch}" | grep -q "64" && lbit="64" || lbit="32"
    fi
    kern=$(uname -r)
    in_kernel_no_swap_total_size=$(
        LANG=C
        df -t simfs -t ext2 -t ext3 -t ext4 -t btrfs -t xfs -t vfat -t ntfs --total 2>/dev/null | grep total | awk '{ print $2 }'
    )
    swap_total_size=$(free -k | grep Swap | awk '{print $2}')
    zfs_total_size=$(to_kibyte "$(calc_sum "$(zpool list -o size -Hp 2> /dev/null)")")
    disk_total_size=$(calc_size $((swap_total_size + in_kernel_no_swap_total_size + zfs_total_size)))
    in_kernel_no_swap_used_size=$(
        LANG=C
        df -t simfs -t ext2 -t ext3 -t ext4 -t btrfs -t xfs -t vfat -t ntfs --total 2>/dev/null | grep total | awk '{ print $3 }'
    )
    swap_used_size=$(free -k | grep Swap | awk '{print $3}')
    zfs_used_size=$(to_kibyte "$(calc_sum "$(zpool list -o allocated -Hp 2> /dev/null)")")
    disk_used_size=$(calc_size $((swap_used_size + in_kernel_no_swap_used_size + zfs_used_size)))
    tcpctrl=$(sysctl net.ipv4.tcp_congestion_control | awk -F ' ' '{print $3}')
}
# Print System information
print_system_info() {
    if [ -n "$cname" ]; then
        echo " CPU Model          : $(_blue "$cname")"
    else
        echo " CPU Model          : $(_blue "CPU model not detected")"
    fi
    if [ -n "$freq" ]; then
        echo " CPU Cores          : $(_blue "$cores @ $freq MHz")"
    else
        echo " CPU Cores          : $(_blue "$cores")"
    fi
    if [ -n "$ccache" ]; then
        echo " CPU Cache          : $(_blue "$ccache")"
    fi
    if [ -n "$cpu_aes" ]; then
        echo " AES-NI             : $(_green "\xe2\x9c\x93 Enabled")"
    else
        echo " AES-NI             : $(_red "\xe2\x9c\x97 Disabled")"
    fi
    if [ -n "$cpu_virt" ]; then
        echo " VM-x/AMD-V         : $(_green "\xe2\x9c\x93 Enabled")"
    else
        echo " VM-x/AMD-V         : $(_red "\xe2\x9c\x97 Disabled")"
    fi
    echo " Total Disk         : $(_yellow "$disk_total_size") $(_blue "($disk_used_size Used)")"
    echo " Total Mem          : $(_yellow "$tram") $(_blue "($uram Used)")"
    if [ "$swap" != "0" ]; then
        echo " Total Swap         : $(_blue "$swap ($uswap Used)")"
    fi
    echo " System uptime      : $(_blue "$up")"
    echo " Load average       : $(_blue "$load")"
    echo " OS                 : $(_blue "$opsy")"
    echo " Arch               : $(_blue "$arch ($lbit Bit)")"
    echo " Kernel             : $(_blue "$kern")"
    echo " TCP CC             : $(_yellow "$tcpctrl")"
    echo " Virtualization     : $(_blue "$virt")"
    echo " IPv4/IPv6          : $online"
}

print_io_test() {
    freespace=$(df -m . | awk 'NR==2 {print $4}')
    if [ -z "${freespace}" ]; then
        freespace=$(df -m . | awk 'NR==3 {print $3}')
    fi
    if [ "${freespace}" -gt 1024 ]; then
        writemb=2048
        io1=$(io_test ${writemb})
        echo " I/O Speed(1st run) : $(_yellow "$io1")"
        io2=$(io_test ${writemb})
        echo " I/O Speed(2nd run) : $(_yellow "$io2")"
        io3=$(io_test ${writemb})
        echo " I/O Speed(3rd run) : $(_yellow "$io3")"
        ioraw1=$(echo "$io1" | awk 'NR==1 {print $1}')
        [[ "$(echo "$io1" | awk 'NR==1 {print $2}')" == "GB/s" ]] && ioraw1=$(awk 'BEGIN{print '"$ioraw1"' * 1024}')
        ioraw2=$(echo "$io2" | awk 'NR==1 {print $1}')
        [[ "$(echo "$io2" | awk 'NR==1 {print $2}')" == "GB/s" ]] && ioraw2=$(awk 'BEGIN{print '"$ioraw2"' * 1024}')
        ioraw3=$(echo "$io3" | awk 'NR==1 {print $1}')
        [[ "$(echo "$io3" | awk 'NR==1 {print $2}')" == "GB/s" ]] && ioraw3=$(awk 'BEGIN{print '"$ioraw3"' * 1024}')
        ioall=$(awk 'BEGIN{print '"$ioraw1"' + '"$ioraw2"' + '"$ioraw3"'}')
        ioavg=$(awk 'BEGIN{printf "%.1f", '"$ioall"' / 3}')
        echo " I/O Speed(average) : $(_yellow "$ioavg MB/s")"
    else
        echo " $(_red "Not enough space for I/O Speed test!")"
    fi
}

print_end_time() {
    end_time=$(date +%s)
    time=$((end_time - start_time))
    if [ ${time} -gt 60 ]; then
        min=$((time / 60))
        sec=$((time % 60))
        echo " Finished in        : ${min} min ${sec} sec"
    else
        echo " Finished in        : ${time} sec"
    fi
    date_time=$(date '+%Y-%m-%d %H:%M:%S %Z')
    echo " Timestamp          : $date_time"
}

! _exists "wget" && _red "Error: wget command not found.\n" && exit 1
! _exists "free" && _red "Error: free command not found.\n" && exit 1
# check for curl/wget
_exists "curl" && local_curl=true
# test if the host has IPv4/IPv6 connectivity
[[ -n ${local_curl} ]] && ip_check_cmd="curl -s -m 4" || ip_check_cmd="wget -qO- -T 4"
ipv4_check=$( (ping -4 -c 1 -W 4 ipv4.google.com >/dev/null 2>&1 && echo true) || ${ip_check_cmd} -4 icanhazip.com 2> /dev/null)
ipv6_check=$( (ping -6 -c 1 -W 4 ipv6.google.com >/dev/null 2>&1 && echo true) || ${ip_check_cmd} -6 icanhazip.com 2> /dev/null)
if [[ -z "$ipv4_check" && -z "$ipv6_check" ]]; then
    _yellow "Warning: Both IPv4 and IPv6 connectivity were not detected.\n"
fi
[[ -z "$ipv4_check" ]] && online="$(_red "\xe2\x9c\x97 Offline")" || online="$(_green "\xe2\x9c\x93 Online")"
[[ -z "$ipv6_check" ]] && online+=" / $(_red "\xe2\x9c\x97 Offline")" || online+=" / $(_green "\xe2\x9c\x93 Online")"
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
