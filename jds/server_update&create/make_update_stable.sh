#!/bin/bash

# ANSI颜色码，用于彩色输出
yellow='\033[1;33m'
red='\033[1;31m'
green='\033[1;32m'
cyan='\033[1;36m'
white='\033[0m'

# 安装路径和备份路径
SOFTWARE_DIR="/opt/software"
BACKUP_DIR="/opt/backup"

# 检查命令是否成功执行
check_command() {
	if [ $? -ne 0 ]; then
		printf "${red}$1${white}\n"
		return 1
	fi
}

# 创建安装目录(如果不存在)
create_software_dir() {
	if [ ! -d "$SOFTWARE_DIR" ]; then
		printf "${yellow}创建软件包下载路径:${SOFTWARE_DIR}${white}\n"
		mkdir -p "$SOFTWARE_DIR"
		check_command "创建路径失败"
		printf "${green}软件包下载路径${SOFTWARE_DIR}创建成功!${white}\n"
	fi
}

# 打印当前的 make 版本
print_current_make_version() {
	local versions=("4.2" "4.3" "4.4")
	local current_version
	local upgrade_versions=()
	local need_upgrade=0
	local latest_version="${versions[-1]}"  # 取最高版本

	if command -v make &> /dev/null; then
		current_version=$(make --version | grep -oP '\d+\.\d+(\.\d+)?' | head -n1)
		printf "${yellow}当前已安装的make版本: ${current_version}${white}\n"

		for version in "${versions[@]}"; do
			IFS='.' read -r -a current_parts <<< "$current_version"
			IFS='.' read -r -a version_parts <<< "$version"

			for ((i=0; i<${#version_parts[@]}; i++)); do
				if [ "${current_parts[i]:-0}" -lt "${version_parts[i]}" ]; then
					upgrade_versions+=("$version")
					need_upgrade=1
					break
				elif [ "${current_parts[i]:-0}" -gt "${version_parts[i]}" ]; then
					break
				fi
			done
		done

		if [ $need_upgrade -eq 1 ]; then
			printf "${yellow}当前make版本是: ${current_version},可升级到当前脚本支持的稳定版:%s${white}\n" "$(IFS=,; echo "${upgrade_versions[*]}")"
		else
			if [[ $(printf '%s\n' "$current_version" "$latest_version" | sort -V | head -n1) == "$latest_version" ]]; then
				printf "${yellow}当前make版本是:${current_version},比当前脚本支持的所有稳定版高,无需升级!${white}\n"
			else
				printf "${yellow}当前make版本是:${current_version},已是最新的稳定版,无需升级!${white}\n"
			fi
		fi
	else
		printf "${red}系统中未安装make!${white}\n"
	fi
}

# 获取用户输入的make版本
select_make_version() {
	local versions=("4.2" "4.3" "4.4")
	local choice

	while true; do
		printf "${cyan}请选择要安装的make版本:${white}\n"

		for i in "${!versions[@]}"; do
			printf "${cyan}%d. %s${white}\n" $((i + 1)) "${versions[i]}"
		done

		printf "${cyan}4. 返回菜单${white}\n"
		printf "${cyan}请输入选项(1-4): ${white}"
		read -r choice

		case "$choice" in
			[1-3])
				make_version="${versions[choice-1]}"
				printf "${green}选择版本: make ${make_version}${white}\n"
				return 0
				;;
			4)
				return 1
				;;
			*)
				printf "${red}无效选项, 重新选择${white}\n"
				;;
		esac
	done
}

# 安装 make
install_make_version() {
	local make_version
	local software_list=("wget" "tar")

	for software in "${software_list[@]}"; do
		if ! command -v "$software" &> /dev/null; then
			printf "${yellow}当前环境缺少软件包$software,正在安装${white}\n"
			yum install "$software" -y >/dev/null 2>&1
			check_command "安装${software}失败"
		fi
	done

	printf "${yellow}选择要安装的make版本:${white}\n"
	if select_make_version; then
		if [ -z "$make_version" ]; then
			return 1
		fi
	else
		return 1
	fi

	create_software_dir

	local make_source_dir="${SOFTWARE_DIR}/make-${make_version}"
	local make_tar="${SOFTWARE_DIR}/make-${make_version}.tar.gz"
    
	cd "$SOFTWARE_DIR" || { printf "${red}无法进入目录:${SOFTWARE_DIR}.${white}\n"; return 1; }

	wget "https://mirrors.aliyun.com/gnu/make/make-${make_version}.tar.gz" -O "${make_tar}"
	check_command "下载make源代码失败"

	if [ ! -f "${make_tar}" ] || [ ! -s "${make_tar}" ]; then
		printf "${red}下载的文件不存在或为空${white}\n"
		return 1
	fi

	tar xvf "${make_tar}" -C .. || { printf "${red}解压make源代码失败${white}\n"; return 1; }

	cd "../make-${make_version}/" || { printf "${red}无法进入make-${make_version}目录${white}\n"; return 1; }

	mkdir build
	cd build || { printf "${red}无法进入build目录${white}\n"; return 1; }

	../configure --prefix=/usr
	check_command "配置make失败"

	make
	check_command "编译make失败"

	make install
	check_command "安装make失败"

	printf "${green}make ${make_version}安装成功!${white}\n"


	if [ -f "${make_tar}" ]; then
		rm -f "${make_tar}"
		printf "${green}安装包${make_tar}已删除${white}\n"
	else
		printf "${yellow}安装包${make_tar}不存在,无需删除${white}\n"
	fi

	if command -v make &> /dev/null; then
		printf "${yellow}当前已安装的make版本:${white}\n"
		make --version
	else
		printf "${red}系统中未安装make${white}\n"
	fi
}

# 管理 Make 安装的菜单
make_menu() {
	while true; do
		clear
		printf "${cyan}=================================${white}\n"
		printf "${cyan}       Make 管理菜单             ${white}\n"
		printf "${cyan}=================================${white}\n"
		printf "${cyan}1. 查看当前make版本${white}\n"
		printf "${cyan}2. 选择make版本并安装${white}\n"
		printf "${cyan}3. 返回上一级目录${white}\n"
		printf "${cyan}=================================${white}\n"
		printf "${cyan}请输入选项并按回车:${white}"
		read -r choice

		case "$choice" in
			1)
				print_current_make_version
				;;
			2)
				if ! install_make_version; then
					printf "${red}安装失败, 重新选择选项.${white}\n"
					continue
				fi
				;;
			3)
				printf "${green}退出程序${white}\n"
				exit 0
				;;
			*)
				printf "${red}无效选项, 重新选择!${white}\n"
				;;
		esac
		printf "${cyan}按任意键继续${white}\n"
		read -n 1 -s -r
	done
}

# 运行菜单
make_menu
