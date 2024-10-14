#!/bin/bash

set -o errexit
clear

os_release=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d '"' -f 2 | sed 's/ (.*//')

# ANSI颜色码,用于彩色输出
yellow='\033[1;33m' # 提示信息
red='\033[1;31m'    # 警告信息
green='\033[1;32m'  # 成功信息
blue='\033[1;34m'   # 一般信息
cyan='\033[1;36m'   # 特殊信息
purple='\033[1;35m' # 紫色或粉色信息
gray='\033[1;30m'   # 灰色信息
white='\033[0m'     # 结束颜色设置

download_dir="/opt/software"

check_download_dir() {
    if [ ! -d "$download_dir" ]; then
        mkdir -p "$download_dir"
    fi
}

check_mysql_installed() {
	if command -v mysql >/dev/null 2>&1 && command -v mysqladmin >/dev/null 2>&1; then
		local mysql_version
		mysql_version=$(mysql --version 2>&1)

		if [[ "$mysql_version" =~ ([0-9]+\.[0-9]+\.[0-9]+) ]]; then
			mysql_version="${BASH_REMATCH[1]}"
			printf "${green}MySQL已安装,版本为:${mysql_version}${white}\n"
		else
			printf "${red}无法确定MySQL版本.${white}\n"
		fi
	else
		printf "${red}MySQL未安装,请执行安装程序.${white}\n"
	fi
}

# 检查MySQL
control_mysql() {
	local action="${1:-status}"

	case "$action" in
		start)
			if ! check_mysql_installed; then
				printf "${red}未安装MySQL.${white}\n"
				return
			fi

			# 检查MySQL是否已经在运行
			if systemctl is-active mysqld >/dev/null 2>&1; then
				printf "${yellow}MySQL已经在运行中,无需启动.${white}\n"
			else
				systemctl enable mysqld --now
				if systemctl is-active mysqld >/dev/null 2>&1; then
					printf "${green}MySQL启动成功!${white}\n"
				else
					printf "${red}MySQL启动失败!${white}\n"
				fi
			fi
			;;
		stop)
			if ! check_mysql_installed; then
				printf "${red}未安装MySQL.${white}\n"
				return
			fi

			if ! systemctl is-active mysqld >/dev/null 2>&1; then
				printf "${yellow}MySQL已经停止,无需停止.${white}\n"
			else
				systemctl disable mysqld --now
				if systemctl is-active mysqld >/dev/null 2>&1; then
					printf "${red}MySQL停止失败!${white}\n"
				else
					printf "${green}MySQL停止成功!${white}\n"
				fi
			fi
			;;
		status)
			if ! check_mysql_installed; then
				printf "${red}未安装MySQL.${white}\n"
				return
			fi
		
			# 查找MySQL进程
			if ps -ef | grep '[m]ysqld' >/dev/null 2>&1; then
				printf "${yellow}MySQL进程信息:\n$(ps -ef | grep '[m]ysqld')${white}\n"
				systemctl status mysqld
			else
				printf "${red}未找到MySQL进程信息.${white}\n"
				# 检查服务状态
				if systemctl is-active mysqld >/dev/null 2>&1; then
					printf "${yellow}MySQL服务正在运行,但未找到进程信息.${white}\n"
				else
					printf "${yellow}MySQL服务未启动.${white}\n"
				fi
			fi
			;;
		*)
			printf "${red}无效的操作参数: ${action}${white}\n"
			return
			;;
	esac
}

# 下载或生成my.cnf配置文件
generate_mysql_config() {
	if wget -q -O /etc/my.cnf https://raw.githubusercontent.com/honeok8s/conf/main/mysql/my-4C8G.cnf; then
		printf "${green}MySQL配置文件已成功下载.${white}\n"
	else
	# 如果下载失败,使用EOF语法生成文件
		cat <<EOF > /etc/my.cnf
# For advice on how to change settings please see
# http://dev.mysql.com/doc/refman/8.0/en/server-configuration-defaults.html
[mysql]
default-character-set=utf8mb4

[mysqld]
#
# Remove leading # and set to the amount of RAM for the most important data
# cache in MySQL. Start at 70% of total RAM for dedicated server, else 10%.
# innodb_buffer_pool_size = 128M
#
# Remove the leading "# " to disable binary logging
# Binary logging captures changes between backups and is enabled by
# default. It's default setting is log_bin=binlog
# disable_log_bin
#
# Remove leading # to set options mainly useful for reporting servers.
# The server defaults are faster for transactions and fast SELECTs.
# Adjust sizes as needed, experiment to find the optimal values.
# join_buffer_size = 128M
# sort_buffer_size = 2M
# read_rnd_buffer_size = 2M
#
# Remove leading # to revert to previous value for default_authentication_plugin,
# this will increase compatibility with older clients. For background, see:
# https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_default_authentication_plugin
# default-authentication-plugin=mysql_native_password
port=3306
default-storage-engine=INNODB # 默认存储引擎
character-set-server=utf8mb4  # 字符集设置
default-authentication-plugin=mysql_native_password # 默认身份验证插件
skip-log-bin      # 禁用二进制日志功能
skip-name-resolve # 禁用名称解析

datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock

log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid

slow_query_log = ON # 慢查询日志开启
#long_query_time = 5 # 慢查询阈值设置为5秒
slow_query_log_file = /var/lib/mysql/slow.log

max_connections=500 # 最大连接数
tmp_table_size=32M  # 临时表大小
myisam_sort_buffer_size=64M # MyISAM排序缓冲区大小
innodb_log_buffer_size=256M # InnoDB日志缓冲区大小
innodb_buffer_pool_size=1024M # InnoDB缓冲池大小
innodb_log_file_size=1024M    # InnoDB日志文件大小
innodb_open_files=500   # InnoDB打开文件数
max_allowed_packet=256M # 最大允许的数据包大小
max_connect_errors=100  # 最大连接错误数
connect_timeout=60      # 连接超时时间
net_read_timeout=60     # 网络读取超时时间
log_timestamps = SYSTEM # 日志时间戳格式
expire_logs_days =2
#binlog_expire_logs_seconds=172800 # 二进制日志过期时间2天
max_binlog_size=512M     # 最大二进制日志文件大小
read_rnd_buffer_size =1M # 随机读缓冲区大小
read_buffer_size =1M     # 读取缓冲区大小
sort_buffer_size =1M     # 排序缓冲区大小
sql_mode = STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION # SQL模式设置

[client]
default-character-set=utf8mb4
socket=/var/lib/mysql/mysql.sock
EOF
	fi
}

# MySQL初始化
initialize_mysql() {
	local dbroot_passwd=$(openssl rand -base64 15)

	# 检查是否已经初始化过 MySQL
	if grep -q "MySQL init process done. Ready for start up." /var/log/mysqld.log; then
		printf "${red}MySQL已经初始化过,请不要重复初始化.${white}\n"
		return
	fi

	echo "ALTER USER 'root'@'localhost' IDENTIFIED BY '${dbroot_passwd}';" > /tmp/mysql-init
	if mysqld --initialize --user=mysql --init-file=/tmp/mysql-init; then
		rm -f /tmp/mysql-init
		printf "${green}通过指定配置文件初始化MySQL成功!${white}\n"
		printf "${yellow}MySQL Root密码:$dbroot_passwd${white}\n"
	else
		printf "${red}MySQL初始化失败.${white}\n"
		rm -f /tmp/mysql-init
		return
	fi
}

# MySQL安装
mysql_install() {
	check_download_dir
	if ! check_mysql_installed; then
		printf "${yellow}正在${os_release}上安装! ${white}\n"
	else
		printf "${red}MySQL已安装!${white}\n"
		return
	fi

	cd "$download_dir" || exit 1

	# 检查临时文件夹权限,由于mysql安装中会通过mysql用户在/tmp目录下新建tmp_db文件,所以给/tmp较大权限
	if [ "$(stat -c '%A' /tmp)" != "drwxrwxrwt" ]; then
		chmod -R 777 /tmp
		printf "${yellow}已更新/tmp目录权限为777!${white}\n"
	fi

	# 检查并卸载冲突的包
	for package in mariadb-libs mysql-libs; do
		if rpm -q $package >/dev/null 2>&1; then
			yum remove $package -y >/dev/null 2>&1
			printf "${yellow} 正在卸载冲突文件:${package}${white}\n"
		fi
	done

	# 检查并安装依赖
	for package in libaio net-tools; do
		if ! rpm -q $package >/dev/null 2>&1; then
			yum install $package -y >/dev/null 2>&1
			printf "${yellow} 安装并检查依赖:${package}${white}\n"
		fi
	done

	# 下载 MySQL
	wget --progress=bar:force -P $download_dir https://downloads.mysql.com/archives/get/p/23/file/mysql-8.0.26-1.el7.x86_64.rpm-bundle.tar
	printf "${yellow}正在解压MySQL并执行安装.${white}\n"
	tar xvf mysql-8.0.26-1.el7.x86_64.rpm-bundle.tar
	rm -f mysql-8.0.26-1.el7.x86_64.rpm-bundle.tar

	# 安装MySQL,必须安装顺序执行
	for package in \
		mysql-community-common-8.0.26-1.el7.x86_64.rpm \
		mysql-community-client-plugins-8.0.26-1.el7.x86_64.rpm \
		mysql-community-libs-8.0.26-1.el7.x86_64.rpm \
		mysql-community-client-8.0.26-1.el7.x86_64.rpm \
		mysql-community-server-8.0.26-1.el7.x86_64.rpm; do

		if rpm -ivh $package; then
			printf "${green} MySQL安装包安装成功:${package}${white}\n"
			rm -f "$package"
		else
			printf "${red} MySQL安装包安装失败:${package}${white}\n"
			return
		fi
	done

	printf "${green}MySQL所有包安装完毕!${white}\n"

	# 验证安装
	check_mysql_installed

	# 备份当前的my.cnf文件
	mv /etc/my.cnf{,.bak}
	# 下载基础配置文件my-4C8G.cnf
	generate_mysql_config

	# 根据服务器性能调优
	# 获取CPU核数和内存大小（单位为MB）
	# local num_cores=$(grep -c ^processor /proc/cpuinfo)
	local num_cores=$(nproc)
	local memory_size=$(free -m | awk '/^Mem:/{print $2}')

	# 根据内存大小调整参数
	if [ "$memory_size" -ge 7500 ] && [ "$memory_size" -le 8000 ]; then
		printf "${yellow}8GB内存配置,使用默认配置${white}\n"
	elif [ "$memory_size" -ge 3500 ] && [ "$memory_size" -le 4000 ]; then
		sed -ri "s/^max_connections=.*/max_connections=300/" /etc/my.cnf
		sed -ri "s/^tmp_table_size=.*/tmp_table_size=16M/" /etc/my.cnf
		sed -ri "s/^myisam_sort_buffer_size=.*/myisam_sort_buffer_size=32M/" /etc/my.cnf
		sed -ri "s/^innodb_log_buffer_size=.*/innodb_log_buffer_size=128M/" /etc/my.cnf
		sed -ri "s/^innodb_buffer_pool_size=.*/innodb_buffer_pool_size=512M/" /etc/my.cnf
		sed -ri "s/^innodb_log_file_size=.*/innodb_log_file_size=512M/" /etc/my.cnf
		sed -ri "s/^innodb_open_files=.*/innodb_open_files=300/" /etc/my.cnf
		sed -ri "s/^max_allowed_packet=.*/max_allowed_packet=128M/" /etc/my.cnf
		sed -ri "s/^max_connect_errors=.*/max_connect_errors=50/" /etc/my.cnf
		sed -ri "s/^max_binlog_size=.*/max_binlog_size=256M/" /etc/my.cnf
		sed -ri "s/^read_rnd_buffer_size =.*/read_rnd_buffer_size = 512K/" /etc/my.cnf
		sed -ri "s/^read_buffer_size =.*/read_buffer_size = 512K/" /etc/my.cnf
		sed -ri "s/^sort_buffer_size =.*/sort_buffer_size = 512K/" /etc/my.cnf
		printf "${yellow}MySQL配置文件已更新并根据服务器配置动态调整完成.${white}\n"
	elif [ "$memory_size" -ge 1500 ] && [ "$memory_size" -le 2000 ]; then
		sed -ri "s/^max_connections=.*/max_connections=200/" /etc/my.cnf
		sed -ri "s/^tmp_table_size=.*/tmp_table_size=8M/" /etc/my.cnf
		sed -ri "s/^myisam_sort_buffer_size=.*/myisam_sort_buffer_size=16M/" /etc/my.cnf
		sed -ri "s/^innodb_log_buffer_size=.*/innodb_log_buffer_size=64M/" /etc/my.cnf
		sed -ri "s/^innodb_buffer_pool_size=.*/innodb_buffer_pool_size=256M/" /etc/my.cnf
		sed -ri "s/^innodb_log_file_size=.*/innodb_log_file_size=256M/" /etc/my.cnf
		sed -ri "s/^innodb_open_files=.*/innodb_open_files=200/" /etc/my.cnf
		sed -ri "s/^max_allowed_packet=.*/max_allowed_packet=64M/" /etc/my.cnf
		sed -ri "s/^max_connect_errors=.*/max_connect_errors=20/" /etc/my.cnf
		sed -ri "s/^max_binlog_size=.*/max_binlog_size=128M/" /etc/my.cnf
		sed -ri "s/^read_rnd_buffer_size =.*/read_rnd_buffer_size = 256K/" /etc/my.cnf
		sed -ri "s/^read_buffer_size =.*/read_buffer_size = 256K/" /etc/my.cnf
		sed -ri "s/^sort_buffer_size =.*/sort_buffer_size = 256K/" /etc/my.cnf
		printf "${yellow}MySQL配置文件已更新并根据服务器配置动态调整完成.${white}\n"
	else
		printf "${red}未知内存配置,未做修改.${white}\n"
	fi

	# 调用函数进行MySQL初始化
	if initialize_mysql; then
		printf "${green}MySQL初始化成功!${white}\n"
	else
		printf "${red}MySQL初始化失败.${white}\n"
		return
	fi
	
	systemctl enable mysqld --now >/dev/null 2>&1
	
	# 检查MySQL服务是否处于活动状态
	if ! systemctl is-active mysqld >/dev/null 2>&1; then
		printf "${red}错误:MySQL状态检查失败或服务无法启动,请检查安装日志或手动启动MySQL服务. ${white}\n"
		return
	else
		printf "${green}MySQL已完成自检,启动并设置开机自启. ${white}\n"
	fi
	
	echo ""
	
	# 清理安装包文件
	rm -f mysql-community*
}

# MySQL卸载
mysql_uninstall() {
	if ! check_mysql_installed; then
		return
	fi

	local MAXDEPTH=5

	systemctl is-active mysqld >/dev/null 2>&1 && systemctl disable mysqld --now >/dev/null 2>&1

	# 遍历并卸载每个已安装的 MySQL 包
	for package in $(rpm -qa | grep -iE '^mysql-community-'); do
		if yum remove "$package" -y; then
			printf "${green}成功卸载:$package${white}\n"
		else
			printf "${red}卸载失败:$package${white}\n"
		fi
	done

	# 查找并删除与MySQL相关的文件夹
	[ -f /var/log/mysqld.log ] && rm -f /var/log/mysqld.log || true
	find / -maxdepth $MAXDEPTH -type d -name '*mysql*' 2>/dev/null | xargs rm -fr

	[ -f /etc/my.cnf ] && rm -f /etc/my.cnf
	printf "${green}MySQL卸载完成.${white}\n"
}

##########
# MySQL子菜单
mysql_menu() {
    while true; do
		clear
		printf "${cyan}=== MySQL 操作 ===${white}\n"
		printf "${cyan}1. 查看MySQL服务${white}\n"
		printf "${cyan}2. 启动MySQL服务${white}\n"
		printf "${cyan}3. 停止MySQL服务${white}\n"
		printf "${cyan}4. 安装MySQL服务${white}\n"
		printf "${cyan}5. 卸载MySQL服务${white}\n"
		printf "${cyan}6. 返回主菜单.${white}\n"

		printf "${cyan}请输入选项数字并按Enter键: ${white}"
		read choice

		case $choice in
			1)
				control_mysql status
				;;
			2)
				control_mysql start
				;;
			3)
				control_mysql stop
				;;
			4)
				mysql_install
				;;
			5)
				mysql_uninstall
				;;
			6)
				printf "${yellow}返回主菜单.${white}\n"
				return
				;;
			*)
				printf "${red}无效选项,请重新输入${white}\n"
				;;
		esac
		printf "${cyan}按任意键继续.${white}"
		read -n 1 -s -r -p ""
	done
}
##########
# 主菜单函数
main() {
	while true; do
		clear
		printf "${cyan}=== 服务器管理菜单 ===${white}\n"
		printf "${cyan}1. MySQL管理${white}\n"
		printf "${cyan}2. 退出${white}\n"

		printf "${cyan}请输入选项数字并按Enter键: ${white}"
		read choice

		case $choice in
			1)
				mysql_menu
				;;
			2)
				printf "${yellow}Bye!${white}\n"
				exit 0
				;;
			*)
				printf "${red}无效选项,请重新输入${white}\n"
				;;
		esac
		printf "${cyan}按任意键继续.${white}"
		read -n 1 -s -r -p ""
	done
}

if [[ $EUID -ne 0 ]]; then
	printf "${red}此脚本必须以root用户身份运行. ${white}\n"
	exit 1
fi

main
exit 0