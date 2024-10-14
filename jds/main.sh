#!/bin/bash
# Author: honeok

set -o errexit
clear

# 颜色代码
yellow='\033[1;33m'  # 提示信息
red='\033[1;31m'     # 警告信息
magenta='\033[0;35m' # 品红色
green='\033[1;32m'   # 成功信息
blue='\033[1;34m'    # 一般信息
cyan='\033[1;36m'    # 特殊信息
purple='\033[1;35m'  # 紫色或粉色信息
gray='\033[1;30m'    # 灰色信息
white='\033[0m'      # 结束颜色设置

# 打印带颜色的消息
_yellow() { echo -e ${yellow}$@${white}; }
_red() { echo -e ${red}$@${white}; }
_magenta() { echo -e ${magenta}$@${white}; }
_green() { echo -e ${green}$@${white}; }
_blue() { echo -e ${blue}$@${white}; }
_cyan() { echo -e ${cyan}$@${white}; }
_purple() { echo -e ${purple}$@${white}; }
_gray() { echo -e ${gray}$@${white}; }

##########################################################
# 全局变量
update_file_center_ip="10.47.7.242"
update_file_center_passwd="c4h?itwj5ENi"
#################### function library ####################

print_logo(){
    echo -e "${yellow}\
       _     _        _____                      
      | |   | |      / ____|                     
      | | __| |___  | |  __  __ _ _ __ ___   ___ 
  _   | |/ _\` / __| | | |_ |/ _\` | '_ \` _ \ / _ \\
 | |__| | (_| \__ \ | |__| | (_| | | | | | |  __/
  \____/ \__,_|___/  \_____|\\__,_|_| |_| |_|\___|${white}"
}

install(){
	if [ $# -eq 0 ]; then
		_red "未提供软件包参数"
		return 1
	fi

	for package in "$@"; do
		if ! command -v "$package" &>/dev/null; then
			_yellow "正在安装 $package"
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
			_green "$package 已经安装"
		fi
	done
	return 0
}

print_process(){
	ps aux | grep -E 'lv_app|p8_app|p9_app|npm|mysql|BS|processcontrol|tarlog|node (www|app.js)|dops.sh|redis|filebeat|python3\.9 main\.py|logbus|sh start\.sh' | grep -v 'grep'
}

# 启动所有服务器
all_start(){
	# 动态生成服务器目录
	local start_dirs=()
	for i in {1..5}; do
		start_dirs+=("/data/server${i}/game/")
	done
	start_dirs+=("/data/server/gate/")
	start_dirs+=("/data/server/login/")

	# 启动
	for dir in "${start_dirs[@]}"; do
		cd "$dir"
		rm -f nohup.txt
		./server.sh start
		echo ""
	done

	sleep 5

	cd /data/tool/ || { _red "无法进入目录 /data/tool/"; exit 1; }
	if ! pgrep -f 'processcontrol' > /dev/null; then
		sh processcontrol.sh > /dev/null 2>&1 &
		_green "processcontrol 启动成功"
	else
		_yellow "processcontrol 正在运行"
	fi 

	_green "所有服务器启动成功"
	print_process
}

# 停止所有服务器
all_stop() {
	# 检查并停止守护进程
	cd /data/tool/
	if pgrep -f 'processcontrol' > /dev/null; then
		kill -9 $(pgrep -f 'processcontrol' | head -n 1)
		> control.txt
		> dump.txt
		_green "processcontrol 守护进程停止成功!"
	else
		_yellow "processcontrol 守护进程不存在无需停止"
	fi

	# 停止服务器
	stop_server() {
		local dir=$1
		cd "$dir"
		./server.sh flush
		sleep 60
		./server.sh stop
		_green "在 $dir 停止成功"
	}

	# 停止登录服务器
	cd /data/server/login/
	./server.sh stop
	_green "Login 停止成功"

	# 停止网关服务器
	cd /data/server/gate/
	./server.sh stop
	sleep 120
	_green "Gate 停止成功"

	# 动态生成游戏服务器目录
	local stop_dirs=()
	for i in {1..5}; do
		stop_dirs+=("/data/server${i}/game/")
	done

	# 停止所有游戏服务器
	for dir in "${stop_dirs[@]}"; do
		stop_server "$dir"
	done
	
	print_process
}

all_reload(){
	cd /data/update/ || { _red "无法进入目录 $dir"; exit 1; }

	if [ "$(ls -A)" ]; then
		rm -rf *
		_green "目录/data/update/已清空"
	else
		_yellow "目录/data/update/为空"
	fi

	install_package sshpass

	if ! sshpass -p "${update_file_center_passwd}" scp -o StrictHostKeyChecking=no root@${update_file_center_ip}:/data/update/updategame.tar.gz ./; then
		_red "文件下载失败"; exit 1
	fi
	
	# 解压更新包
	if ! tar xvf updategame.tar.gz; then
		_red "解压更新包失败"; exit 1
	fi

	# 定义服务器目录
	local reload_dirs=()
	for i in {1..5}; do
		reload_dirs+=("/data/server${i}/game/")
	done

	# 复制更新文件到每个服务器目录
	for dir in "${server_dirs[@]}"; do
		\cp -rf /data/update/app/* "$dir"
	done

	# 重新加载
	for dir in "${reload_dirs[@]}"; do
		cd "$dir" || { _red "无法进入目录 $dir"; exit 1; }
		./server.sh reload
		_green "$dir 重新加载成功"
	done

	_green "所有服务器重新加载成功"
	
	print_process
}

update_start(){
	# 动态生成服务器目录
	local updatestart_dirs=()
	for i in {1..5}; do
		updatestart_dirs+=("/data/server${i}/game/")
	done
	updatestart_dirs+=("/data/server/gate/")
	updatestart_dirs+=("/data/server/login/")

	cd /data/update/ || { _red "无法进入目录/data/update/"; exit 1; }

	if [ "$(ls -A)" ]; then
		rm -rf *
		_green "目录/data/update/已清空"
	else
		_yellow "目录/data/update/为空"
	fi

	install_package sshpass

	if ! sshpass -p "${update_file_center_passwd}" scp -o StrictHostKeyChecking=no root@${update_file_center_ip}:/data/update/updategame.tar.gz ./; then
		_red "文件下载失败"; exit 1
	fi
	
	# 解压更新包
	if ! tar xvf updategame.tar.gz; then
		_red "解压更新包失败"; exit 1
	fi

	# 复制更新文件到每个服务器目录
	for dir in "${updatestart_dirs[@]}"; do
		\cp -rf /data/update/app/* "$dir"
	done

	# 启动服务器
	start_server() {
		local dir=$1
		cd "$dir" || { _red "无法进入目录 $dir"; exit 1; }
		rm -f nohup.txt
		./server.sh start
		if [ $? -ne 0 ]; then
			_red "$dir 启动失败"; exit 1
		fi
		_green "$dir 启动成功"
	}

	for dir in "${updatestart_dirs[@]}"; do
		start_server "$dir"
	done

	cd /data/tool/ || { _red "无法进入目录 /data/tool/"; exit 1; }
	if ! pgrep -f 'processcontrol' > /dev/null; then
		sh processcontrol.sh > /dev/null 2>&1 &
		_green "processcontrol 启动成功"
	else
		_yellow "processcontrol 正在运行"
	fi 

	_green "所有服务器启动成功"
	
	print_process
}

down_update_start(){
	# 检查并停止守护进程
	cd /data/tool/
	if pgrep -f 'processcontrol' > /dev/null; then
		kill -9 $(pgrep -f 'processcontrol' | head -n 1)
		> control.txt
		> dump.txt
		_green "processcontrol 守护进程停止成功!"
	else
		_yellow "processcontrol 守护进程不存在无需停止"
	fi

	# 停止服务器
	stop_server() {
		local dir=$1
		cd "$dir"
		./server.sh flush
		sleep 60
		./server.sh stop
		_green "在 $dir 停止成功"
	}

	# 停止登录服务器
	cd /data/server/login/ || { _red "无法进入目录 /data/server/login/"; exit 1; }
	./server.sh stop
	_green "Login 停止成功"

	# 停止网关服务器
	cd /data/server/gate/ || { _red "无法进入目录 /data/server/gate/"; exit 1; }
	./server.sh stop
	sleep 120
	_green "Gate 停止成功"

	# 动态生成游戏服务器目录
	local stop_dirs=()
	for i in {1..5}; do
		stop_dirs+=("/data/server${i}/game/")
	done

	# 停止所有游戏服务器
	for dir in "${stop_dirs[@]}"; do
		stop_server "$dir"
	done

############################################################

	# 更新操作
	cd /data/update/ || { _red "无法进入目录/data/update/"; exit 1; }

	# 清空更新目录
	if [ "$(ls -A)" ]; then
		rm -rf *
		_green "目录/data/update/已清空"
	else
		_yellow "目录/data/update/为空"
	fi

	install_package sshpass

	if ! sshpass -p "${update_file_center_passwd}" scp -o StrictHostKeyChecking=no root@${update_file_center_ip}:/data/update/updategame.tar.gz ./; then
		_red "文件下载失败"; exit 1
	fi

	# 解压更新包
	if ! tar xvf updategame.tar.gz; then
		_red "解压更新包失败"; exit 1
	fi

	# 动态生成更新目录列表
	local updatestart_dirs=()
	for i in {1..5}; do
		updatestart_dirs+=("/data/server${i}/game/")
	done
	updatestart_dirs+=("/data/server/gate/")
	updatestart_dirs+=("/data/server/login/")

	# 复制更新文件到每个服务器目录
	for dir in "${updatestart_dirs[@]}"; do
		\cp -rf /data/update/app/* "$dir"
	done

	# 启动服务器
	start_server() {
		local dir=$1
		cd "$dir" || { _red "无法进入目录 $dir"; exit 1; }
		# 删除旧的 nohup 文件
		rm -f nohup.txt
		# 启动服务器
		./server.sh start
		if [ $? -ne 0 ]; then
			_red "$dir 启动失败"; exit 1
		fi
		_green "$dir 启动成功"
	}

	# 启动所有服务器
	for dir in "${updatestart_dirs[@]}"; do
		start_server "$dir"
	done

	# 检查并启动守护进程
	cd /data/tool/ || { _red "无法进入目录 /data/tool/"; exit 1; }
	if ! pgrep -f 'processcontrol' > /dev/null; then
		sh processcontrol.sh > /dev/null 2>&1 &
		_green "processcontrol 启动成功"
	else
		_yellow "processcontrol 正在运行"
	fi 

	_green "所有服务器启动成功"
	
	print_process
}

# 交互菜单
main(){
	local choice
	while true; do
		clear
		print_logo
		_purple "-------------------------"
		_purple "1. 查看游戏进程"
		_purple "2. 启动服务器"
		_purple "3. 停止服务器(默认执行存盘)"
		_purple "4. 重读服务器"
		_purple "5. 维护更新启动"
		_purple "6. 停止服务更新并重启服务器"
		_purple "0. 退出脚本"
		_purple "-------------------------"
		echo -n -e "${cyan}请输入选项并按Enter: ${white}"
		read choice

		case "$choice" in
			1)
				print_process
				;;
			2)
				all_start
				;;
			3)
				all_stop
				;;
			4)
				all_reload
				;;
			5)
				update_start
				;;
			6)
				down_update_start
				;;
			0)
				_yellow "Bye!"
				exit 0
				;;
			*)
				_red "无效选项,请重新输入"
				;;
		esac
		_yellow "按任意键继续"	
		read -n 1 -s -r
	done
}

if [ "$#" -eq 0 ]; then
	# 如果没有参数,运行交互式逻辑
	main
else
	# 如果有参数,执行相应函数
	case $1 in
		\ps)
			print_process
			;;
		\start)
			all_start
			;;
		\stop)
			all_stop
			;;
		\reload)
			all_reload
			;;
		updatestart)
			update_start
			;;
		downupdate_start)
			down_update_start
			;;
		-h)
			_yellow "可选参数: ps [查看游戏进程]/start[启动所有服务器]/stop[停止所有服务器]/reload[重读服务器]/updatestart/downupdate_start"
			;;
		*)
			_red "无效的参数"
			;;
	esac
fi
exit 0