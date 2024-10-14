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

################################### Redis Start ###################################
# 检查Redis是否已安装
check_redis_installed() {
	local redis_conf_path=""
	local redis_install_dir=""
	local netstat_cmd="netstat"
	local ss_cmd="ss"
	local redis_service_name="redis"
	local redis_cli_path=""
	local redis_port_process
	local redis_port_owner
	local redis_process
	local redis_cli_dir=""
	local redis_cli_command="redis-cli"

	# 检查netstat是否存在，如果不存在则使用ss
	if ! command -v $netstat_cmd &> /dev/null; then
		netstat_cmd=""
	fi

	# 检查Redis配置文件
	for dir in /etc /opt /usr /usr/local; do
		if [ -d "$dir" ]; then
			redis_conf_path=$(find "$dir" -maxdepth 5 -type f \( -name '*redis.conf' -o -name '*redis*.conf' -o -name 'redis*.conf' \) 2>/dev/null | head -n 1)
			if [ -n "$redis_conf_path" ]; then
				printf "${yellow}找到Redis配置文件:$redis_conf_path${white}\n"
				redis_install_dir=$(dirname "$redis_conf_path")
				break
			fi
		fi
	done

	if [ -n "$redis_conf_path" ]; then
		printf "${yellow}Redis配置文件已找到,Redis已安装${white}\n"
		return 0
	fi

	# 检查端口6379使用和Redis服务情况
	local port_pattern=':6379\s+.*redis\b'
	
	if [ -n "$netstat_cmd" ]; then
		redis_port_process=$($netstat_cmd -lntpu 2>/dev/null | grep -E "$port_pattern" | head -n 1)
	else
		redis_port_process=$(ss -lntpu 2>/dev/null | grep -E "$port_pattern" | head -n 1)
	fi

	if [ -n "$redis_port_process" ]; then
		printf "${yellow}端口6379正在被Redis占用,Redis已安装${white}\n"
		return 0
	fi

	# 检查Redis服务状态
	if systemctl list-units --type=service 2>/dev/null | grep -Eiq "$redis_service_name"; then
		if systemctl is-active --quiet "$redis_service_name"; then
			printf "${yellow}Redis服务正在运行(systemd),Redis已安装${white}\n"
			return 0
		fi
	fi

	if service --status-all 2>/dev/null | grep -Eiq "$redis_service_name"; then
		if service "$redis_service_name" status 2>/dev/null | grep -Eq "running|active"; then
			printf "${yellow}Redis服务正在运行(init.d),Redis已安装${white}\n"
			return 0
		fi
	fi

	# 全局搜索redis-cli并验证
	redis_cli_path=$(find / -type f -name 'redis-cli' 2>/dev/null | head -n 1)
	if [ -n "$redis_cli_path" ]; then
		redis_cli_dir=$(dirname "$redis_cli_path")
		printf "${yellow}找到Redis客户端工具:$redis_cli_path${white}\n"

		# 进入redis-cli所在目录
		cd "$redis_cli_dir" || { printf "${yellow}无法进入目录:$redis_cli_dir${white}\n"; return 1; }

		# 检查redis-cli是否可执行
		if [ -x "./$redis_cli_command" ]; then
			printf "${yellow}Redis客户端工具可执行,Redis已安装${white}\n"
			return 0
		else
			printf "${yellow}找到Redis客户端工具但无法执行${white}\n"
		fi
	fi

	printf "${red}Redis未安装,请执行安装程序${white}\n"
	return 1
}

manage_redis_systemd() {
    local redis_version="$1"
    local redis_dir="/opt/redis-${redis_version}"
    local redis_service_file="/etc/systemd/system/redis.service"

    # 检查Redis安装目录
    if [ ! -d "$redis_dir" ]; then
        printf "${red}Redis安装目录不存在:${redis_dir}${white}\n"
        return 1
    fi

    # 创建或检查systemd服务文件
    if [ ! -f "$redis_service_file" ]; then
        tee "$redis_service_file" > /dev/null <<EOF
[Unit]
Description=Redis In-Memory Data Store
After=network.target

[Service]
Type=forking
ExecStart=${redis_dir}/src/redis-server ${redis_dir}/redis.conf
ExecStop=${redis_dir}/src/redis-cli -h 127.0.0.1 -p 6379 shutdown
Restart=always

# User=redis
# Group=redis

[Install]
WantedBy=multi-user.target
EOF
        check_command "创建Systemd服务文件失败:${redis_service_file}"
        printf "${green}创建Systemd服务文件成功:${redis_service_file}${white}\n"
    else
        printf "${yellow}Systemd服务文件已存在:${redis_service_file}${white}\n"
    fi

    # 重载systemd配置
    systemctl daemon-reload
    check_command "重载systemd配置失败"

    # 启用并启动Redis服务
    systemctl enable redis --now >/dev/null 2>&1
    check_command "启用Redis服务失败"

    # 检查Redis服务状态
    if ! systemctl is-active redis >/dev/null 2>&1; then
        printf "${red}Redis状态检查失败或服务无法启动,请检查安装日志或手动启动Redis服务${white}\n"
        return 1
    else
        printf "${green}Redis已完成自检,启动并设置开机自启${white}\n"
    fi

    # 显示Redis服务状态
    systemctl status redis --no-pager
}

# 安装指定版本的Redis(该函数为redis_version_selection_menu函数的调用子函数)
install_redis_version() {
    # 校验软件包下载路径
    create_software_dir

    # 校验Redis安装
    if ! check_redis_installed >/dev/null 2>&1; then
        printf "${yellow}正在${os_release}上安装!${white}\n"
    else
        printf "${red}Redis已安装${white}\n"
        return # 返回redis菜单
    fi

    # 定义版本号和下载目录
    local version="$1"
    local redis_download_dir="$SOFTWARE_DIR/redis"
    local redis_url="http://download.redis.io/releases/redis-${version}.tar.gz"
    local redis_dir="/opt/redis-${version}"

    # 删除旧的下载目录(包括其中的所有文件)
    if [ -d "$redis_download_dir" ]; then
        rm -fr "$redis_download_dir"
        printf "${yellow}历史下载目录已删除:${redis_download_dir}${white}\n"
    fi

    # 创建新的下载目录
    mkdir -p "$redis_download_dir"
    check_command "目录创建失败:${redis_download_dir}"
    if [ $? -eq 0 ]; then
        printf "${green}软件安装目录创建成功:${redis_download_dir}${white}\n"
    fi

    # 检查并安装依赖
    for package in net-tools wget; do
        if ! rpm -q $package >/dev/null 2>&1; then
            yum install $package -y >/dev/null 2>&1
            printf "${yellow}安装并检查依赖:${package}${white}\n"
        fi
    done

    # 下载Redis软件包
    wget --progress=bar:force -P "$redis_download_dir" "$redis_url"
    check_command "下载Redis安装包失败"

    # 解压Redis软件包
    mkdir -p "$redis_dir"
    check_command "创建Redis安装目录失败:${redis_dir}"
    tar xvf "$redis_download_dir/redis-${version}.tar.gz" -C "$redis_dir" --strip-components=1
    check_command "解压Redis安装包失败"

    # 编译Redis
    cd "$redis_dir" || return
    make
    check_command "编译Redis失败"

    # 使用make install将Redis安装到指定目录
    make PREFIX="$redis_dir" install
    check_command "安装Redis失败"

    # 备份当前的配置文件
    \cp -f "$redis_dir"/redis.conf "$redis_dir"/redis.conf.bak

    # 修改redis.conf文件
    sed -i 's/^daemonize no/daemonize yes/' "$redis_dir"/redis.conf

    # 删除安装包
    rm -f "$redis_download_dir/redis-${version}.tar.gz"

    # 管理 Redis systemd 服务
    manage_redis_systemd ${version}

    # 清理安装包文件和下载路径
    if [ -d "$redis_download_dir" ]; then
        rm -rf "$redis_download_dir"
        printf "${green}安装包目录已清空并删除:${redis_download_dir}${white}\n"
    else
        printf "${red}文件下载目录不存在,无需清理${white}\n"
    fi
}

# 提供Redis版本选择菜单并调用install_redis_version函数的Redis安装总函数
redis_version_selection_menu() {
	local choice

	while true; do
		clear
		printf "${cyan}=================================${white}\n"
		printf "${cyan}         选择Redis版本           ${white}\n"
		printf "${cyan}=================================${white}\n"
		printf "${cyan}1. 安装Redis 7.0.5${white}\n"
		printf "${cyan}2. 安装Redis 7.0.9${white}\n"
		printf "${cyan}3. 安装Redis 7.2.5${white}\n"
		printf "${cyan}4. 返回上一级菜单${white}\n"
		printf "${cyan}=================================${white}\n"

		# 读取用户选择
		printf "${cyan}请输入选项并按回车:${white}"
		read -r choice

		case "$choice" in
			1)
				install_redis_version "7.0.5"
				;;
			2)
				install_redis_version "7.0.9"
				;;
			3)
				install_redis_version "7.2.5"
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

# 卸载Redis
uninstall_redis() {
    # 校验Redis是否安装
    if ! check_redis_installed >/dev/null 2>&1; then
        printf "${red}Redis未安装,无需卸载${white}\n"
        return
    fi

    # 默认Redis安装目录
    local redis_base_dir="/opt/redis"
    local redis_service_file="/etc/systemd/system/redis.service"

    # 查找Redis版本
    local version
    version=$(ls -d ${redis_base_dir}-*/ 2>/dev/null | sed 's|.*/redis-||; s|/||')
    if [ -z "$version" ]; then
        printf "${red}Redis安装目录不存在或未找到版本号${white}\n"
        return 1
    fi

    local redis_dir="${redis_base_dir}-${version}"

	printf "${yellow}停止并禁用Redis服务${white}\n"
    if systemctl is-active redis >/dev/null 2>&1; then
        systemctl disable redis --now >/dev/null 2>&1
        check_command "无法停止并禁用Redis服务"
		printf "${green}Redis服务已停止并禁用${white}\n"
	else
        printf "${green}Redis服务已停止${white}\n"
    fi

    # 删除systemd服务文件
    if [ -f "$redis_service_file" ]; then
        rm -f "$redis_service_file"
        check_command "删除systemd服务文件失败:${redis_service_file}"
        printf "${green}删除systemd服务文件成功:${redis_service_file}${white}\n"
    else
        printf "${yellow}systemd服务文件不存在:${redis_service_file}${white}\n"
    fi

    # 删除Redis安装目录
    if [ -d "$redis_dir" ]; then
        rm -rf "$redis_dir"
        check_command "删除Redis安装目录失败:${redis_dir}"
        printf "${green}删除Redis安装目录成功:${redis_dir}${white}\n"
    else
        printf "${yellow}Redis安装目录不存在:${redis_dir}${white}\n"
    fi

    # 刷新systemd配置
    systemctl daemon-reload
    check_command "重载systemd配置失败"
}

# 控制Redis服务的状态
control_redis() {
    local action="${1:-status}"
    local redis_service_name="redis"

    case "$action" in
        status)
            if ! check_redis_installed; then
                return # 返回Redis菜单
            fi

            # 查找Redis进程
            if ps -ef | grep '[r]edis-server' >/dev/null 2>&1; then
                printf "${yellow}Redis进程信息:\n$(ps -ef | grep '[r]edis-server')${white}\n"
                systemctl status "$redis_service_name"
            else
                printf "${red}未找到Redis进程信息${white}\n"
                # 检查服务状态
                if systemctl is-active "$redis_service_name" >/dev/null 2>&1; then
                    printf "${yellow}Redis服务正在运行,但未找到进程信息${white}\n"
                else
                    printf "${yellow}Redis服务未启动${white}\n"
                fi
            fi
            ;;
        start)
            if ! check_redis_installed; then
                return # 返回Redis菜单
            fi

            # 检查Redis是否已经在运行
            if systemctl is-active "$redis_service_name" >/dev/null 2>&1; then
                printf "${red}Redis已运行,请不要重复启动!${white}\n"
            else
                systemctl enable "$redis_service_name" --now >/dev/null 2>&1
                if systemctl is-active "$redis_service_name" >/dev/null 2>&1; then
                    printf "${green}Redis启动成功!${white}\n"
                else
                    printf "${red}Redis启动失败${white}\n"
                fi
            fi
            ;;
        stop)
            if ! check_redis_installed; then
                return # 返回Redis菜单
            fi

            if ! systemctl is-active "$redis_service_name" >/dev/null 2>&1; then
                printf "${yellow}Redis已经停止,无需停止${white}\n"
            else
                systemctl disable "$redis_service_name" --now >/dev/null 2>&1
                if ! systemctl is-active "$redis_service_name" >/dev/null 2>&1; then
                    printf "${green}Redis停止成功!${white}\n"
                else
                    printf "${red}Redis停止失败!${white}\n"
                fi
            fi
            ;;
        *)
            printf "${red}无效的操作参数:${action}${white}\n"
            return 1
            ;;
    esac
    return 0
}

# 管理 Make 安装的菜单
redis_menu() {
	local choice
	while true; do
		clear
		printf "${cyan}=================================${white}\n"
		printf "${cyan}          Redis管理菜单          ${white}\n"
		printf "${cyan}=================================${white}\n"
		printf "${cyan}1. 查看Redis服务${white}\n"
		printf "${cyan}2. 启动Redis服务${white}\n"
		printf "${cyan}3. 停止Redis服务${white}\n"
		printf "${cyan}4. 安装Redis服务${white}\n"
		printf "${cyan}5. 卸载Redis服务${white}\n"
		printf "${cyan}6. 返回主菜单${white}\n"
		printf "${cyan}=================================${white}\n"

		printf "${cyan}请输入选项并按回车:${white}"
		read -r choice

		case "$choice" in
			1)
				control_redis status
				;;
			2)
				control_redis start
				;;
			3)
				control_redis stop
				;;
			4)
				redis_version_selection_menu
				;;
			5)
				uninstall_redis
				;;
			6)
				printf "${yellow}返回主菜单${white}\n"
				#return
				exit
				;;
			*)
				printf "${red}无效选项, 重新选择!${white}\n"
				;;
		esac
		printf "${cyan}按任意键继续${white}\n"
		read -n 1 -s -r
	done
}
################################### Redis END ###################################
redis_menu
