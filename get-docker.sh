#!/usr/bin/env bash
#
# Description: Installs the latest Docker CE on supported Linux distributions.
#
# Copyright (c) 2023 - 2025 honeok <honeok@duck.com>
#
# Licensed under the GNU General Public License, version 2 only.
# This program is distributed WITHOUT ANY WARRANTY.
# See <https://www.gnu.org/licenses/old-licenses/gpl-2.0.html>.

# 当前脚本版本号
readonly VERSION='v0.1.4 (2025.03.31)'

red='\033[91m'
green='\033[92m'
yellow='\033[93m'
purple='\033[95m'
cyan='\033[96m'
white='\033[0m'
function _red { echo -e "${red}$*${white}"; }
function _green { echo -e "${green}$*${white}"; }
function _yellow { echo -e "${yellow}$*${white}"; }
function _purple { echo -e "${purple}$*${white}"; }
function _cyan { echo -e "${cyan}$*${white}"; }

function _err_msg { echo -e "\033[41m\033[1mError${white} $*"; }
function _suc_msg { echo -e "\033[42m\033[1mSuccess${white} $*"; }
function _info_msg { echo -e "\033[43m\033[1mTis${white} $*"; }

# 各变量默认值
getdocker_pid='/tmp/getdocker.pid'
os_info=$(grep "^PRETTY_NAME=" /etc/*-release | cut -d '"' -f 2 | sed 's/ (.*)//')
os_name=$(grep "^ID=" /etc/*-release | awk -F'=' '{print $2}' | sed 's/"//g')
script_url='https://github.com/honeok/Tools/raw/master/get-docker.sh'
ua_browser='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36'

if [ -f "$getdocker_pid" ] && kill -0 "$(cat "$getdocker_pid")" 2>/dev/null; then
    _err_msg "$(_red 'The script seems to be running, please do not run it again!')" && exit 1
fi

function _exit {
    local return_value="$?"

    [ -f "$getdocker_pid" ] && rm -f "$getdocker_pid" 2>/dev/null
    exit "$return_value"
}

trap '_exit' SIGINT SIGQUIT SIGTERM EXIT

echo $$ > "$getdocker_pid"

# Logo generation from: https://www.lddgo.net/string/text-to-ascii-art (Small Slant)
function show_logo {
    echo -e "$yellow  _____    __     __        __ 
 / ______ / /____/ ___ ____/ /_____ ____
/ (_ / -_/ __/ _  / _ / __/  '_/ -_/ __/
\___/\__/\__/\_,_/\___\__/_/\_\\__/_/
"
    printf "\n"
    _green " System   : $os_info"
    echo "$(_green " Version  : $VERSION") $(_purple '\xF0\x9F\x90\xB3')"
    echo " $(_cyan bash <(curl -sL "$script_url"))"
    printf "\n"
}

function _exists {
    local _cmd="$1"
    if type "$_cmd" >/dev/null 2>&1; then
        return 0
    elif command -v "$_cmd" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

function runtime_count {
    local runcount
    runcount=$(curl -fskL -m 3 --retry 1 "https://hits.611611611.xyz/get-docker?action=hit&title=hits&title_bg=%23555555&count_bg=%2342bd14&edge_flat=false")
    today=$(echo "$runcount" | grep '"daily"' | sed 's/.*"daily": *\([0-9]*\).*/\1/')
    total=$(echo "$runcount" | grep '"total"' | sed 's/.*"total": *\([0-9]*\).*/\1/')
}

function end_message {
    local current_time
    current_time=$(date '+%Y-%m-%d %H:%M:%S %Z')

    runtime_count
    _green "Current server time: $current_time Script execution completed."
    _purple 'Thank you for using this script! If you have any questions, please visit https://www.honeok.com get more information.'
    if [ -n "$today" ] && [ -n "$total" ]; then
        _yellow "Number of script runs today: $today total number of script runs: $total"
    fi
}

function pre_check {
    # 备用 www.qualcomm.cn
    cloudflare_api='www.garmin.com.cn'

    if [ "$(id -ru)" -ne 0 ] || [ "$EUID" -ne 0 ]; then
        _err_msg "$(_red 'This script must be run as root!')" && exit 1
    fi
    if [ "$(ps -p $$ -o comm=)" != "bash" ] || readlink /proc/$$/exe | grep -q "dash"; then
        _err_msg "$(_red 'This script needs to be run with bash, not sh!')" && exit 1
    fi
    _LOC=$(curl -A "$ua_browser" -fskL -m 3 "https://$cloudflare_api/cdn-cgi/trace" | grep -i '^loc=' | cut -d'=' -f2 | xargs)
    if [ -z "$_LOC" ]; then
        _err_msg "$(_red 'Cannot retrieve server location. Check your network and try again.')" && end_message && exit 1
    fi
}

function os_permission {
    case "$os_name" in
        'debian')
            # 检查Debian版本是否小于10
            if [ "$(grep -oE '[0-9]+' /etc/debian_version | head -1)" -lt 10 ]; then
                _err_msg "$(_red 'This version of Debian is no longer supported!')" && end_message && exit 1
            fi
        ;;
        'ubuntu')
            # 检查Ubuntu版本是否小于20.04
            if [ "$(grep "^VERSION_ID" /etc/*-release | cut -d '"' -f 2 | tr -d '.')" -lt '2004' ]; then
                _err_msg "$(_red 'This version of Ubuntu is no longer supported!')" && end_message && exit 1
            fi
        ;;
        'almalinux' | 'centos' | 'rhel' | 'rocky')
            # 检查RHEL/CentOS/Rocky/AlmaLinux版本是否小于7
            if [ "$(grep -shoE '[0-9]+' /etc/redhat-release /etc/centos-release /etc/rocky-release /etc/almalinux-release | head -1)" -lt 7 ]; then
                _err_msg "$(_red "This installer requires version $os_name 7 or higher.")" && end_message && exit 1
            fi
        ;;
        *) _err_msg "$(_red 'The current operating system is not supported!')" && end_message && exit 1 ;;
    esac
}

function check_install {
    if _exists docker >/dev/null 2>&1 || \
        docker --version >/dev/null 2>&1 || \
        docker compose version >/dev/null 2>&1 || \
        _exists docker-compose >/dev/null 2>&1; then
            _err_msg "$(_red 'Docker is already installed. Exiting the installer.')" && end_message && exit 1
    fi
}

function clear_repos {
    [ -f "/etc/yum.repos.d/docker-ce.repo" ] &&  rm -f /etc/yum.repos.d/docker-ce.repo 2>/dev/null
    [ -f "/etc/yum.repos.d/docker-ce-staging.repo" ] &&  rm -f /etc/yum.repos.d/docker-ce-staging.repo 2>/dev/null
    [ -f "/etc/apt/keyrings/docker.asc" ] &&  rm -f /etc/apt/keyrings/docker.asc 2>/dev/null
    [ -f "/etc/apt/sources.list.d/docker.list" ] &&  rm -f /etc/apt/sources.list.d/docker.list 2>/dev/null
}

function fix_dpkg {
    pkill -f -15 'apt|dpkg' || pkill -f -9 'apt|dpkg'
    for lockfile in "/var/lib/dpkg/lock" "/var/lib/dpkg/lock-frontend"; do
        [ -f "$lockfile" ] &&  rm -f "$lockfile" >/dev/null 2>&1
    done
    dpkg --configure -a
}

function docker_install {
    local version_code repo_url gpgkey_url

    _info_msg "$(_yellow 'Installing the Docker environment!')"
    if [ "$os_name" = "almalinux" ] || [ "$os_name" = "centos" ] || [ "$os_name" = "rocky" ]; then
        pkg_uninstall docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine >/dev/null 2>&1

        if [ "$_LOC" = "CN" ]; then
            repo_url="https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo"
        else
            repo_url="https://download.docker.com/linux/centos/docker-ce.repo"
        fi

        if _exists dnf >/dev/null 2>&1; then
            dnf config-manager --help >/dev/null 2>&1 || dnf install -y dnf-plugins-core
            dnf config-manager --add-repo "$repo_url" 2>/dev/null
            dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        elif _exists yum >/dev/null 2>&1; then
            rpm -q yum-utils >/dev/null 2>&1 || yum install -y yum-utils
            yum-config-manager --add-repo "$repo_url" >/dev/null 2>&1
            yum makecache fast
            yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        else
            _err_msg "$(_red 'Unknown package manager!')" && end_message && exit 1
        fi
    elif [ "$os_name" = "rhel" ]; then
        pkg_uninstall docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine podman runc >/dev/null 2>&1

        dnf config-manager --help || dnf install -y dnf-plugins-core
        if [ "$_LOC" = "CN" ]; then
            dnf config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/rhel/docker-ce.repo
        else
            dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
        fi
        dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    elif [ "$os_name" = "debian" ] || [ "$os_name" = "ubuntu" ]; then
        version_code="$(grep "^version_codeNAME" /etc/*-release | cut -d= -f2)"
        pkg_uninstall docker.io docker-doc docker-compose podman-docker containerd runc >/dev/null 2>&1

        if [ "$_LOC" = "CN" ]; then
            repo_url="https://mirrors.aliyun.com/docker-ce/linux/${os_name}"
            gpgkey_url="https://mirrors.aliyun.com/docker-ce/linux/${os_name}/gpg"
        else
            repo_url="https://download.docker.com/linux/${os_name}"
            gpgkey_url="https://download.docker.com/linux/${os_name}/gpg"
        fi

        fix_dpkg
        apt-get -qq update
        apt-get install -y -qq ca-certificates curl
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL "$gpgkey_url" -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc

        # add the repository to apt sources
        echo "deb [arch=$( dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] $repo_url $version_code stable" |  tee /etc/apt/sources.list.d/docker.list >/dev/null
        apt-get -qq update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    else
        _err_msg "$(_red 'The current operating system is not supported!')" && end_message && exit 1
    fi

    systemctl daemon-reload
    systemctl enable docker --now
}

function check_status {
    if systemctl is-active --quiet docker || \
        docker info >/dev/null 2>&1 || \
        /etc/init.d/docker status | grep -q 'started' || \
        service docker status >/dev/null 2>&1 || \
        curl -s --unix-socket /var/run/docker.sock http://localhost/version >/dev/null 2>&1; then
            _suc_msg "$(_green 'Docker has completed self-check, started, and set to start on boot!')"
    else
        _err_msg "$(_red 'Docker status check failed or service not starting. Check logs or start Docker manually.')" && end_message && exit 1
    fi
}

function docker_version {
    local docker_v=""
    local docker_compose_v=""

    # 获取Docker版本
    if _exists docker >/dev/null 2>&1; then
        docker_v=$(docker --version | awk -F '[ ,]' '{print $3}')
    elif _exists docker.io >/dev/null 2>&1; then
        docker_v=$(docker.io --version | awk -F '[ ,]' '{print $3}')
    fi

    # 获取Docker Compose版本
    if docker compose version >/dev/null 2>&1; then
        docker_compose_v=$(docker compose version --short)
    elif _exists docker-compose >/dev/null 2>&1; then
        docker_compose_v=$(docker-compose version --short)
    fi

    echo
    echo "Docker Version: v$docker_v"
    echo "Docker Compose Version: v$docker_compose_v"
    echo
    _yellow "Get Docker information"
    sleep 2
    docker version 2>/dev/null

    # intentionally mixed spaces and tabs here -- tabs are stripped by "<<-EOF", spaces are kept in the output
    echo
    echo "================================================================================"
    echo
    echo "To run the Docker daemon as a fully privileged service, but granting non-root"
    echo "users access, refer to https://docs.docker.com/go/daemon-access/"
    echo
    echo "WARNING: Access to the remote API on a privileged Docker daemon is equivalent"
    echo "         to root access on the host. Refer to the 'Docker daemon attack surface'"
    echo "         documentation for details: https://docs.docker.com/go/attack-surface/"
    echo
    echo "================================================================================"
    echo
}

function get_docker {
    clear
    show_logo
    pre_check
    os_permission
    check_install
    clear_repos
    docker_install
    check_status
    docker_version
    end_message
}

get_docker