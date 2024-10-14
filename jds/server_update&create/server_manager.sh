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

# MySQL函数1
# 检查MySQL是否已安装
check_mysql_installed() {
	if command -v mysql >/dev/null 2>&1 && command -v mysqladmin >/dev/null 2>&1; then
		local mysql_version
		mysql_version=$(mysql --version 2>&1)

		if [[ "$mysql_version" =~ ([0-9]+\.[0-9]+\.[0-9]+) ]]; then
			mysql_version="${BASH_REMATCH[1]}"
			printf "${yellow}MySQL已安装, 版本为: ${mysql_version}${white}\n"
			return 0
		else
			printf "${red}无法确定MySQL版本${white}\n"
			return 1
		fi
	else
		printf "${red}MySQL未安装, 请执行安装程序${white}\n"
		return 1
	fi
}

# MySQL函数2
# 优化和自动生成MySQL配置文件
generate_mysql_config() {
	local url="https://raw.githubusercontent.com/honeok8s/conf/main/mysql/mysql_server_manager_config.cnf"
	local dest="/etc/my.cnf"
	local expected_checksum="b0a5cf17be27e3797cc9118fe81393d3e82d1339257a6823542df5287b3ad3ba"

	# 尝试下载文件并进行完整性校验
	for i in {1..3}; do
		# 下载文件
		if wget -q -O "$dest" "$url"; then
			printf "${green}MySQL配置文件已成功下载${white}\n"

			# 校验文件完整性
			if echo "$expected_checksum $dest" | sha256sum -c -; then
				printf "${green}文件完整性校验通过${white}\n"
				return
			else
				printf "${red}文件完整性校验失败${white}\n"
			fi
		else
			printf "${red}从Github拉取配置文件失败,第$i次重试${white}\n"
		fi
	done

	# 如果所有重试都失败,则使用EOF语法生成文件
	printf "${yellow}下载失败,重试次数已用尽,使用默认配置生成文件${white}\n"

	cat <<EOF > "$dest"
# For advice on how to change settings please see
# http://dev.mysql.com/doc/refman/8.0/en/server-configuration-defaults.html
[mysql]
default-character-set=utf8mb4

[mysqld]

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
long_query_time = 5 # 慢查询阈值设置为5秒
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
}

# MySQL函数3
# 初始化MySQL
initialize_mysql() {
	local dbroot_passwd=$(openssl rand -base64 15)

	# 检查是否已经初始化过 MySQL
	if grep -q "MySQL init process done. Ready for start up." /var/log/mysqld.log; then
		printf "${red}MySQL已经初始化过,请不要重复初始化${white}\n"
		return
	fi

	echo "ALTER USER 'root'@'localhost' IDENTIFIED BY '${dbroot_passwd}';" > /tmp/mysql-init
	if mysqld --initialize --user=mysql --init-file=/tmp/mysql-init; then
		rm -f /tmp/mysql-init >/dev/null 2>&1
		printf "${green}通过指定配置文件初始化MySQL成功!${white}\n"
		printf "${yellow}MySQL Root密码: $dbroot_passwd 请妥善保管${white}\n"
	else
		printf "${red}MySQL初始化失败.${white}\n"
		rm -f /tmp/mysql-init >/dev/null 2>&1
		return
	fi
}

# MySQL调优
optimize_mysql_performance() {
    # 获取系统的 CPU 核数
    local num_cores=$(nproc)
    # 获取系统的总内存大小（单位：MB）
    local memory_size=$(free -m | awk '/^Mem:/{print $2}')

    # 根据内存和CPU核数调整MySQL参数
    if [ "$memory_size" -ge 7500 ] && [ "$memory_size" -le 8192 ] && [ "$num_cores" -ge 4 ] && [ "$num_cores" -le 6 ]; then
        # 如果内存在7500MB到8000MB之间且CPU核数在4到6之间,使用默认配置
        printf "${yellow}检测到当前8GB内存且CPU核数为4至6,使用默认配置${white}\n"
	# 1核1GB内存
	elif [ "$memory_size" -ge 950 ] && [ "$memory_size" -le 1024 ] && [ "$num_cores" -eq 1 ]; then
		printf "${yellow}检测到当前1GB内存且CPU核数为1,已调整配置文件${white}\n"
		sed -i -r '
			s/^[[:space:]]*max_connections[[:space:]]*=[[:space:]]*[0-9]+/max_connections = 50/
			s/^[[:space:]]*tmp_table_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/tmp_table_size = 4M/
			s/^[[:space:]]*myisam_sort_buffer_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/myisam_sort_buffer_size = 8M/
			s/^[[:space:]]*innodb_log_buffer_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/innodb_log_buffer_size = 32M/
			s/^[[:space:]]*innodb_buffer_pool_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/innodb_buffer_pool_size = 64M/
			s/^[[:space:]]*innodb_log_file_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/innodb_log_file_size = 64M/
			s/^[[:space:]]*innodb_open_files[[:space:]]*=[[:space:]]*[0-9]+/innodb_open_files = 50/
			s/^[[:space:]]*max_allowed_packet[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/max_allowed_packet = 32M/
			s/^[[:space:]]*max_connect_errors[[:space:]]*=[[:space:]]*[0-9]+/max_connect_errors = 10/
			s/^[[:space:]]*max_binlog_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/max_binlog_size = 32M/
			s/^[[:space:]]*read_rnd_buffer_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/read_rnd_buffer_size = 64K/
			s/^[[:space:]]*read_buffer_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/read_buffer_size = 64K/
			s/^[[:space:]]*sort_buffer_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/sort_buffer_size = 64K/
		' /etc/my.cnf
		printf "${green}MySQL配置文件已更新并根据服务器配置动态调整完成${white}\n"
	# 1核2GB内存
	elif [ "$memory_size" -ge 1800 ] && [ "$memory_size" -le 2048 ] && [ "$num_cores" -eq 1 ]; then
		printf "${yellow}检测到当前2GB内存且CPU核数为1,已调整配置文件${white}\n"
		sed -i -r '
			s/^[[:space:]]*max_connections[[:space:]]*=[[:space:]]*[0-9]+/max_connections = 100/
			s/^[[:space:]]*tmp_table_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/tmp_table_size = 8M/
			s/^[[:space:]]*myisam_sort_buffer_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/myisam_sort_buffer_size = 16M/
			s/^[[:space:]]*innodb_log_buffer_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/innodb_log_buffer_size = 64M/
			s/^[[:space:]]*innodb_buffer_pool_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/innodb_buffer_pool_size = 128M/
			s/^[[:space:]]*innodb_log_file_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/innodb_log_file_size = 128M/
			s/^[[:space:]]*innodb_open_files[[:space:]]*=[[:space:]]*[0-9]+/innodb_open_files = 100/
			s/^[[:space:]]*max_allowed_packet[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/max_allowed_packet = 64M/
			s/^[[:space:]]*max_connect_errors[[:space:]]*=[[:space:]]*[0-9]+/max_connect_errors = 20/
			s/^[[:space:]]*max_binlog_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/max_binlog_size = 64M/
			s/^[[:space:]]*read_rnd_buffer_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/read_rnd_buffer_size = 128K/
			s/^[[:space:]]*read_buffer_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/read_buffer_size = 128K/
			s/^[[:space:]]*sort_buffer_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/sort_buffer_size = 128K/
		' /etc/my.cnf
		printf "${green}MySQL配置文件已更新并根据服务器配置动态调整完成${white}\n"
	# 2核2GB内存
	elif [ "$memory_size" -ge 1800 ] && [ "$memory_size" -le 2048 ] && [ "$num_cores" -eq 2 ]; then
		printf "${yellow}检测到当前2GB内存且CPU核数为2,已调整配置文件${white}\n"
		sed -i -r '
			s/^[[:space:]]*max_connections[[:space:]]*=[[:space:]]*[0-9]+/max_connections = 150/
			s/^[[:space:]]*tmp_table_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/tmp_table_size = 8M/
			s/^[[:space:]]*myisam_sort_buffer_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/myisam_sort_buffer_size = 16M/
			s/^[[:space:]]*innodb_log_buffer_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/innodb_log_buffer_size = 64M/
			s/^[[:space:]]*innodb_buffer_pool_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/innodb_buffer_pool_size = 128M/
			s/^[[:space:]]*innodb_log_file_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/innodb_log_file_size = 128M/
			s/^[[:space:]]*innodb_open_files[[:space:]]*=[[:space:]]*[0-9]+/innodb_open_files = 150/
			s/^[[:space:]]*max_allowed_packet[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/max_allowed_packet = 64M/
			s/^[[:space:]]*max_connect_errors[[:space:]]*=[[:space:]]*[0-9]+/max_connect_errors = 30/
			s/^[[:space:]]*max_binlog_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/max_binlog_size = 128M/
			s/^[[:space:]]*read_rnd_buffer_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/read_rnd_buffer_size = 256K/
			s/^[[:space:]]*read_buffer_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/read_buffer_size = 256K/
			s/^[[:space:]]*sort_buffer_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/sort_buffer_size = 256K/
		' /etc/my.cnf
		printf "${green}MySQL配置文件已更新并根据服务器配置动态调整完成${white}\n"
	# 2核4GB内存
	elif [ "$memory_size" -ge 3600 ] && [ "$memory_size" -le 4096 ] && [ "$num_cores" -eq 2 ]; then
		printf "${yellow}检测到当前4GB内存且CPU核数为2,已调整配置文件${white}\n"
		sed -i -r '
			s/^[[:space:]]*max_connections[[:space:]]*=[[:space:]]*[0-9]+/max_connections = 200/
			s/^[[:space:]]*tmp_table_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/tmp_table_size = 16M/
			s/^[[:space:]]*myisam_sort_buffer_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/myisam_sort_buffer_size = 32M/
			s/^[[:space:]]*innodb_log_buffer_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/innodb_log_buffer_size = 128M/
			s/^[[:space:]]*innodb_buffer_pool_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/innodb_buffer_pool_size = 256M/
			s/^[[:space:]]*innodb_log_file_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/innodb_log_file_size = 256M/
			s/^[[:space:]]*innodb_open_files[[:space:]]*=[[:space:]]*[0-9]+/innodb_open_files = 200/
			s/^[[:space:]]*max_allowed_packet[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/max_allowed_packet = 128M/
			s/^[[:space:]]*max_connect_errors[[:space:]]*=[[:space:]]*[0-9]+/max_connect_errors = 50/
			s/^[[:space:]]*max_binlog_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/max_binlog_size = 256M/
			s/^[[:space:]]*read_rnd_buffer_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/read_rnd_buffer_size = 512K/
			s/^[[:space:]]*read_buffer_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/read_buffer_size = 512K/
			s/^[[:space:]]*sort_buffer_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/sort_buffer_size = 512K/
		' /etc/my.cnf
		printf "${green}MySQL配置文件已更新并根据服务器配置动态调整完成${white}\n"
	# 4核4GB内存
	elif [ "$memory_size" -ge 3600 ] && [ "$memory_size" -le 4096 ] && [ "$num_cores" -eq 4 ]; then
		printf "${yellow}检测到当前4GB内存且CPU核数为4,已调整配置文件${white}\n"
		sed -i -r '
			s/^[[:space:]]*max_connections[[:space:]]*=[[:space:]]*[0-9]+/max_connections = 300/
			s/^[[:space:]]*tmp_table_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/tmp_table_size = 16M/
			s/^[[:space:]]*myisam_sort_buffer_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/myisam_sort_buffer_size = 32M/
			s/^[[:space:]]*innodb_log_buffer_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/innodb_log_buffer_size = 128M/
			s/^[[:space:]]*innodb_buffer_pool_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/innodb_buffer_pool_size = 512M/
			s/^[[:space:]]*innodb_log_file_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/innodb_log_file_size = 512M/
			s/^[[:space:]]*innodb_open_files[[:space:]]*=[[:space:]]*[0-9]+/innodb_open_files = 300/
			s/^[[:space:]]*max_allowed_packet[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/max_allowed_packet = 128M/
			s/^[[:space:]]*max_connect_errors[[:space:]]*=[[:space:]]*[0-9]+/max_connect_errors = 100/
			s/^[[:space:]]*max_binlog_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/max_binlog_size = 512M/
			s/^[[:space:]]*read_rnd_buffer_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/read_rnd_buffer_size = 1M/
			s/^[[:space:]]*read_buffer_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/read_buffer_size = 1M/
			s/^[[:space:]]*sort_buffer_size[[:space:]]*=[[:space:]]*[0-9]+[KMG]?/sort_buffer_size = 1M/
		' /etc/my.cnf
		printf "${green}MySQL配置文件已更新并根据服务器配置动态调整完成${white}\n"
    else
        # 对于其他情况,不做任何修改
        printf "${red}未匹配到合适的内存和CPU配置,未做任何修改${white}\n"
    fi
}

# MySQL函数4
# 安装指定版本的MySQL(该函数为mysql_version_selection_menu函数的调用子函数),包含下载路径的判断,配置文件的调优(支持:8G/4G/2G内存自动判断并优化),数据库初始化
install_mysql_version() {
	# 校验软件包下载路径
	create_software_dir

	# 校验MySQL安装
	if ! check_mysql_installed >/dev/null 2>&1; then
		printf "${yellow}正在${os_release}上安装! ${white}\n"
	else
		printf "${red}MySQL已安装${white}\n"
		return # 返回mysql菜单
	fi

	# 定义下载目录
	local version="$1"
	local arch=$(uname -m) # 获取系统架构
	local mysql_download_dir="$SOFTWARE_DIR/mysql"
	local mysql_url="https://downloads.mysql.com/archives/get/p/23/file/mysql-${version}-1.el7.${arch}.rpm-bundle.tar"

	# 旧的下载目录如果存在则删除,有可能曾经以为不确定因素中断安装导致的文件夹创建
	if [ -d "$mysql_download_dir" ]; then
		rm -fr $mysql_download_dir
		printf "${yellow}历史下载目录已删除:${mysql_download_dir}${white}\n"
	fi

	# 创建下载目录,如果不存在
	if [ ! -d "$mysql_download_dir" ]; then
		mkdir -p "$mysql_download_dir"
		check_command "目录创建失败:${mysql_download_dir}"
		if [ $? -eq 0 ]; then
			printf "${green}软件安装目录创建成功:${mysql_download_dir}${white}\n"
		else
			return 1
		fi
	else
		printf "${yellow}目录已存在:${mysql_download_dir}${white}\n"
	fi

	cd "$mysql_download_dir" || return

	# 检查临时文件夹权限,由于mysql安装中会通过mysql用户在/tmp目录下新建tmp_db文件,所以给/tmp较大权限
	if [ "$(stat -c '%A' /tmp)" != "drwxrwxrwt" ]; then
		chmod -R 777 /tmp >/dev/null 2>&1
		printf "${yellow}已更新/tmp目录权限为777!${white}\n"
	fi

	# 检查并卸载冲突的包
	for package in mariadb-libs mysql-libs; do
		if rpm -q $package >/dev/null 2>&1; then
			printf "${yellow}卸载冲突文件:${package}${white}\n"
			yum remove $package -y >/dev/null 2>&1
		fi
	done

	# 检查并安装依赖
	for package in libaio net-tools wget; do
		if ! rpm -q $package >/dev/null 2>&1; then
			yum install $package -y >/dev/null 2>&1
			printf "${yellow}安装并检查依赖:${package}${white}\n"
		fi
	done

	# 下载MySQL软件包
	wget --progress=bar:force -P "$mysql_download_dir" "$mysql_url"
	check_command "下载MySQL安装包失败"

	tar xvf "$mysql_download_dir/mysql-${version}-1.el7.${arch}.rpm-bundle.tar" -C "$mysql_download_dir"
	check_command "解压MySQL安装包失败"

	# 删除安装包
	rm -f "$mysql_download_dir/mysql-${version}-1.el7.${arch}.rpm-bundle.tar"

	# 定义安装包数组
	local packages=(
		mysql-community-common-${version}-1.el7.${arch}.rpm
		mysql-community-client-plugins-${version}-1.el7.${arch}.rpm
		mysql-community-libs-${version}-1.el7.${arch}.rpm
		mysql-community-icu-data-files-${version}-1.el7.${arch}.rpm
		mysql-community-client-${version}-1.el7.${arch}.rpm
		mysql-community-server-${version}-1.el7.${arch}.rpm
	)

	# 安装MySQL,按顺序执行
	for package in "${packages[@]}"; do
		if [ -f "$package" ]; then
			yum localinstall "$package" -y && printf "${green}MySQL安装包: ${package} 安装成功${white}\n" || printf "${red}MySQL安装包安装失败:${package}${white}\n"
			# 删除已安装的包文件
			rm -f "$package"
		else
			printf "${yellow}未找到安装包: ${package} 也许不需要${white}\n"
		fi
	done

	echo ""
	printf "${green}MySQL所有包安装完毕${white}\n"

	# 验证安装
	check_mysql_installed

	# 备份当前的my.cnf文件
	mv /etc/my.cnf{,.bak}

	# 下载MySQL配置文件
	generate_mysql_config

	# 性能调优
	optimize_mysql_performance

	# 调用函数进行MySQL初始化
	if initialize_mysql; then
		printf "${green}MySQL初始化成功${white}\n"
	else
		printf "${red}MySQL初始化失败${white}\n"
		return 1
	fi

	systemctl enable mysqld --now >/dev/null 2>&1

	# 检查MySQL服务是否处于活动状态
	if ! systemctl is-active mysqld >/dev/null 2>&1; then
		printf "${red}MySQL状态检查失败或服务无法启动,请检查安装日志或手动启动MySQL服务${white}\n"
		return 1
	else
		printf "${green}MySQL已完成自检,启动并设置开机自启${white}\n"
	fi

	echo ""

	# 清理安装包文件和下载路径
	if [ -d "$mysql_download_dir" ] && [ "$(ls -A $mysql_download_dir)" ]; then
		for file in "$mysql_download_dir"/*; do
			rm -f "$file"
		done
		if [ ! "$(ls -A $mysql_download_dir)" ]; then
			rmdir "$mysql_download_dir"
			printf "${green}安装包目录已清空并删除:${mysql_download_dir}${white}\n"
		fi
	else
		printf "${red}文件下载目录为空,无需清理${white}\n"
	fi
}

# MySQL函数5
# 提供MySQL版本选择菜单并调用install_mysql_version函数的MySQL安装总函数
mysql_version_selection_menu() {
	local choice

	while true; do
		clear
		printf "${cyan}=================================${white}\n"
		printf "${cyan}         选择MySQL版本           ${white}\n"
		printf "${cyan}=================================${white}\n"
		printf "${cyan}1. 安装MySQL 8.0.26${white}\n"
		printf "${cyan}2. 安装MySQL 8.0.28${white}\n"
		printf "${cyan}3. 安装MySQL 8.0.30${white}\n"
		printf "${cyan}4. 返回上一级菜单${white}\n"
		printf "${cyan}=================================${white}\n"

		# 读取用户选择
		printf "${cyan}请输入选项并按回车:${white}"
		read -r choice

		case "$choice" in
			1)
				install_mysql_version "8.0.26"
				;;
			2)
				install_mysql_version "8.0.28"
				;;
			3)
				install_mysql_version "8.0.30"
				;;
			4)
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

# MySQL函数6
# 卸载MySQL服务,一把梭
mysql_uninstall() {
    # 检查MySQL是否安装
    if ! check_mysql_installed >/dev/null 2>&1; then
        printf "${red}MySQL未安装, 无需卸载${white}\n"
        return # 返回mysql菜单
    fi

    printf "${yellow}停止并禁用MySQL服务${white}\n"
    if systemctl is-active mysqld >/dev/null 2>&1; then
        systemctl disable mysqld --now >/dev/null 2>&1
        check_command "无法停止并禁用MySQL服务"
        printf "${green}MySQL服务已停止并禁用${white}\n"
    else
        printf "${green}MySQL服务已停止${white}\n"
    fi

    printf "${yellow}卸载MySQL软件包${white}\n"
    for package in $(rpm -qa | grep -iE '^mysql-community-'); do
        yum remove "$package" -y
        check_command "卸载失败:$package"
        printf "${green}成功卸载:$package${white}\n"
    done

    printf "${yellow}删除与MySQL相关的文件${white}\n"

    # 定义排除目录的数组
    local EXCLUDE_DIRS=(
        "/etc/selinux/"
        "/usr/lib/firewalld/services/"
        "/usr/lib64/"
        "/usr/share/vim/"
    )

    # 定义删除文件和目录的函数
    delete_with_exclusions() {
        local exclude_dirs_pattern
        local items_to_delete
        local item

        # 将排除目录数组转换为正则表达式模式
        exclude_dirs_pattern=$(printf "%s|" "${EXCLUDE_DIRS[@]}" | sed 's/|$//')
        exclude_dirs_pattern="^($exclude_dirs_pattern).*"

        # 查找文件和目录,排除指定目录及其子目录
        items_to_delete=$(find / -name "*mysql*" -print 2>/dev/null | grep -Pv "$exclude_dirs_pattern")

        for item in $items_to_delete; do
            # 跳过排除目录中的项
            local exclude=0
            for exclude_dir in "${EXCLUDE_DIRS[@]}"; do
                if [[ $item == $exclude_dir* ]]; then
                    printf "${yellow}跳过排除目录中的项:$item${white}\n"
                    exclude=1
                    break
                fi
            done

            # 如果未被排除，则删除文件或目录
            if [ $exclude -eq 0 ]; then
                if [ -d "$item" ]; then
                    printf "${yellow}删除目录:$item${white}\n"
                    rm -fr "$item"
                    check_command "删除目录$item失败"
                elif [ -f "$item" ]; then
                    printf "${yellow}删除文件:$item${white}\n"
                    rm -f "$item"
                    check_command "删除文件$item失败"
                fi
            fi
        done
    }

    # 删除特定的 MySQL 配置文件
    delete_specific_files() {
        local files
        files=$(ls /etc/my.cnf.* 2>/dev/null)

        for file in $files; do
            if [ -e "$file" ]; then
                printf "${yellow}删除文件:$file${white}\n"
                rm -f "$file"
                check_command "删除文件$file失败"
            fi
        done
    }

    # 调用局部函数进行删除操作
    delete_with_exclusions
    delete_specific_files

    check_command "MySQL卸载失败" || printf "${green}MySQL卸载完成${white}\n"
}

# MySQL函数7
# 控制MySQL服务的状态
control_mysql() {
	local action="${1:-status}"

	case "$action" in
		status)
			if ! check_mysql_installed; then
				return # 返回mysql菜单
			fi

			# 查找MySQL进程
			if ps -ef | grep '[m]ysqld' >/dev/null 2>&1; then
				printf "${yellow}MySQL进程信息:\n$(ps -ef | grep '[m]ysqld')${white}\n"
				systemctl status mysqld
			else
				printf "${red}未找到MySQL进程信息${white}\n"
				# 检查服务状态
				if systemctl is-active mysqld >/dev/null 2>&1; then
					printf "${yellow}MySQL服务正在运行,但未找到进程信息${white}\n"
				else
					printf "${yellow}MySQL服务未启动${white}\n"
				fi
			fi
			;;
		start)
			if ! check_mysql_installed; then
				return # 返回mysql菜单
			fi

			# 检查MySQL是否已经在运行
			if systemctl is-active mysqld >/dev/null 2>&1; then
				printf "${red}MySQL已运行,请不要重复启动!${white}\n"
			else
				systemctl enable mysqld --now >/dev/null 2>&1
				if systemctl is-active mysqld >/dev/null 2>&1; then
					printf "${green}MySQL启动成功!${white}\n"
				else
					printf "${red}MySQL启动失败${white}\n"
				fi
			fi
			;;
		stop)
			if ! check_mysql_installed; then
				return # 返回mysql菜单
			fi

			if ! systemctl is-active mysqld >/dev/null 2>&1; then
				printf "${yellow}MySQL已经停止,无需停止${white}\n"
			else
				systemctl disable mysqld --now >/dev/null 2>&1
				if ! systemctl is-active mysqld >/dev/null 2>&1; then
					printf "${green}MySQL停止成功!${white}\n"
				else
					printf "${red}MySQL停止失败!${white}\n"
				fi
			fi
			;;
		*)
			printf "${red}无效的操作参数: ${action}${white}\n"
			return 1
			;;
	esac
	return 0
}

# mysql菜单
mysql_menu() {
	local choice
	while true; do
		clear
		printf "${cyan}=================================${white}\n"
		printf "${cyan}          MySQL 管理菜单         ${white}\n"
		printf "${cyan}=================================${white}\n"
		printf "${cyan}1. 查看MySQL服务${white}\n"
		printf "${cyan}2. 启动MySQL服务${white}\n"
		printf "${cyan}3. 停止MySQL服务${white}\n"
		printf "${cyan}4. 安装MySQL服务${white}\n"
		printf "${cyan}5. 卸载MySQL服务${white}\n"
		printf "${cyan}6. 返回主菜单.${white}\n"
		printf "${cyan}=================================${white}\n"

		printf "${cyan}请输入选项并按回车:${white}"
		read -r choice

		case "$choice" in
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
				mysql_version_selection_menu
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
		printf "${cyan}按任意键继续${white}\n"
		read -n 1 -s -r
	done
}

# 主菜单
main() {
	while true; do
		clear
		printf "${cyan}=================================${white}\n"
		printf "${cyan}              主菜单             ${white}\n"
		printf "${cyan}=================================${white}\n"
		printf "${cyan}1. 工具管理菜单${white}\n"
		printf "${cyan}2. MySQL管理菜单${white}\n"
		printf "${cyan}3. 退出${white}\n"
		printf "${cyan}=================================${white}\n"

		printf "${cyan}请输入选项并按回车:${white}"
		read -r choice

		case "$choice" in
			1)
				echo "return"
				#tools_menu
				;;
			2)
				mysql_menu
				;;
			3)
				printf "${yellow}Bey!${white}\n"
				exit 0  # 退出脚本
				;;
			*)
				printf "${red}无效选项, 请重新输入${white}\n"
				;;
		esac
	done
}

####################
# 检查脚本是否以root用户身份运行
if [[ $EUID -ne 0 ]]; then
	printf "${red}此脚本必须以root用户身份运行.${white}\n"
	exit 1
fi

# 检查操作系统是否受支持(CentOS)
case "$os_release" in
	*CentOS*|*centos*)
		# 不输出任何消息,直接继续执行
		;;
	*)
		printf "${red}此脚本不支持的Linux发行版:$os_release ${white}\n"
		exit 1
		;;
esac

main
exit 0