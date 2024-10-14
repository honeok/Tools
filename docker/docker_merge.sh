#!/bin/bash
# Author: honeok
# Blog: https://www.honeok.com

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

remove() {
	if [ $# -eq 0 ]; then
		_red "未提供软件包参数"
		return 1
	fi

	for package in "$@"; do
		if command -v dnf &>/dev/null; then
			if rpm -q "${package}" >/dev/null 2>&1; then
				dnf remove -y "${package}"* >/dev/null 2>&1 || true
			fi
		elif command -v yum &>/dev/null; then
			if rpm -q "${package}" >/dev/null 2>&1; then
				yum remove -y "${package}"* >/dev/null 2>&1 || true
			fi
		elif command -v apt &>/dev/null; then
			if dpkg -l | grep -qw "${package}"; then
				apt purge -y "${package}"* >/dev/null 2>&1 || true
			fi
		elif command -v apk &>/dev/null; then
			if apk info | grep -qw "${package}"; then
				apk del "${package}"* >/dev/null 2>&1 || true
			fi
		else
			_red "未知的包管理器"
			return 1
		fi
	done
	return 0
}

# 通用systemctl函数, 适用于各种发行版
systemctl() {
	local COMMAND="$1"
	local SERVICE_NAME="$2"

	if command -v apk &>/dev/null; then
		service "$SERVICE_NAME" "$COMMAND"
	else
		/bin/systemctl "$COMMAND" "$SERVICE_NAME"
	fi
}

# 重启服务
restart() {
	systemctl restart "$1"
	if [ $? -eq 0 ]; then
		_green "$1服务已重启"
	else
		_red "错误:重启$1服务失败"
	fi
}

# 重载服务
reload() {
	systemctl reload "$1"
	if [ $? -eq 0 ]; then
		_green "$1服务已重载"
	else
		_red "错误:重载$1服务失败"
	fi
}

# 启动服务
start() {
	systemctl start "$1"
	if [ $? -eq 0 ]; then
		_green "$1服务已启动"
	else
		_red "错误:启动$1服务失败"
	fi
}

# 停止服务
stop() {
	systemctl stop "$1"
	if [ $? -eq 0 ]; then
		_green "$1服务已停止"
	else
		_red "错误:停止$1服务失败"
	fi
}

# 查看服务状态
status() {
	systemctl status "$1"
	if [ $? -eq 0 ]; then
		_green "$1服务状态已显示"
	else
		_red "错误:无法显示$1服务状态"
	fi
}

# 设置服务为开机自启
enable() {
	local service_name="$1"
	if command -v apk &>/dev/null; then
		rc-update add "$service_name" default
	else
		/bin/systemctl enable "$service_name"
	fi

	_green "$service_name已设置为开机自启"
}

generate_docker_config() {
	local config_file="/etc/docker/daemon.json"
	local is_china_server='false'

	if ! command -v docker &> /dev/null; then
		_red "Docker未安装在系统上,无法优化"
		return 1
	fi

	if [ -f "$config_file" ]; then
		# 如果文件存在,检查是否已经优化过
		if grep -q '"storage-driver": "overlay2"' "$config_file"; then
			_yellow "Docker配置文件已经优化,无需再次优化"
			return 0
		fi
	fi

	install python3 >/dev/null 2>&1

	# 检查服务器是否在中国
	if [ "$(curl -s https://ipinfo.io/country)" == 'CN' ]; then
		is_china_server='true'
	fi

	# Python脚本
	python3 - <<EOF
import json
import sys

registry_mirrors = [
	"https://registry.honeok.com",
	"https://registry2.honeok.com",
	"https://docker.ima.cm",
	"https://hub.littlediary.cn",
	"https://h.ysicing.net"
]

base_config = {
	"exec-opts": [
		"native.cgroupdriver=systemd"
	],
	"max-concurrent-downloads": 10,
	"max-concurrent-uploads": 5,
	"log-driver": "json-file",
	"log-opts": {
		"max-size": "30m",
		"max-file": "3"
	},
	"storage-driver": "overlay2",
	"ipv6": False
}

# 如果是中国服务器，将 registry-mirrors 放在前面
if "$is_china_server" == "true":
	config = {
		"registry-mirrors": registry_mirrors,
		**base_config
	}
else:
	config = base_config

with open("/etc/docker/daemon.json", "w") as f:
	json.dump(config, f, indent=4)

EOF

	# 校验和重新加载Docker守护进程
	_green "Docker配置文件已重新加载并重启Docker服务"
	sudo systemctl daemon-reload && systemctl restart docker
	_yellow "Docker配置文件已根据服务器IP归属做相关优化,如需调整自行修改$config_file"
}

install_docker_official() {
	if [[ "$(curl -s ipinfo.io/country)" == "CN" ]]; then
		cd ~
		curl -sS -O https://raw.githubusercontent.com/honeok8s/shell/main/docker/get-docker-official.sh && chmod +x get-docker-official.sh
		sh get-docker-official.sh --mirror Aliyun
		rm -f get-docker-official.sh
	else
		curl -fsSL https://get.docker.com | sh
	fi

	systemctl enable docker
	systemctl start docker
}

install_add_docker() {
    _yellow "正在安装docker环境"

	if [ -f /etc/os-release ] && grep -q "Fedora" /etc/os-release; then
		install_docker_official
	elif command -v apt &>/dev/null || command -v yum &>/dev/null; then
		install_docker_official
	else
		install docker docker-compose
		systemctl enable docker
		systemctl start docker
	fi

	sleep 2
}

# 打印进度条
print_progress() {
	local step=$1
	local total_steps=$2
	local progress=$((100 * step / total_steps))
	local bar_length=50
	local filled_length=$((bar_length * progress / 100))
	local empty_length=$((bar_length - filled_length))
	local bar=$(printf "%${filled_length}s" | tr ' ' '#')
	local empty=$(printf "%${empty_length}s" | tr ' ' '-')
	printf "\r[${bar}${empty}] ${progress}%% 完成"
}

install_docker() {
	if ! command -v docker >/dev/null 2>&1; then
		install_add_docker
	else
		_green "Docker环境已经安装"
	fi
}

# 卸载Docker
uninstall_docker() {
	local os_name
	local docker_files=("/var/lib/docker" "/var/lib/containerd" "/etc/docker" "/opt/containerd")
	local repo_files=("/etc/yum.repos.d/docker.*" "/etc/apt/sources.list.d/docker.*" "/etc/apt/keyrings/docker.*")

	# 获取操作系统信息
	if [ -f /etc/os-release ]; then
		os_name=$(grep '^ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')
	else
		_red "无法识别操作系统版本"
		return 1
	fi

	_yellow "准备卸载Docker"

	# 检查Docker是否安装
	if ! command -v docker &> /dev/null; then
		_red "Docker未安装在系统上,无法继续卸载"
		return 1
	fi

	stop_and_remove_docker() {
		local running_containers

		# 获取所有容器的 ID
		running_containers=$(docker ps -aq)
		# 检查是否有容器 ID
		if [ -n "$running_containers" ]; then
			sudo docker rm -f $running_containers >/dev/null 2>&1
		fi

		sudo systemctl stop docker >/dev/null 2>&1
		sudo systemctl disable docker >/dev/null 2>&1
	}

	remove_docker_files() {
		for file in "${docker_files[@]}"; do
			if [ -e "$file" ]; then
				sudo rm -fr "$file" >/dev/null 2>&1
			fi
		done
	}

	remove_repo_files() {
		for file in "${repo_files[@]}"; do
			if [ -e "$file" ]; then
				sudo rm -f "$file" >/dev/null 2>&1
			fi
		done
	}

	if [[ "$os_name" == "centos" ]]; then
		stop_and_remove_docker

		commands=(
			"sudo yum remove docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras -y >/dev/null 2>&1"
		)
		# 初始化步骤计数
		step=0
		total_steps=${#commands[@]}  # 总命令数

		# 执行命令并打印进度条
		for command in "${commands[@]}"; do
			eval $command
			print_progress $((++step)) $total_steps
		done

		# 结束进度条
		printf "\n"

		remove_docker_files
		remove_repo_files
	elif [[ "$os_name" == "ubuntu" || "$os_name" == "debian" ]]; then
		stop_and_remove_docker

		commands=(
			"sudo apt-get purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras -y >/dev/null 2>&1"
		)
		# 初始化步骤计数
		step=0
		total_steps=${#commands[@]}  # 总命令数

		# 执行命令并打印进度条
		for command in "${commands[@]}"; do
			eval $command
			print_progress $((++step)) $total_steps
		done

		# 结束进度条
		printf "\n"

		remove_docker_files
		remove_repo_files
	elif [[ "$os_name" == "alpine" ]]; then
		stop_and_remove_docker

		commands=(
			"sudo apk del docker docker-compose >/dev/null 2>&1"
		)
		# 初始化步骤计数
		step=0
		total_steps=${#commands[@]}  # 总命令数

		# 执行命令并打印进度条
		for command in "${commands[@]}"; do
			eval $command
			print_progress $((++step)) $total_steps
		done

		# 结束进度条
		printf "\n"

		remove_docker_files
		remove_repo_files
	else
		_red "抱歉, 此脚本不支持您的Linux发行版"
		break
	fi

	# 检查卸载是否成功
	if command -v docker &> /dev/null; then
		_red "Docker卸载失败,请手动检查"
		break
	else
		_green "Docker和Docker Compose已卸载, 并清理文件夹和相关依赖"
	fi
}

	while true; do
		echo "docker"
		echo "-------------------------"
		echo "1. 安装"
		echo "2  优化"
		echo "3. 卸载"
		echo "-------------------------"

		echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
		read choice

		case "$choice" in
			1)
				install_docker
				;;
			2)
				generate_docker_config
				;;
			3)
				uninstall_docker
				;;
			*)
				_red "无效选项,请重新输入"
				;;
		esac
		end_of
	done