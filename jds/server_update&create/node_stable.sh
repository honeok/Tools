#!/bin/bash

set -o errexit

# ANSI颜色码,用于彩色输出
yellow='\033[1;33m' # 提示信息
red='\033[1;31m'    # 警告信息
green='\033[1;32m'  # 成功信息
blue='\033[1;34m'   # 一般信息
cyan='\033[1;36m'   # 特殊信息
purple='\033[1;35m' # 紫色或粉色信息
gray='\033[1;30m'   # 灰色信息
white='\033[0m'     # 结束颜色设置

os_release=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d '"' -f 2 | sed 's/ (.*//')

# 安装路径和备份路径
SOFTWARE_DIR="/opt/software"
BACKUP_DIR="/opt/backup"

# 检查命令是否成功执行
check_command() {
	local message=$1
	if [ $? -ne 0 ]; then
		printf "${red}${message}${white}\n"
		return 1
	fi
}

# 创建安装目录(如果不存在)
create_software_dir() {
	if [ ! -d "$SOFTWARE_DIR" ]; then
		printf "${yellow}创建软件包下载路径:${SOFTWARE_DIR}${white}\n"
		mkdir -p "$SOFTWARE_DIR"
		check_command "创建路径失败"
		printf "${green}软件包下载路径:${SOFTWARE_DIR}创建成功!${white}\n"
	fi
}

######################## Node Start ########################

check_node_installed() {
	# 检查 node 和 npm 是否存在
	if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
		local node_version
		local npm_version

		# 获取Node.js版本
		node_version=$(node --version 2>&1)

		# 获取 npm 版本
		npm_version=$(npm --version 2>&1)

		# 提取Node.js版本号(去掉前面的 'v' 字符)
		if [[ "$node_version" =~ v([0-9]+\.[0-9]+\.[0-9]+) ]]; then
			node_version="${BASH_REMATCH[1]}"
			printf "${yellow}Node.js已安装,版本为:${node_version}${white}\n"
		else
			printf "${red}无法确定Node.js版本${white}\n"
			return 1
		fi
		
        # 打印 npm 版本
        if [[ "$npm_version" =~ ([0-9]+\.[0-9]+\.[0-9]+) ]]; then
            npm_version="${BASH_REMATCH[1]}"
            printf "${yellow}Npm已安装,版本为:${npm_version}${white}\n"
            return 0
        else
            printf "${red}无法确定npm版本${white}\n"
            return 1
        fi
	else
		printf "${red}Node.js或Npm未安装,请执行安装程序${white}\n"
		return 1
	fi
}

install_node_version() {
	# 校验软件包下载路径
	create_software_dir

	# 校验Node安装
	if ! check_node_installed >/dev/null 2>&1; then
		printf "${yellow}正在${os_release}上安装! ${white}\n"
	else
		printf "${red}Node已安装请不要重复执行${white}\n"
		return # 返回Node菜单
	fi

	# 定义下载目录
	local node_version="$1"
	local node_download_dir="$SOFTWARE_DIR/node"
	local node_version_short=${node_version%%.*} # 非CN服务器专用
	local node_url="https://mirrors.aliyun.com/nodejs-release/v${node_version}/node-v${node_version}-linux-x64.tar.xz"
	local software_list=("wget" "curl")

	# 旧的下载目录如果存在则删除,有可能曾经以为不确定因素中断安装导致的文件夹创建
	if [ -d "$node_download_dir" ]; then
		rm -fr $node_download_dir
		printf "${yellow}历史下载目录已删除:${node_download_dir}${white}\n"
	fi

	# 创建下载目录,如果不存在
	if [ ! -d "$node_download_dir" ]; then
		mkdir -p "$node_download_dir"
		check_command "目录创建失败:${node_download_dir}"
		if [ $? -eq 0 ]; then
			printf "${green}软件安装目录创建成功:${node_download_dir}${white}\n"
		else
			return 1
		fi
	else
		printf "${yellow}目录已存在:${node_download_dir}${white}\n"
	fi

	cd "$node_download_dir" || return

	# 检查并安装依赖
	for software in "${software_list[@]}"; do
		if ! command -v "$software" &> /dev/null; then
			printf "${yellow}当前环境缺少软件包$software,正在安装${white}\n"
			yum install "$software" -y >/dev/null 2>&1
			check_command "安装${software}失败"
		fi
	done

	# 根据国家判断Node下载方式
	if [ "$(curl -s https://ipinfo.io/country)" != 'CN' ]; then
		# 添加NodeSource的仓库
		local setup_url="https://rpm.nodesource.com/setup_${node_version_short}.x"
		curl -fsSL "$setup_url" | bash -
		yum install nodejs -y
	else
		# 下载Node软件包
		wget --progress=bar:force -P "$node_download_dir" "$node_url"
		check_command "下载Node安装包失败"
		
		# 确保解压目录存在
		if [ ! -d "/usr/local/nodejs" ]; then
			mkdir -p /usr/local/nodejs
		fi

		# 解压Node安装包
		tar xvf "$node_download_dir/node-v${node_version}-linux-x64.tar.xz" -C /usr/local/nodejs --strip-components=1 >/dev/null 2>&1
		check_command "解压Node安装包失败" || printf "${green}解压Node安装包成功"

		# 设置环境变量
		echo 'export PATH=/usr/local/nodejs/bin:$PATH' | tee /etc/profile.d/nodejs.sh
		source /etc/profile.d/nodejs.sh
	fi

	# 删除安装包
	rm -f "$node_download_dir/node-v${node_version}-linux-x64.tar.xz"
	
	echo ""

	# 验证安装
	check_node_installed
	
	# 删除下载目录本身
	if [ -d "$node_download_dir" ]; then
		rmdir "$node_download_dir" 2>/dev/null || true
		printf "${green}下载目录已清空并删除:${node_download_dir}${white}\n"
	else
		printf "${red}文件下载目录为空或不存在,无需清理${white}\n"
	fi
}

uninstall_node() {
	# 校验Node安装
	if ! check_node_installed >/dev/null 2>&1; then
		printf "${red}Node未安装，无需卸载${white}\n"
		return
	fi

	# 卸载Node.js
	if [ "$(curl -s https://ipinfo.io/country)" != 'CN' ]; then
		# 对于非CN服务器,卸载Node.js
		yum remove nodejs -y
		printf "${green}Node.js已从系统中卸载${white}\n"
	else
		# 对于CN服务器,删除安装目录
		if [ -d "/usr/local/nodejs" ]; then
			rm -rf /usr/local/nodejs
			printf "${green}Node.js目录已删除:${white}/usr/local/nodejs\n"
		fi
	fi

	# 删除环境变量设置文件
	if [ -f /etc/profile.d/nodejs.sh ]; then
		rm -f /etc/profile.d/nodejs.sh
		printf "${green}环境变量文件已删除:${white}/etc/profile.d/nodejs.sh\n"
	fi

	# 验证卸载是否成功
	if check_node_installed >/dev/null 2>&1; then
		printf "${red}Node卸载失败,请手动检查${white}\n"
	else
		printf "${green}Node卸载成功${white}\n"
	fi
}

# 提供Node版本选择菜单并调用install_node_version函数的MySQL安装总函数
node_version_selection_menu() {
	local choice

	while true; do
		clear
		printf "${cyan}=================================${white}\n"
		printf "${cyan}          选择Node版本           ${white}\n"
		printf "${cyan}=================================${white}\n"
		printf "${cyan}1. 安装Node 16.14.2${white}\n"
		printf "${cyan}2. 安装Node 17.9.1${white}\n"
		printf "${cyan}3. 安装Node 22.5.1${white}\n"
		printf "${cyan}4. 返回上一级菜单${white}\n"
		printf "${cyan}=================================${white}\n"

		# 读取用户选择
		printf "${cyan}请输入选项并按回车:${white}"
		read -r choice

		case "$choice" in
			1)
				install_node_version "16.14.2"
				;;
			2)
				install_node_version "17.9.1"
				;;
			3)
				install_node_version "22.5.1"
				;;
			4)
				printf "${yellow}返回上一级菜单${white}\n"
				return
				;;
			*)
				printf "${red}无效选项,请重新输入${white}\n"
				;;
		esac
		# 等待用户按任意键继续
		printf "${cyan}按任意键继续${white}\n"
		read -n 1 -s -r
	done
}

# node菜单
node_menu() {
	local choice
	while true; do
		clear
		printf "${cyan}=================================${white}\n"
		printf "${cyan}           Node管理菜单         ${white}\n"
		printf "${cyan}=================================${white}\n"
		printf "${cyan}1. 查看Node环境${white}\n"
		printf "${cyan}2. 安装Node环境${white}\n"
		printf "${cyan}3. 卸载Node环境${white}\n"
		printf "${cyan}4. 返回上一级菜单${white}\n"
		printf "${cyan}=================================${white}\n"

		printf "${cyan}请输入选项并按回车:${white}"
		read -r choice

		case "$choice" in
			1)
				if ! check_node_installed;then
					printf "${red}请检查错误信息并重试${white}\n"
				fi
				;;
			2)
				node_version_selection_menu
				;;
			3)
				uninstall_node
				;;
			4)
				printf "${yellow}返回上一级菜单${white}\n"
				return
				;;
			*)
				printf "${red}无效选项,请重新输入${white}\n"
				;;
		esac
		printf "${cyan}按任意键继续${white}\n"
		read -n 1 -s -r
	done
}

node_menu