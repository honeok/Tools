#!/bin/bash
# Author: honeok
# Blog: https://www.honeok.com

set -o errexit

yellow='\033[1;33m'       # 黄色
red='\033[1;31m'          # 红色
magenta='\033[1;35m'      # 品红色
green='\033[1;32m'        # 绿色
blue='\033[1;34m'         # 蓝色
cyan='\033[1;36m'         # 青色
purple='\033[1;35m'       # 紫色
gray='\033[1;30m'         # 灰色
orange='\033[1;38;5;208m' # 橙色
white='\033[0m'           # 白色
_yellow() { echo -e ${yellow}$@${white}; }
_red() { echo -e ${red}$@${white}; }
_magenta() { echo -e ${magenta}$@${white}; }
_green() { echo -e ${green}$@${white}; }
_blue() { echo -e ${blue}$@${white}; }
_cyan() { echo -e ${cyan}$@${white}; }
_purple() { echo -e ${purple}$@${white}; }
_gray() { echo -e ${gray}$@${white}; }
_orange() { echo -e ${orange}$@${white}; }

current_date=$(date '+%Y-%m-%d %H:%M:%S')

# 结尾任意键结束
end_of(){
	_green "操作完成"
	_yellow "按任意键继续"
	read -n 1 -s -r -p ""
	echo ""
	clear
}

# 检查用户是否为root
need_root(){
	clear
	if [ "$(id -u)" -ne "0" ]; then
		_red "该功能需要root用户才能运行"
		end_of
	fi
}

# 安装软件包
install(){
	if [ $# -eq 0 ]; then
		_red "未提供软件包参数"
		return 1
	fi

	for package in "$@"; do
		if ! command -v "$package" &>/dev/null; then
			_yellow "正在安装$package"
			if command -v dnf &>/dev/null; then
				dnf install -y "$package"
			elif command -v yum &>/dev/null; then
				yum -y install "$package"
			elif command -v apt &>/dev/null; then
				apt update && apt install -y "$package"
			elif command -v apk &>/dev/null; then
				apk add "$package"
			else
				_red "未知的包管理器"
				return 1
			fi
		else
			_green "$package已经安装"
		fi
	done
	return 0
}

serverstatus(){
	local choice
	while true; do
		clear
		echo "----------------------------"
		echo " Serverstatus 探针管理脚本"
		echo "----------------------------"
		echo "1. 部署探针(需安装Docker)"
		echo "----------------------------"
        echo "0. 退出"
		echo "----------------------------"
		echo ""
		
		echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
		read choice

		case "$choice" in
			1)
				while true;do
					clear
					echo "---------------------------------"
					echo " 安装探针需要部署Docker,是否继续?"
					echo "---------------------------------"
					echo "1. 安装Docker并部署Serverstatus探针"
					echo "2. 已安装Docker直接部署Serverstatus探针"
					echo "---------------------------------"
					echo "0. 取消"
					echo "---------------------------------"

					echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
					read choice
					
					case $choice in
						1)
							install wget
							bash <(wget -qO- https://raw.githubusercontent.com/honeok8s/get-docker/main/get-docker.sh)
							
							;;
						2)
							
							;;
						0)
							break
							;;
						*)
							_red "无效选项,请重新输入"
							;;
					esac
				done
				;;
			0)
				clear
				exit 0
				;;
			*)
				_red "无效选项,请重新输入"
				;;
		esac
	done
}
serverstatus