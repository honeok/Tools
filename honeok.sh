#!/usr/bin/env bash
# Author: honeok
# Blog：www.honeok.com
# Github：https://github.com/honeok/shell

yellow='\033[93m'        # 亮黄色
red='\033[1;31m'         # 亮红色
green='\033[92m'         # 亮绿色
blue='\033[1;34m'        # 亮蓝色
cyan='\033[96m'          # 亮青色
purple='\033[95m'        # 亮紫色
gray='\033[1;37m'        # 亮灰色
orange='\033[38;5;214m'  # 亮橙色
white='\033[0m'          # 重置为默认颜色

_yellow() { echo -e ${yellow}$@${white}; }
_red() { echo -e ${red}$@${white}; }
_green() { echo -e ${green}$@${white}; }
_blue() { echo -e ${blue}$@${white}; }
_cyan() { echo -e ${cyan}$@${white}; }
_purple() { echo -e ${purple}$@${white}; }
_gray() { echo -e ${gray}$@${white}; }
_orange() { echo -e ${orange}$@${white}; }

########################################
print_logo(){
    local os_info=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d '"' -f 2)
echo -e "${yellow}   __                      __     💀
  / /  ___  ___  ___ ___  / /__
 / _ \/ _ \/ _ \/ -_) _ \/  '_/
/_//_/\___/_//_/\__/\___/_/\_\ 
"
    local os_text="当前操作系统:${os_info}"
    _yellow "${os_text}"
}

print_logo

_yellow "2.x 版存在诸多问题，3.x正在不慌不忙的开发中"
_blue "抢先试用：bash <(curl -sL github.com/honeok/shell/raw/main/honeok_dev.sh)"