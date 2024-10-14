#!/bin/bash

# ANSI颜色码，用于彩色输出
yellow='\033[1;33m' # 提示信息
red='\033[1;31m'    # 警告信息
green='\033[1;32m'  # 成功信息
blue='\033[1;34m'   # 一般信息
cyan='\033[1;36m'   # 特殊信息
purple='\033[1;35m' # 紫色或粉色信息
gray='\033[1;30m'   # 灰色信息
white='\033[0m'     # 结束颜色设置

# 检查命令是否成功执行
check_command() {
    local message="$1"
    if [ $? -ne 0 ]; then
        printf "${red}${message}${white}\n"
        return 1
    fi
}

install_and_upgrade() {
    # 比较版本函数
    version_ge() {
        local ver1 ver2
        IFS='.' read -r -a ver1 <<< "$1"
        IFS='.' read -r -a ver2 <<< "$2"

        local length1=${#ver1[@]}
        local length2=${#ver2[@]}

        if [ "$length1" -lt "$length2" ]; then
            ver1+=($(for i in $(seq $length1 $length2); do echo 0; done))
        elif [ "$length2" -lt "$length1" ]; then
            ver2+=($(for i in $(seq $length2 $length1); do echo 0; done))
        fi

        for i in $(seq 0 $((${#ver1[@]} - 1))); do
            if [ "${ver1[$i]}" -gt "${ver2[$i]}" ]; then
                return 0
            elif [ "${ver1[$i]}" -lt "${ver2[$i]}" ]; then
                return 1
            fi
        done
        return 0
    }

    # 获取当前版本的函数
    package_get_version() {
        local pkg_name="$1"
        local version

        version=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}\n' "$pkg_name" 2>/dev/null)
        if [ $? -ne 0 ]; then
            printf "${red}软件包$pkg_name未安装${white}\n"
        else
            printf "%s\n" "$version"
        fi
    }

    # 执行系统更新
    perform_system_update() {
        printf "${yellow}系统更新请稍后${white}\n"
        sleep 2s
        yum update -y
        check_command "系统更新失败"
    }

    # 安装工具
    install_tool() {
        local tool="$1"
        printf "${yellow}检查并安装辅助工具:$tool${white}\n"
        local current_version latest_version

        current_version=$(package_get_version "$tool")
        if [[ "$current_version" == *"未安装"* ]]; then
            latest_version=$(yum info "$tool" 2>/dev/null | grep -i 'Version' | awk '{print $3}' | sed 's/^[[:space:]]*//')
			check_command "获取工具 $tool 最新版本信息失败"

            if [ -z "$latest_version" ]; then
                printf "${red}获取最新版本信息失败，跳过$tool${white}\n"
                return 1
            fi

            yum install -y "$tool" >/dev/null 2>&1
			check_command "安装工具$tool失败"

            if [ $? -eq 0 ]; then
                printf "${green}工具$tool已成功安装或已是最新版本${white}\n"
            else
                printf "${red}安装工具$tool失败${white}\n"
                return 1
            fi
        else
            printf "${green}工具$tool已是最新版本${white}\n"
        fi
    }

    # 安装插件
    install_plugin() {
        local plugin="$1"
        printf "${yellow}检查并安装必要插件: $plugin${white}\n"
        local current_version latest_version

        current_version=$(package_get_version "$plugin")
        if [[ "$current_version" == *"未安装"* ]]; then
            latest_version=$(yum info "$plugin" 2>/dev/null | grep -i 'Version' | awk '{print $3}' | sed 's/^[[:space:]]*//')
			check_command "获取插件$plugin最新版本信息失败"

            if [ -z "$latest_version" ]; then
                printf "${red}获取最新版本信息失败,跳过$plugin${white}\n"
                return 1
            fi

            yum install -y "$plugin" >/dev/null 2>&1
			check_command "安装插件$plugin失败"
			
            if [ $? -eq 0 ]; then
                printf "${green}插件$plugin已成功安装或已是最新版本${white}\n"
            else
                printf "${red}安装插件$plugin失败${white}\n"
                return 1
            fi
        else
            printf "${green}插件$plugin已是最新版本${white}\n"
        fi
    }

    # 从EPEL仓库安装Python3.6
    install_python_from_epel() {
        printf "${yellow}检查并安装Python3.6从EPEL仓库${white}\n"

        # 安装EPEL仓库
        yum install -y epel-release
        check_command "安装EPEL仓库失败"

        # 安装Python3.6
        yum install -y python36
        check_command "安装 Python3.6失败"

        # 设置 Python3.6为默认 Python 3
        alternatives --install /usr/bin/python3 python3 /usr/bin/python3.6 1
    }

    # 升级 Python 版本
    upgrade_python() {
        local python_version
        python_version=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')

        local required_version="3.6.8"

        if ! version_ge "$python_version" "$required_version"; then
            printf "${yellow}当前Python版本: $python_version小于$required_version正在升级Python${white}\n"

            # 从 EPEL 仓库安装 Python 3.6
            install_python_from_epel

            # 验证 Python 版本是否升级成功
            python_version=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')
            if version_ge "$python_version" "$required_version"; then
                printf "${green}Python已成功升级到版本$python_version${white}\n"
            else
                printf "${red}Python升级失败,请重试${white}\n"
                return 1
            fi
        else
            printf "${yellow}当前Python版本:Python $python_version,已满足要求${white}\n"
        fi
    }

    # 执行主操作
    perform_system_update

    local auxiliary_tools=(
        "lrzsz"
        "sshpass"
        "dos2unix"
        "wget"
        "ntpdate"
    )
    local required_plugins=(
        "bison"
        "autoconf"
        "python3"
    )

    for tool in "${auxiliary_tools[@]}"; do
        install_tool "$tool"
    done

    for plugin in "${required_plugins[@]}"; do
        install_plugin "$plugin"
    done

    upgrade_python
}

# 主菜单循环
while true; do
    clear
    printf "${cyan}=================================${white}\n"
    printf "${cyan}       安装和升级工具菜单       ${white}\n"
    printf "${cyan}=================================${white}\n"
    printf "${cyan}1. 安装或升级运行组件${white}\n"
    printf "${cyan}=================================${white}\n"

    printf "${cyan}请输入选项并按回车: ${white}"
    read -r choice

    case "$choice" in
        1)
            install_and_upgrade
            ;;
        *)
            printf "${red}无效的选项，请重新选择${white}\n"
            ;;
    esac
    printf "${cyan}按任意键继续...${white}\n"
    read -n 1 -s -r -p ""
done
