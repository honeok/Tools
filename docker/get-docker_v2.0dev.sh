#!/bin/bash
# Author: honeok
# Blog: www.honeok.com

set -o errexit
clear

gitdocker_version="2024.8.12 v1.0"
os_release=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d '"' -f 2)

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

# 安装软件包
install() {
	if [ $# -eq 0 ]; then
		_red "未提供软件包参数"
		return 1
	fi

	for package in "$@"; do
		if ! command -v "$package" &>/dev/null; then
			_yellow "正在安装$package"
			if command -v dnf &>/dev/null; then
				dnf update -y
				dnf install epel-release -y
				dnf install "$package" -y
			elif command -v yum &>/dev/null; then
				yum update -y
				yum install epel-release -y
				yum install "$package" -y
			elif command -v apt &>/dev/null; then
				apt update -y
				apt install "$package" -y
			elif command -v apk &>/dev/null; then
				apk update
				apk add "$package"
			else
				_red "未知的包管理器"
				return 1
			fi
		else
			_green "$package已安装"
		fi
	done

	return 0
}

# 卸载软件包
remove() {
	if [ $# -eq 0 ]; then
		_red "未提供软件包参数"
		return 1
	fi

	for package in "$@"; do
		_yellow "正在卸载$package"
		if command -v dnf &>/dev/null; then
			if rpm -q "$package" &>/dev/null; then
				dnf remove "$package"* -y
			fi
		elif command -v yum &>/dev/null; then
			if rpm -q "${package}" >/dev/null 2>&1; then
				yum remove "${package}"* -y
			fi
		elif command -v apt &>/dev/null; then
			if dpkg -l | grep -qw "${package}"; then
				apt purge "${package}"* -y
			fi
		elif command -v apk &>/dev/null; then
			if apk info | grep -qw "${package}"; then
				apk del "${package}"*
			fi
		else
			_red "未知的包管理器"
			return 1
		fi
	done

	return 0
}

# 检查网络连接
check_internet_connect(){
	if ! ping -c 1 objectstorage.ap-seoul-1.oraclecloud.com &> /dev/null; then
		_red "网络错误,无法访问互联网"
		exit 1
	fi
}

# 获取服务器IP地址
check_ip_address(){
	local ipv4_address=$(curl -s -H "X-Forwarded-For: 223.5.5.5" http://ifconfig.me)
	local ipv6_address=$(curl -s --max-time 1 ipv6.ip.sb)
	local isp_info=$(curl -s https://ipinfo.io | grep '"org":' | awk -F'"' '{print $4}')
	local location=$(curl -s ipinfo.io/city)

	_yellow "公网IPv4地址: ${ipv4_address}"
	_yellow "公网IPv6地址: ${ipv6_address}"
	_yellow "运营商: ${isp_info}"
	_yellow "地理位置: ${location}"
}

# 检查Docker或Docker Compose是否已安装,用于在函数操作系统安装docker中嵌套
check_docker_installed() {
	if command -v docker >/dev/null 2>&1; then
		if docker --version >/dev/null 2>&1; then
			_red "Docker已安装,正在退出安装程序"
			script_completion_message
			exit 0
		fi
	fi
	
	if command -v docker compose >/dev/null 2>&1 || command -v docker-compose >/dev/null 2>&1; then
		_red "Docker Compose已安装,正在退出安装程序"
		script_completion_message
		exit 0
	fi
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

# 在CentOS上安装Docker
centos_install_docker(){
	local repo_url=""
	local total_steps=5
	local step=0

	# 检查是否为CentOS7
	if ! grep -q '^ID="centos"$' /etc/os-release || ! grep -q '^VERSION_ID="7"$' /etc/os-release; then
		_red "本脚本仅支持在CentOS7上安装Docker,如有需求请www.honeok.com留言"
		script_completion_message
		exit 0
	fi

	# 根据地区选择镜像源
	if [ "$(curl -s https://ipinfo.io/country)" == 'CN' ]; then
		repo_url="http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo"
	else
		repo_url="https://download.docker.com/linux/centos/docker-ce.repo"
	fi

	check_docker_installed
	sudo yum remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine -y >/dev/null 2>&1 || true

	commands=(
		"sudo yum install yum-utils -y >/dev/null 2>&1"
		"sudo yum-config-manager --add-repo \"$repo_url\" >/dev/null 2>&1"
		"sudo yum makecache fast >/dev/null 2>&1"
		"sudo yum install docker-ce docker-ce-cli containerd.io -y >/dev/null 2>&1"
		"sudo systemctl enable docker --now >/dev/null 2>&1"
	)

	for command in "${commands[@]}"; do
		eval $command
		print_progress $((++step)) $total_steps
	done

	# 结束进度条
	printf "\n"

	# 检查Docker服务是否处于活动状态 
	if ! sudo systemctl is-active --quiet docker; then
		_red "Docker状态检查失败或服务无法启动,请检查安装日志或手动启动Docker服务"
		exit 1
	else
		_green "Docker已完成自检,启动并设置开机自启"
	fi
}

#alpine_install_docker(){
#	local repo_url=""
#	local local alpine_version=$(grep '^VERSION_ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')

#	# 根据服务器位置选择镜像源
#	if [ "$(curl -s https://ipinfo.io/country)" == 'CN' ]; then
#		repo_url=https://mirrors.tuna.tsinghua.edu.cn/alpine/$alpine_version/community
#	else
#		repo_url=https://dl-cdn.alpinelinux.org/alpine/$alpine_version/community
#	fi

#	echo $repo_url >>/etc/apk/repositories
	
	# 更新apk索引
#	apk update
	
	# 安装Docker及相关工具
#	commands=(
#		"apk add --no-cache docker"
#		"rc-update add docker default"
#		"service docker start"
#	)
	
	# 初始化步骤计数
#	step=0
#	total_steps=${#commands[@]}  # 总命令数
	
#	for command in "${commands[@]}"; do
#		eval $command
#		print_progress $((++step)) $total_steps
#	done
	
	# 结束进度条
#	printf "\n"
	
#	if ! docker --version >/dev/null 2>&1; then
#		_red "Docker安装失败,请手动检查"
#		exit 1
#	else
#		_green "Docker已成功安装并启动"
#	else
#}

# 在 Debian/Ubuntu 上安装 Docker
install_docker(){
	local repo_url=""
	local gpg_key_url=""
	local codename="$(lsb_release -cs)"
	local os_name="$(lsb_release -si)"

	# 根据服务器位置选择镜像源
	if [ "$(curl -s https://ipinfo.io/country)" == 'CN' ]; then
		repo_url="https://mirrors.aliyun.com/docker-ce/linux/${os_name,,}"
		gpg_key_url="https://mirrors.aliyun.com/docker-ce/linux/${os_name,,}/gpg"
	else
		repo_url="https://download.docker.com/linux/${os_name,,}"
		gpg_key_url="https://download.docker.com/linux/${os_name,,}/gpg"
	fi
	
	# 验证是否为受支持的操作系统
	if [[ "$os_name" != "Ubuntu" && "$os_name" != "Debian" ]]; then
		_red "此脚本不支持的Linux发行版"
		exit 1
	fi

	check_docker_installed

	# 根据官方文档删除旧版本的Docker
	apt install sudo >/dev/null 2>&1
	for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
		sudo apt remove $pkg >/dev/null 2>&1 || true
	done

	commands=(
		"sudo apt update -y >/dev/null 2>&1"
		"sudo apt install apt-transport-https ca-certificates curl gnupg lsb-release -y >/dev/null 2>&1"
		"sudo install -m 0755 -d /etc/apt/keyrings >/dev/null 2>&1"
		"sudo curl -fsSL \"$gpg_key_url\" -o /etc/apt/keyrings/docker.asc >/dev/null 2>&1"
		"sudo chmod a+r /etc/apt/keyrings/docker.asc >/dev/null 2>&1"
		"echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] $repo_url $codename stable\" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null"
		"sudo apt update -y >/dev/null 2>&1"
		"sudo apt install docker-ce docker-ce-cli containerd.io -y >/dev/null 2>&1"
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

	# 检查Docker服务是否处于活动状态
	if ! sudo systemctl is-active --quiet docker; then
		_red "Docker状态检查失败或服务无法启动,请检查安装日志或手动启动Docker服务"
		exit 1
	else
		_green "Docker已完成自检,启动并设置开机自启"
	fi
}

# 卸载Docker
uninstall_docker() {
	local os_name
	local os_release
	local docker_files=("/var/lib/docker" "/var/lib/containerd" "/etc/docker" "/opt/containerd")
	local repo_files=("/etc/yum.repos.d/docker.*" "/etc/apt/sources.list.d/docker.*" "/etc/apt/keyrings/docker.*")

	# 获取操作系统信息
	if [ -f /etc/os-release ]; then
		os_name=$(grep '^ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')
		os_release=$(grep '^VERSION_ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
	else
		_red "无法识别操作系统版本"
		exit 1
	fi

	_yellow "准备卸载Docker"

	# 检查Docker是否安装
	if ! command -v docker &> /dev/null; then
		_red "Docker未安装在系统上,无法继续卸载"
		script_completion_message
		exit 1
	fi

	stop_and_remove_docker() {
		sudo docker rm -f $(docker ps -q) >/dev/null 2>&1 || true
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
			if ls "$file" >/dev/null 2>&1; then
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
	else
		_red "抱歉, 此脚本不支持您的Linux发行版"
		exit 1
	fi

	# 检查卸载是否成功
	if command -v docker &> /dev/null; then
		_red "Docker卸载失败,请手动检查"
		exit 1
	else
		_green "Docker和Docker Compose已卸载, 并清理文件夹和相关依赖"
	fi
}

# 动态生成并加载Docker配置文件,确保最佳的镜像下载和网络配置
generate_docker_config() {
	local config_file="/etc/docker/daemon.json"
	local is_china_server='false'
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
	sudo systemctl daemon-reload && sudo systemctl restart docker
	_yellow "Docker配置文件已根据服务器IP归属做相关优化,如需调整自行修改$config_file"
}

# 显示已安装Docker和Docker Compose版本
docker_main_version() {
	local docker_version=""
	local docker_compose_version=""

	# 获取 Docker 版本
	if command -v docker >/dev/null 2>&1; then
		docker_version=$(docker --version | awk -F '[ ,]' '{print $3}')
	elif command -v docker.io >/dev/null 2>&1; then
		docker_version=$(docker.io --version | awk -F '[ ,]' '{print $3}')
	fi

	# 获取 Docker Compose 版本
	if command -v docker-compose >/dev/null 2>&1; then
		docker_compose_version=$(docker-compose version --short)
	elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
		docker_compose_version=$(docker compose version --short)
	fi

	_yellow "已安装Docker版本: v$docker_version"
	_yellow "已安装Docker Compose版本: $docker_compose_version"

	_yellow "正在获取Docker信息"
	sleep 2s
	sudo docker version

	# intentionally mixed spaces and tabs here -- tabs are stripped by "<<-EOF", spaces are kept in the output
	echo
	echo "================================================================================"
 	echo
	echo "To run Docker as a non-privileged user, consider setting up the"
	echo "Docker daemon in rootless mode for your user:"
	echo
	echo "    dockerd-rootless-setuptool.sh install"
	echo
	echo "Visit https://docs.docker.com/go/rootless/ to learn about rootless mode."
	echo
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

# 退出脚本前显示执行完成信息
script_completion_message() {
	local timezone=$(timedatectl | awk '/Time zone/ {print $3}')
	local current_time=$(date '+%Y-%m-%d %H:%M:%S')

	printf "${green}服务器当前时间: ${current_time} 时区: ${timezone} 脚本执行完成${white}\n"

	_purple "感谢使用本脚本!如有疑问,请访问honeok.com获取更多信息"
}

print_getdocker_logo() {
cat << 'EOF'
   ______     __         __           __            
  / _______  / /_   ____/ ____  _____/ /_____  _____
 / / __/ _ \/ __/  / __  / __ \/ ___/ //_/ _ \/ ___/
/ /_/ /  __/ /_   / /_/ / /_/ / /__/ ,< /  __/ /    
\____/\___/\__/   \__,_/\____/\___/_/|_|\___/_/     
                                                    
EOF

	_yellow "Author: honeok"
	_blue "Version: $gitdocker_version"
	_purple "Project: https://github.com/honeok8s"
}

# 执行逻辑
# 检查脚本是否以root用户身份运行
if [[ $EUID -ne 0 ]]; then
	printf "${red}此脚本必须以root用户身份运行. ${white}\n"
	exit 1
fi

# 参数检查
if [ -n "$1" ] && [ "$1" != "uninstall" ]; then
	print_getdocker_logo
	_red "无效参数! (可选: 没有参数/uninstall)"
	script_completion_message
	exit 1
fi

if [ -n "$2" ]; then
	print_getdocker_logo
	_red "只能提供一个参数 (可选: uninstall)"
	script_completion_message
	exit 1
fi

# 检查操作系统是否受支持(CentOS,Debian,Ubuntu)
case "$os_release" in
	*CentOS*|*centos*|*Debian*|*debian*|*Ubuntu*|*ubuntu*)
		_yellow "检测到本脚本支持的Linux发行版: $os_release"
		;;
	*)
		_red "此脚本不支持的Linux发行版: $os_release"
		exit 1
		;;
esac

# 开始脚本
main(){
	# 打印Logo
	print_getdocker_logo

	# 执行卸载 Docker
	if [ "$1" == "uninstall" ]; then
		uninstall_docker
		script_completion_message
		exit 0
	fi

	# 检查网络连接
	check_internet_connect

	# 获取IP地址
	check_ip_address

	# 检查操作系统兼容性并执行安装或卸载
	case "$os_release" in
	*CentOS*|*centos*)
		centos_install_docker
		generate_docker_config
		docker_main_version
		;;
	*Debian*|*debian*|*Ubuntu*|*ubuntu*)
		install_docker
		generate_docker_config
		docker_main_version
		;;
	*)
		_red "使用方法: ./get_docker.sh [uninstall]"
		exit 1
		;;
	esac

	# 完成脚本
	script_completion_message
}

main "$@"
exit 0
