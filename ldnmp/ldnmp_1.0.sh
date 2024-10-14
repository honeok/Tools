#!/bin/bash
# Author: honeok
# Blog: https://www.honeok.com

#set -o errexit

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

# 卸载软件包
remove(){
	if [ $# -eq 0 ]; then
		_red "未提供软件包参数"
		return 1
	fi

	for package in "$@"; do
		_yellow "正在卸载$package"
		if command -v dnf &>/dev/null; then
			dnf remove -y "${package}"*
		elif command -v yum &>/dev/null; then
			yum remove -y "${package}"*
		elif command -v apt &>/dev/null; then
			apt purge -y "${package}"*
		elif command -v apk &>/dev/null; then
			apk del "${package}"*
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

check_crontab_installed() {
	if command -v crontab >/dev/null 2>&1; then
		_green "crontab已安装"
		return $?
	else
		install_crontab
		return 0
	fi
}

install_crontab() {
	if [ -f /etc/os-release ]; then
		. /etc/os-release
			case "$ID" in
				ubuntu|debian)
					install cron
					enable cron
					start cron
					;;
				centos)
					install cronie
					enable crond
					start crond
					;;
				alpine)
					apk add --no-cache cronie
					rc-update add crond
					rc-service crond start
					;;
				*)
					_red "不支持的发行版:$ID"
					return 1
					;;
			esac
	else
		_red "无法确定操作系统"
		return 1
	fi

	_yellow "Crontab已安装且Cron服务正在运行"
}

###############################################################

manage_compose() {
	case "$1" in
		start)	# 启动容器
			if docker compose version >/dev/null 2>&1; then
				docker compose up -d
			elif command -v docker-compose >/dev/null 2>&1; then
				docker-compose up -d
			fi
			;;
		stop)	# 停止容器
			if docker compose version >/dev/null 2>&1; then
				docker compose stop
			elif command -v docker-compose >/dev/null 2>&1; then
				docker-compose stop
			fi
			;;
		down)	# 停止并删除容器
			if docker compose version >/dev/null 2>&1; then
				docker compose down
			elif command -v docker-compose >/dev/null 2>&1; then
				docker-compose down
			fi
			;;
		down_all)
			if docker compose version >/dev/null 2>&1; then
				docker compose down --rmi all
			elif command -v docker-compose >/dev/null 2>&1; then
				docker-compose down --rmi all
			fi
			;;
		clean_down)	# 停止容器并删除镜像和卷
			if docker compose version >/dev/null 2>&1; then
				docker compose down --rmi all --volumes
			elif command -v docker-compose >/dev/null 2>&1; then
				docker-compose down --rmi all --volumes
			fi
			;;
	esac
}

ldnmp_check_status() {
	if docker inspect "ldnmp" &>/dev/null; then
		_yellow "LDNMP环境已安装,可以选择更新LDNMP环境"
		end_of
		linux_ldnmp
	fi
}

ldnmp_install_status() {
	if docker inspect "ldnmp" &>/dev/null; then
		_yellow "LDNMP环境已安装,开始部署$webname"
	else
		_red "LDNMP环境未安装,请先安装LDNMP环境再部署网站"
		end_of
		linux_ldnmp
	fi
}

ldnmp_restore_check(){
	if docker inspect "ldnmp" &>/dev/null; then
		_yellow "LDNMP环境已安装,无法还原LDNMP环境,请先卸载现有环境再次尝试还原"
		end_of
		linux_ldnmp
	fi
}

nginx_install_status() {
	if docker inspect "nginx" &>/dev/null; then
		_yellow "Nginx环境已安装,开始部署$webname"
	else
		_red "Nginx环境未安装,请先安装Nginx环境再部署网站"
		end_of
		linux_ldnmp
	fi
}

ldnmp_check_port() {
	# 定义要检测的端口
	ports=("80" "443")

	# 检查端口占用情况
	for port in "${ports[@]}"; do
		result=$(netstat -tulpn | grep ":$port ")

		if [ -n "$result" ]; then
			clear
			_red "端口$port已被占用,无法安装环境,卸载以下程序后重试"
			_yellow "$result"
			end_of
			linux_ldnmp
			return 1
		fi
	done
}

ldnmp_install_deps() {
	clear
	# 安装依赖包
	install wget socat unzip tar
}

ldnmp_uninstall_deps(){
	clear
	remove socat
}

ldnmp_install_certbot() {
	local cron_job existing_cron

	# 检查并安装certbot
	if ! command -v certbot &> /dev/null; then
		install certbot || { _red "安装certbot失败"; return 1; }
	fi

	[ ! -d /data/script ] && mkdir -p /data/script
	cd /data/script || { _red "进入目录/data/script失败"; return 1; }

	# 设置定时任务字符串
	check_crontab_installed
	cron_job="0 0 * * * /data/script/auto_cert_renewal.sh >/dev/null 2>&1"

	# 检查是否存在相同的定时任务
	existing_cron=$(crontab -l 2>/dev/null | grep -F "$cron_job")

	if [ -z "$existing_cron" ]; then
		# 下载并使脚本可执行
		curl -sS -o ./auto_cert_renewal.sh https://raw.githubusercontent.com/honeok8s/shell/main/callscript/autocert_certbot.sh
		chmod a+x auto_cert_renewal.sh

		# 添加定时任务
		(crontab -l 2>/dev/null; echo "$cron_job") | crontab -
		_green "续签任务已安装"
	else
		_yellow "续签任务已存在,无需重复安装"
	fi
}

ldnmp_uninstall_certbot() {
	local cron_job existing_cron

	# 检查并卸载certbot
	if command -v certbot &> /dev/null; then
		remove certbot || { _red "卸载certbot失败"; return 1; }
	fi

	cron_job="0 0 * * * /data/script/auto_cert_renewal.sh >/dev/null 2>&1"
	# 检查并删除定时任务
	existing_cron=$(crontab -l 2>/dev/null | grep -F "$cron_job")
	if [ -n "$existing_cron" ]; then
		(crontab -l 2>/dev/null | grep -Fv "$cron_job") | crontab -
		_green "续签任务已从定时任务中移除"
	else
		_yellow "定时任务未找到,无需移除"
	fi

	# 删除脚本文件
	if [ -f /data/script/auto_cert_renewal.sh ]; then
		rm /data/script/auto_cert_renewal.sh
		_green "续签脚本文件已删除"
	fi
}

default_server_ssl() {
	install openssl

	if command -v dnf &>/dev/null || command -v yum &>/dev/null; then
		openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -keyout /data/docker_data/web/nginx/certs/default_server.key -out /data/docker_data/web/nginx/certs/default_server.crt -days 5475 -subj "/C=US/ST=State/L=City/O=Organization/OU=Organizational Unit/CN=Common Name"
	else
		openssl genpkey -algorithm Ed25519 -out /data/docker_data/web/nginx/certs/default_server.key
		openssl req -x509 -key /data/docker_data/web/nginx/certs/default_server.key -out /data/docker_data/web/nginx/certs/default_server.crt -days 5475 -subj "/C=US/ST=State/L=City/O=Organization/OU=Organizational Unit/CN=Common Name"
	fi
}

install_ldnmp() {
	#check_swap
	cd "$web_dir" || { _red "无法进入目录$web_dir"; return 1; }

	manage_compose start

	clear
	_yellow "正在配置LDNMP环境,请耐心等待"

	# 定义要执行的命令
	commands=(
		"docker exec nginx chmod -R 777 /var/www/html"
		"docker restart nginx > /dev/null 2>&1"

		"docker exec php apk update > /dev/null 2>&1"
		"docker exec php74 apk update > /dev/null 2>&1"

		# php安装包管理
		"curl -sL https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions -o /usr/local/bin/install-php-extensions > /dev/null 2>&1"
		"docker exec php mkdir -p /usr/local/bin/ > /dev/null 2>&1"
		"docker exec php74 mkdir -p /usr/local/bin/ > /dev/null 2>&1"
		"docker cp /usr/local/bin/install-php-extensions php:/usr/local/bin/ > /dev/null 2>&1"
		"docker cp /usr/local/bin/install-php-extensions php74:/usr/local/bin/ > /dev/null 2>&1"
		"docker exec php chmod +x /usr/local/bin/install-php-extensions > /dev/null 2>&1"
		"docker exec php74 chmod +x /usr/local/bin/install-php-extensions > /dev/null 2>&1"

		# php安装扩展
		"docker exec php sh -c '\
			apk add --no-cache imagemagick imagemagick-dev \
			&& apk add --no-cache git autoconf gcc g++ make pkgconfig \
			&& rm -rf /tmp/imagick \
			&& git clone https://github.com/Imagick/imagick /tmp/imagick \
			&& cd /tmp/imagick \
			&& phpize \
			&& ./configure \
			&& make \
			&& make install \
			&& echo 'extension=imagick.so' > /usr/local/etc/php/conf.d/imagick.ini \
			&& rm -rf /tmp/imagick' > /dev/null 2>&1"

		"docker exec php install-php-extensions imagick > /dev/null 2>&1"
		"docker exec php install-php-extensions mysqli > /dev/null 2>&1"
		"docker exec php install-php-extensions pdo_mysql > /dev/null 2>&1"
		"docker exec php install-php-extensions gd > /dev/null 2>&1"
		"docker exec php install-php-extensions intl > /dev/null 2>&1"
		"docker exec php install-php-extensions zip > /dev/null 2>&1"
		"docker exec php install-php-extensions exif > /dev/null 2>&1"
		"docker exec php install-php-extensions bcmath > /dev/null 2>&1"
		"docker exec php install-php-extensions opcache > /dev/null 2>&1"
		"docker exec php install-php-extensions redis > /dev/null 2>&1"

		# php配置参数
		"docker exec php sh -c 'echo \"upload_max_filesize=50M \" > /usr/local/etc/php/conf.d/uploads.ini' > /dev/null 2>&1"
		"docker exec php sh -c 'echo \"post_max_size=50M \" > /usr/local/etc/php/conf.d/post.ini' > /dev/null 2>&1"
		"docker exec php sh -c 'echo \"memory_limit=256M\" > /usr/local/etc/php/conf.d/memory.ini' > /dev/null 2>&1"
		"docker exec php sh -c 'echo \"max_execution_time=1200\" > /usr/local/etc/php/conf.d/max_execution_time.ini' > /dev/null 2>&1"
		"docker exec php sh -c 'echo \"max_input_time=600\" > /usr/local/etc/php/conf.d/max_input_time.ini' > /dev/null 2>&1"

		# php重启
		"docker exec php chmod -R 777 /var/www/html"
		"docker restart php > /dev/null 2>&1"

		# php7.4安装扩展
		"docker exec php74 install-php-extensions imagick > /dev/null 2>&1"
		"docker exec php74 install-php-extensions mysqli > /dev/null 2>&1"
		"docker exec php74 install-php-extensions pdo_mysql > /dev/null 2>&1"
		"docker exec php74 install-php-extensions gd > /dev/null 2>&1"
		"docker exec php74 install-php-extensions intl > /dev/null 2>&1"
		"docker exec php74 install-php-extensions zip > /dev/null 2>&1"
		"docker exec php74 install-php-extensions exif > /dev/null 2>&1"
		"docker exec php74 install-php-extensions bcmath > /dev/null 2>&1"
		"docker exec php74 install-php-extensions opcache > /dev/null 2>&1"
		"docker exec php74 install-php-extensions redis > /dev/null 2>&1"

		# php7.4配置参数
		"docker exec php74 sh -c 'echo \"upload_max_filesize=50M \" > /usr/local/etc/php/conf.d/uploads.ini' > /dev/null 2>&1"
		"docker exec php74 sh -c 'echo \"post_max_size=50M \" > /usr/local/etc/php/conf.d/post.ini' > /dev/null 2>&1"
		"docker exec php74 sh -c 'echo \"memory_limit=256M\" > /usr/local/etc/php/conf.d/memory.ini' > /dev/null 2>&1"
		"docker exec php74 sh -c 'echo \"max_execution_time=1200\" > /usr/local/etc/php/conf.d/max_execution_time.ini' > /dev/null 2>&1"
		"docker exec php74 sh -c 'echo \"max_input_time=600\" > /usr/local/etc/php/conf.d/max_input_time.ini' > /dev/null 2>&1"

		# php7.4重启
		"docker exec php74 chmod -R 777 /var/www/html"
		"docker restart php74 > /dev/null 2>&1"

		# redis调优
		"docker exec -it redis redis-cli CONFIG SET maxmemory 512mb > /dev/null 2>&1"
		"docker exec -it redis redis-cli CONFIG SET maxmemory-policy allkeys-lru > /dev/null 2>&1"

		# 最后一次php重启
		"docker restart php > /dev/null 2>&1"
		"docker restart php74 > /dev/null 2>&1"
      )

	total_commands=${#commands[@]}  # 计算总命令数

	for ((i = 0; i < total_commands; i++)); do
		command="${commands[i]}"
		eval $command  # 执行命令

		# 打印百分比和进度条
		percentage=$(( (i + 1) * 100 / total_commands ))
		completed=$(( percentage / 2 ))
		remaining=$(( 50 - completed ))
		progressBar="["
			for ((j = 0; j < completed; j++)); do
				progressBar+="#"
			done
			for ((j = 0; j < remaining; j++)); do
				progressBar+="."
			done
			progressBar+="]"
			echo -ne "\r[${yellow}$percentage%${white}] $progressBar"
	done

	echo # 打印换行,以便输出不被覆盖

	clear
	_green "LDNMP环境安装完毕"
	echo "------------------------"
	ldnmp_version
}

ldnmp_install_nginx(){
	local nginx_dir nginx_conf_dir default_conf

	nginx_dir="/data/docker_data/web/nginx"
	nginx_conf_dir="/data/docker_data/web/nginx/conf.d"
	default_conf="$nginx_conf_dir/default.conf"

	need_root

	# 如果已安装LDNMP环境直接返回
	if docker inspect "ldnmp" &>/dev/null; then
		_yellow "LDNMP环境已集成Nginx,无须重复安装"
		return 0
	fi

	if docker inspect "nginx" &>/dev/null; then
		if curl -s https://raw.githubusercontent.com/honeok8s/conf/main/nginx/ldnmp-nginx-docker-compose.yml | head -n 20 | diff - "/data/docker_data/web/docker-compose.yml" &>/dev/null; then
			_yellow "检测到通过本脚本已安装Nginx"
			return 0
		else
			docker rm -f nginx >/dev/null 2>&1
		fi
	else
		ldnmp_check_port
		ldnmp_install_deps
		#install_docker
		ldnmp_install_certbot

		mkdir -p "$nginx_dir" "$nginx_conf_dir" "$nginx_dir/certs"
		wget -qO "$nginx_dir/nginx.conf" "https://raw.githubusercontent.com/honeok8s/conf/main/nginx/nginx-2C2G.conf"
		wget -qO "$nginx_conf_dir/default.conf" "https://raw.githubusercontent.com/honeok8s/conf/main/nginx/conf.d/default2.conf"

		default_server_ssl

		wget -qO "/data/docker_data/web/docker-compose.yml" "https://raw.githubusercontent.com/honeok8s/conf/main/nginx/ldnmp-nginx-docker-compose.yml"

		cd /data/docker_data/web || { _red "无法进入目录/data/docker_data/web"; return 1; }
		manage_compose start

		docker exec -it nginx chmod -R 777 /var/www/html

		clear
		nginx_version=$(docker exec nginx nginx -v 2>&1)
		nginx_version=$(echo "$nginx_version" | grep -oP "nginx/\K[0-9]+\.[0-9]+\.[0-9]+")
		_green "Nginx安装完成"
		echo -e "当前版本:${yellow}v$nginx_version${white}"
		echo ""
	fi
}

ldnmp_version() {
	# 获取Nginx版本
	if docker ps --format '{{.Names}}' | grep -q '^nginx$'; then
		nginx_version=$(docker exec nginx nginx -v 2>&1)
		nginx_version=$(echo "$nginx_version" | grep -oP "nginx/\K[0-9]+\.[0-9]+\.[0-9]+")
		echo -n -e "Nginx: ${yellow}v$nginx_version${white}"
	else
		echo -n -e "Nginx: ${red}NONE${white}"
	fi

	# 获取MySQL版本
	if docker ps --format '{{.Names}}' | grep -q '^mysql$'; then
		DB_ROOT_PASSWD=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /data/docker_data/web/docker-compose.yml | tr -d '[:space:]')
		mysql_version=$(docker exec mysql mysql --silent --skip-column-names -u root -p"$DB_ROOT_PASSWD" -e "SELECT VERSION();" 2>/dev/null | tail -n 1)
		echo -n -e "     MySQL: ${yellow}v$mysql_version${white}"
	else
		echo -n -e "     MySQL: ${red}NONE${white}"
	fi

	# 获取PHP版本
	if docker ps --format '{{.Names}}' | grep -q '^php$'; then
		php_version=$(docker exec php php -v 2>/dev/null | grep -oP "PHP \K[0-9]+\.[0-9]+\.[0-9]+")
		echo -n -e "     PHP: ${yellow}v$php_version${white}"
	else
		echo -n -e "     PHP: ${red}NONE${white}"
	fi

	# 获取Redis版本
	if docker ps --format '{{.Names}}' | grep -q '^redis$'; then
		redis_version=$(docker exec redis redis-server -v 2>&1 | grep -oP "v=+\K[0-9]+\.[0-9]+")
		echo -e "     Redis: ${yellow}v$redis_version${white}"
	else
		echo -e "     Redis: ${red}NONE${white}"
	fi

	echo "------------------------"
	echo ""
}

add_domain() {
	ip_address

	echo -e "先将域名解析到本机IP: ${yellow}$ipv4_address  $ipv6_address${white}"
	echo -n "请输入你解析的域名(输入0取消操作):"
	read -r domain

	if [[ "$domain" == "0" ]]; then
		linux_ldnmp
	fi

	# 域名格式校验
	domain_regex="^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$"
	if [[ $domain =~ $domain_regex ]]; then
		# 检查域名是否已存在
		if [ -e $nginx_dir/conf.d/$domain.conf ]; then
			_red "当前域名${domain}已被使用,请前往31站点管理,删除站点后再部署${webname}"
			end_of
			linux_ldnmp
		else
			_green "域名${domain}格式校验正确"
		fi
	else
		_red "域名格式不正确,请重新输入"
		end_of
		linux_ldnmp
	fi
}

ip_address() {
ipv4_address=$(curl -s ipv4.ip.sb)
ipv6_address=$(curl -s --max-time 1 ipv6.ip.sb)
}

iptables_open(){
	iptables -P INPUT ACCEPT
	iptables -P FORWARD ACCEPT
	iptables -P OUTPUT ACCEPT
	iptables -F

	ip6tables -P INPUT ACCEPT
	ip6tables -P FORWARD ACCEPT
	ip6tables -P OUTPUT ACCEPT
	ip6tables -F
}

ldnmp_install_ssltls() {
	if docker ps --format '{{.Names}}' | grep -q '^nginx$'; then
		docker stop nginx > /dev/null 2>&1
	else
		_red "未发现Nginx容器或未运行"
		return 1
	fi
	iptables_open > /dev/null 2>&1

	yes | certbot delete --cert-name $domain > /dev/null 2>&1

	certbot_version=$(certbot --version 2>&1 | grep -oP "\d+\.\d+\.\d+")

	version_ge() {
		[ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" != "$1" ]
	}

	if version_ge "$certbot_version" "1.17.0"; then
		certbot certonly --standalone -d $domain --email your@email.com --agree-tos --no-eff-email --force-renewal --key-type ecdsa
	else
		certbot certonly --standalone -d $domain --email your@email.com --agree-tos --no-eff-email --force-renewal
	fi

	cp /etc/letsencrypt/live/$domain/fullchain.pem /data/docker_data/web/nginx/certs/${domain}_cert.pem > /dev/null 2>&1
	cp /etc/letsencrypt/live/$domain/privkey.pem /data/docker_data/web/nginx/certs/${domain}_key.pem > /dev/null 2>&1

	docker start nginx > /dev/null 2>&1
}

ldnmp_certs_status() {
	sleep 1
	file_path="/etc/letsencrypt/live/$domain/fullchain.pem"

	if [ ! -f "$file_path" ]; then
		_red "域名证书申请失败,请检测域名是否正确解析或更换域名重新尝试!"
		end_of
		linux_ldnmp
	fi
}

ldnmp_add_db() {
	DB_NAME=$(echo "$domain" | sed -e 's/[^A-Za-z0-9]/_/g')

	DB_ROOT_PASSWD=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /data/docker_data/web/docker-compose.yml | tr -d '[:space:]')
	DB_USER=$(grep -oP 'MYSQL_USER:\s*\K.*' /data/docker_data/web/docker-compose.yml | tr -d '[:space:]')
	DB_USER_PASSWD=$(grep -oP 'MYSQL_PASSWORD:\s*\K.*' /data/docker_data/web/docker-compose.yml | tr -d '[:space:]')

	if [[ -z "$DB_ROOT_PASSWD" || -z "$DB_USER" || -z "$DB_USER_PASSWD" ]]; then
		_red "无法获取MySQL凭据"
		return 1
	fi

	docker exec mysql mysql -u root -p"$DB_ROOT_PASSWD" -e "CREATE DATABASE IF NOT EXISTS $DB_NAME; GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';" > /dev/null 2>&1 || {
		_red "创建数据库或授予权限失败"
		return 1
	}
}

reverse_proxy() {
      ip_address
      wget -O /home/web/conf.d/$yuming.conf https://raw.githubusercontent.com/kejilion/nginx/main/reverse-proxy.conf
      sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf
      sed -i "s/0.0.0.0/$ipv4_address/g" /home/web/conf.d/$yuming.conf
      sed -i "s/0000/$duankou/g" /home/web/conf.d/$yuming.conf
      docker restart nginx
}

nginx_check() {
	docker exec nginx nginx -t > /dev/null 2>&1
	return $?
}

ldnmp_restart() {
	docker exec nginx chmod -R 777 /var/www/html
	docker exec php chmod -R 777 /var/www/html
	docker exec php74 chmod -R 777 /var/www/html

	if nginx_check; then
		docker restart nginx >/dev/null 2>&1
	else
		_red "Nginx配置校验失败,请检查配置文件"
		return 1
	fi
	docker restart php >/dev/null 2>&1
	docker restart php74 >/dev/null 2>&1
}

ldnmp_display_success() {
	clear
	echo "您的$webname搭建好了!"
	echo "https://$domain"
	echo "------------------------"
	echo "$webname安装信息如下"
}

nginx_display_success() {
	clear
	echo "您的$webname搭建好了"
	echo "https://$domain"
}

fail2ban_status() {
	docker restart fail2ban >/dev/null 2>&1
	sleep 5

	# 尝试检测fail2ban容器状态最多三次
	local retries=3
	local count=0

	while [ $count -lt $retries ]; do
		if docker ps | grep -q fail2ban; then
			# 显示fail2ban状态
			docker exec fail2ban fail2ban-client status
			return 0
		else
			# 容器未运行,等待一段时间后重试
			_yellow "Fail2ban容器未运行,正在重试($((count+1))/$retries)"
			sleep 5
			count=$((count + 1))
		fi
	done

	# 如果三次检测后仍未找到容器运行,输出提示信息
	_red "Fail2ban容器在重试后仍未运行"
}

fail2ban_status_jail() {
	docker exec fail2ban fail2ban-client status $jail_name
}

fail2ban_sshd() {
	if grep -q 'Alpine' /etc/issue; then
		jail_name=alpine-sshd
		fail2ban_status_jail
	else
		jail_name=linux-sshd
		fail2ban_status_jail
	fi
}

fail2ban_install_sshd() {
	[ ! -d /data/docker_data/fail2ban ] && mkdir -p /data/docker_data/fail2ban
	cd /data/docker_data/fail2ban
	wget -qO docker-compose.yml https://raw.githubusercontent.com/honeok8s/conf/main/fail2ban/fail2ban-docker-compose.yml

	manage_compose start

	sleep 3
	if grep -q 'Alpine' /etc/issue; then
		cd /data/docker_data/fail2ban/config/fail2ban/filter.d
		curl -sS -O https://raw.githubusercontent.com/kejilion/config/main/fail2ban/alpine-sshd.conf
		curl -sS -O https://raw.githubusercontent.com/kejilion/config/main/fail2ban/alpine-sshd-ddos.conf
		cd /data/docker_data/fail2ban/config/fail2ban/jail.d/
		curl -sS -O https://raw.githubusercontent.com/kejilion/config/main/fail2ban/alpine-ssh.conf
	elif command -v dnf &>/dev/null; then
		cd /data/docker_data/fail2ban/config/fail2ban/jail.d/
		curl -sS -O https://raw.githubusercontent.com/kejilion/config/main/fail2ban/centos-ssh.conf
	else
		install rsyslog
		systemctl start rsyslog
		systemctl enable rsyslog
		cd /data/docker_data/fail2ban/config/fail2ban/jail.d/
		curl -sS -O https://raw.githubusercontent.com/honeok8s/conf/main/fail2ban/linux-ssh.conf
	fi
}

############################################################################################################
linux_ldnmp() {
	# 定义全局安装路径
	web_dir="/data/docker_data/web"
	nginx_dir="$web_dir/nginx"

	while true; do
		clear
		echo "▶ LDNMP建站"
		echo "------------------------"
		echo "1. 安装LDNMP环境"
		echo "2. 安装WordPress"
		echo "3. 安装Discuz论坛"
		echo "4. 安装可道云桌面"
		echo "5. 安装苹果CMS网站"
		echo "6. 安装独角数发卡网"
		echo "7. 安装flarum论坛网站"
		echo "8. 安装typecho轻量博客网站"
		echo "20. 自定义动态站点"
		echo "------------------------"
		echo "21. 仅安装nginx"
		echo "22. 站点重定向"
		echo "23. 站点反向代理-IP+端口"
		echo "24. 站点反向代理-域名"
		echo "25. 自定义静态站点"
		echo "26. 安装Bitwarden密码管理平台"
		echo "27. 安装Halo博客网站"
		echo "------------------------"
		echo "31. 站点数据管理"
		echo "32. 备份全站数据"
		echo "33. 定时远程备份"
		echo "34. 还原全站数据"
		echo "------------------------"
		echo "35. 站点防御程序"
		echo "------------------------"
		echo "36. 优化LDNMP环境"
		echo "37. 更新LDNMP环境"
		echo "38. 卸载LDNMP环境"
		echo "------------------------"
		echo "0. 返回主菜单"
		echo "------------------------"
		read -p "请输入你的选择: " choice

		case $choice in
			1)
				need_root
				ldnmp_check_status

				if [ -d "$nginx_dir" ];then
					cd "$web_dir"
					manage_compose down && rm docker-compose.yml
				fi

				ldnmp_check_port
				ldnmp_install_deps
				#install_docker
				ldnmp_install_certbot

				# 清理并创建必要的目录
				[ -d "$web_dir" ] && rm -fr "$web_dir"
				mkdir -p "$nginx_dir/certs" "$nginx_dir/conf.d" "$web_dir/redis" "$web_dir/mysql"

				cd "$web_dir" || { _red "无法进入目录 $web_dir"; return 1; }

				# 下载配置文件
				wget -qO "$nginx_dir/nginx.conf" "https://raw.githubusercontent.com/honeok8s/conf/main/nginx/nginx-2C2G.conf"
				wget -qO "$nginx_dir/conf.d/default.conf" "https://raw.githubusercontent.com/honeok8s/conf/main/nginx/conf.d/default2.conf"
				wget -qO "$web_dir/docker-compose.yml" "https://raw.githubusercontent.com/honeok8s/conf/main/ldnmp/LDNMP-docker-compose.yml"

				default_server_ssl

				# 随机生成数据库密码并替换

				DB_ROOT_PASSWD=$(openssl rand -base64 16)
				DB_USER=$(openssl rand -hex 4)
				DB_USER_PASSWD=$(openssl rand -base64 8)

				sed -i "s#HONEOK_ROOTPASSWD#$DB_ROOT_PASSWD#g" "$web_dir/docker-compose.yml"
				sed -i "s#HONEOK_USER#$DB_USER#g" "$web_dir/docker-compose.yml"
				sed -i "s#HONEOK_PASSWD#$DB_USER_PASSWD#g" "$web_dir/docker-compose.yml"

				install_ldnmp
				;;
			2)
				clear
				webname="WordPress"

				ldnmp_install_status
				add_domain
				ldnmp_install_ssltls
				ldnmp_certs_status
				ldnmp_add_db

				wget -qO "$nginx_dir/conf.d/$domain.conf" "https://raw.githubusercontent.com/kejilion/nginx/main/wordpress.com.conf"
				sed -i -e "s/yuming.com/$domain/g" -e "s/my_cache/fst_cache/g" "$nginx_dir/conf.d/$domain.conf"

				wordpress_dir="$nginx_dir/html/$domain"
				[ ! -d $wordpress_dir ] && mkdir -p "$wordpress_dir"
				cd "$wordpress_dir" || { _red "无法进入目录$wordpress_dir"; return 1; }
				wget -qO latest.zip "https://cn.wordpress.org/latest-zh_CN.zip" && unzip latest.zip && rm latest.zip

				# 配置WordPress
				wp_config="$wordpress_dir/wordpress/wp-config-sample.php"
				echo "define('FS_METHOD', 'direct');" >> "$wp_config"
				echo "define('WP_REDIS_HOST', 'redis');" >> "$wp_config"
				echo "define('WP_REDIS_PORT', '6379');" >> "$wp_config"

				ldnmp_restart
				ldnmp_display_success

				echo "数据库名: $DB_NAME"
				echo "用户名: $DB_USER"
				echo "密码: $DB_USER_PASSWD"
				echo "数据库地址: mysql"
				echo "表前缀: wp_"
				;;
			3)
				clear
				webname="Discuz论坛"

				ldnmp_install_status
				add_domain
				ldnmp_install_ssltls
				ldnmp_certs_status
				ldnmp_add_db

				wget -qO "$nginx_dir/conf.d/$domain.conf" "https://raw.githubusercontent.com/kejilion/nginx/main/discuz.com.conf"
				sed -i -e "s/yuming.com/$domain/g" -e "s/my_cache/fst_cache/g" "$nginx_dir/conf.d/$domain.conf"

				discuz_dir="$nginx_dir/html/$domain"
				[ ! -d $discuz_dir ] && mkdir -p "$discuz_dir"
				cd "$discuz_dir" || { _red "无法进入目录$discuz_dir"; return 1; }
				wget -qO latest.zip https://github.com/kejilion/Website_source_code/raw/main/Discuz_X3.5_SC_UTF8_20240520.zip && unzip latest.zip && rm latest.zip

				ldnmp_restart
				ldnmp_display_success

				echo "数据库名: $DB_NAME"
				echo "用户名: $DB_USER"
				echo "密码: $DB_USER_PASSWD"
				echo "数据库地址: mysql"
				echo "表前缀: discuz_"
				;;
			4)
				clear
				webname="可道云桌面"

				ldnmp_install_status
				add_domain
				ldnmp_install_ssltls
				ldnmp_certs_status
				ldnmp_add_db

				wget -qO "$nginx_dir/conf.d/$domain.conf" "https://raw.githubusercontent.com/kejilion/nginx/main/kdy.com.conf"
				sed -i -e "s/yuming.com/$domain/g" -e "s/my_cache/fst_cache/g" "$nginx_dir/conf.d/$domain.conf"

				kdy_dir="$nginx_dir/html/$domain"
				[ ! -d $kdy_dir ] && mkdir -p "$kdy_dir"
				cd "$kdy_dir" || { _red "无法进入目录$kdy_dir"; return 1; }
				wget -qO latest.zip https://github.com/kalcaddle/kodbox/archive/refs/tags/1.50.02.zip && unzip latest.zip && rm latest.zip
				mv "$kdy_dir/kodbox-*" "$kdy_dir/kodbox"

				ldnmp_restart
				ldnmp_display_success

				echo "数据库名: $DB_NAME"
				echo "用户名: $DB_USER"
				echo "密码: $DB_USER_PASSWD"
				echo "数据库地址: mysql"
				echo "Redis地址: redis"
				;;
			5)
				clear
				webname="苹果CMS"

				ldnmp_install_status
				add_domain
				ldnmp_install_ssltls
				ldnmp_certs_status
				ldnmp_add_db

				wget -qO "$nginx_dir/conf.d/$domain.conf" "https://raw.githubusercontent.com/kejilion/nginx/main/maccms.com.conf"
				sed -i -e "s/yuming.com/$domain/g" -e "s/my_cache/fst_cache/g" "$nginx_dir/conf.d/$domain.conf"

				cms_dir="$nginx_dir/html/$domain"
				[ ! -d $cms_dir ] && mkdir -p "$cms_dir"
				cd "$cms_dir" || { _red "无法进入目录$cms_dir"; return 1; }
				wget -q https://github.com/magicblack/maccms_down/raw/master/maccms10.zip && unzip maccms10.zip && rm maccms10.zip
				cd "$cms_dir/template/" || { _red "无法进入目录$cms_dir/template/"; return 1; }
				wget -q https://github.com/kejilion/Website_source_code/raw/main/DYXS2.zip && unzip DYXS2.zip && rm "$cms_dir/template/DYXS2.zip"
				cp "$cms_dir/template/DYXS2/asset/admin/Dyxs2.php" "$cms_dir/application/admin/controller"
				cp "$cms_dir/template/DYXS2/asset/admin/dycms.html" "$cms_dir/application/admin/view/system"
				mv "$cms_dir/admin.php" "$cms_dir/vip.php"
				wget -qO "$cms_dir/application/extra/maccms.php" https://raw.githubusercontent.com/kejilion/Website_source_code/main/maccms.php
 
				ldnmp_restart
				ldnmp_display_success

				echo "数据库名: $DB_NAME"
				echo "用户名: $DB_USER"
				echo "密码: $DB_USER_PASSWD"
				echo "数据库地址: mysql"
				echo "数据库端口: 3306"
				echo "表前缀: mac_"
				echo "------------------------"
				echo "安装成功后登录后台地址"
				echo "https://$domain/vip.php"
				;;
			6)
				clear
				webname="独角数卡"

				ldnmp_install_status
				add_domain
				ldnmp_install_ssltls
				ldnmp_certs_status
				ldnmp_add_db

				wget -qO "$nginx_dir/conf.d/$domain.conf" "https://raw.githubusercontent.com/kejilion/nginx/main/dujiaoka.com.conf"
				sed -i -e "s/yuming.com/$domain/g" -e "s/my_cache/fst_cache/g" "$nginx_dir/conf.d/$domain.conf"

				djsk_dir="$nginx_dir/html/$domain"
				[ ! -d $djsk_dir ] && mkdir -p "$djsk_dir"
				cd "$djsk_dir" || { _red "无法进入目录$djsk_dir"; return 1; }
				wget -q https://github.com/assimon/dujiaoka/releases/download/2.0.6/2.0.6-antibody.tar.gz && tar -zxvf 2.0.6-antibody.tar.gz && rm 2.0.6-antibody.tar.gz

				ldnmp_restart
				ldnmp_display_success

				echo "数据库名: $DB_NAME"
				echo "用户名: $DB_USER"
				echo "密码: $DB_USER_PASSWD"
				echo "数据库地址: mysql"
				echo "数据库端口: 3306"
				echo ""
				echo "Redis主机: redis"
				echo "Redis地址: redis"
				echo "Redis端口: 6379"
				echo "Redis密码: 默认不填写"
				echo ""
				echo "网站url: https://$domain"
				echo "后台登录路径: /admin"
				echo "------------------------"
				echo "用户名: admin"
				echo "密码: admin"
				echo "------------------------"
				echo "后台登录出现0err或者其他登录异常问题"
				echo "使用命令: sed -i 's/ADMIN_HTTPS=false/ADMIN_HTTPS=true/g' $djsk_dir/dujiaoka/.env"
				;;
			7)
				clear
				webname="Flarum论坛"

				ldnmp_install_status
				add_domain
				ldnmp_install_ssltls
				ldnmp_certs_status
				ldnmp_add_db

				wget -qO "$nginx_dir/conf.d/$domain.conf" "https://raw.githubusercontent.com/kejilion/nginx/main/flarum.com.conf"
				sed -i -e "s/yuming.com/$domain/g" -e "s/my_cache/fst_cache/g" "$nginx_dir/conf.d/$domain.conf"

				flarum_dir="$nginx_dir/html/$domain"
				[ ! -d $flarum_dir ] && mkdir -p "$flarum_dir"
				cd "$flarum_dir" || { _red "无法进入目录$flarum_dir"; return 1; }

				docker exec php sh -c "php -r \"copy('https://getcomposer.org/installer', 'composer-setup.php');\""
				docker exec php sh -c "php composer-setup.php"
				docker exec php sh -c "php -r \"unlink('composer-setup.php');\""
				docker exec php sh -c "mv composer.phar /usr/local/bin/composer"

				docker exec php composer create-project flarum/flarum /var/www/html/$domain
				docker exec php sh -c "cd /var/www/html/$domain && composer require flarum-lang/chinese-simplified"
				docker exec php sh -c "cd /var/www/html/$domain && composer require fof/polls"

				ldnmp_restart
				ldnmp_display_success

				echo "数据库名: $DB_NAME"
				echo "用户名: $DB_USER"
				echo "密码: $DB_USER_PASSWD"
				echo "数据库地址: mysql"
				echo "数据库端口: 3306"
				echo "表前缀: flarum_"
				echo "管理员信息自行设置"
				;;
			8)
				clear
				webname="Typecho"

				ldnmp_install_status
				add_domain
				ldnmp_install_ssltls
				ldnmp_certs_status
				ldnmp_add_db

				wget -qO "$nginx_dir/conf.d/$domain.conf" "https://raw.githubusercontent.com/kejilion/nginx/main/typecho.com.conf"
				sed -i -e "s/yuming.com/$domain/g" -e "s/my_cache/fst_cache/g" "$nginx_dir/conf.d/$domain.conf"

				typecho_dir="$nginx_dir/html/$domain"
				[ ! -d $typecho_dir ] && mkdir -p "$typecho_dir"
				cd "$typecho_dir" || { _red "无法进入目录$typecho_dir"; return 1; }
				wget -qO latest.zip https://github.com/typecho/typecho/releases/latest/download/typecho.zip && unzip latest.zip && rm latest.zip

				ldnmp_restart
				ldnmp_display_success

				echo "数据库名: $DB_NAME"
				echo "用户名: $DB_USER"
				echo "密码: $DB_USER_PASSWD"
				echo "数据库地址: mysql"
				echo "数据库端口: 3306"
				echo "表前缀: typecho_"
				;;
			20)
				clear
				webname="PHP动态站点"

				ldnmp_install_status
				add_domain
				ldnmp_install_ssltls
				ldnmp_certs_status
				ldnmp_add_db

				wget -qO "$nginx_dir/conf.d/$domain.conf" "https://raw.githubusercontent.com/kejilion/nginx/main/index_php.conf"
				sed -i -e "s/yuming.com/$domain/g" -e "s/my_cache/fst_cache/g" "$nginx_dir/conf.d/$domain.conf"

				dyna_dir="$nginx_dir/html/$domain"
				[ ! -d $dyna_dir ] && mkdir -p "$dyna_dir"
				cd "$dyna_dir" || { _red "无法进入目录$dyna_dir"; return 1; }

				clear
				echo -e "[${yellow}1/6${white}] 上传PHP源码"
				echo "-------------"
				echo "目前只允许上传zip格式的源码包,请将源码包放到$dyna_dir目录下"
				echo -n "也可以输入下载链接远程下载源码包,直接回车将跳过远程下载:"
				read -r url_download

				if [ -n "$url_download" ]; then
					wget -q "$url_download"
				fi

				unzip $(ls -t *.zip | head -n 1)
				rm -f $(ls -t *.zip | head -n 1)

				clear
				echo -e "[${yellow}2/6${white}] index.php所在路径"
				echo "-------------"
				find "$(realpath .)" -name "index.php" -print

				echo -n "请输入index.php的路径,如($nginx_dir/html/$domain/wordpress/):"
				read -r index_path

				sed -i "s#root /var/www/html/$domain/#root $index_path#g" "$nginx_dir/conf.d/$domain.conf"
				sed -i "s#$nginx_dir/#/var/www/#g" "$nginx_dir/conf.d/$domain.conf"

				clear
				echo -e "[${yellow}3/6${white}] 请选择PHP版本"
				echo "-------------"
				echo -n "1. php最新版 | 2. php7.4:" 
				read -r php_v

				case "$php_v" in
					1)
						sed -i "s#php:9000#php:9000#g" "$nginx_dir/conf.d/$domain.conf"
						PHP_Version="php"
						;;
					2)
						sed -i "s#php:9000#php74:9000#g" "$nginx_dir/conf.d/$domain.conf"
						PHP_Version="php74"
						;;
					*)
						echo "无效的选择，请重新输入。"
						;;
				esac

				clear
				echo -e "[${yellow}4/6${white}] 安装指定扩展"
				echo "-------------"
				echo "已经安装的扩展"
				docker exec php php -m

				echo -n "$(echo -e "输入需要安装的扩展名称,如 ${yellow}SourceGuardian imap ftp${white} 等,直接回车将跳过安装:")"
				read -r php_extensions
				if [ -n "$php_extensions" ]; then
					docker exec $PHP_Version install-php-extensions $php_extensions
				fi

				clear
				echo -e "[${yellow}5/6${white}] 编辑站点配置"
				echo "-------------"
				echo "按任意键继续,可以详细设置站点配置,如伪静态等内容"
				read -n 1 -s -r -p ""
				vim "$nginx_dir/conf.d/$domain.conf"

				clear
				echo -e "[${yellow}6/6${white}] 数据库管理"
				echo "-------------"
				echo -n "1. 我搭建新站        2. 我搭建老站有数据库备份:"
				read -r use_db
				case $use_db in
					1)
						echo ""
						;;
					2)
						echo "数据库备份必须是.gz结尾的压缩包,请放到/opt/目录下,支持宝塔/1panel备份数据导入"
						echo -n "也可以输入下载链接,远程下载备份数据,直接回车将跳过远程下载:" 
						read -r url_download_db

						cd /opt/
						if [ -n "$url_download_db" ]; then
							wget -q "$url_download_db"
						fi
						gunzip $(ls -t *.gz | head -n 1)
						latest_sql=$(ls -t *.sql | head -n 1)
						DB_ROOT_PASSWD=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /data/docker_data/web/docker-compose.yml | tr -d '[:space:]')

						docker exec -i mysql mysql -u root -p"$DB_ROOT_PASSWD" $DB_NAME < "/opt/$latest_sql"
						echo "数据库导入的表数据"
						docker exec -i mysql mysql -u root -p"$DB_ROOT_PASSWD" -e "USE $DB_NAME; SHOW TABLES;"
						rm -f *.sql
						_green "数据库导入完成"
						;;
					*)
						echo ""
						;;
				esac

				ldnmp_restart
				ldnmp_display_success

				prefix="web$(shuf -i 10-99 -n 1)_"

				echo "数据库名: $DB_NAME"
				echo "用户名: $DB_USER"
				echo "密码: $DB_USER_PASSWD"
				echo "数据库地址: mysql"
				echo "数据库端口: 3306"
				echo "表前缀: $prefix"
				echo "管理员登录信息自行设置"
				;;
			21)
				ldnmp_install_nginx
				;;
			22)
				clear
				webname="站点重定向"

				nginx_install_status
				ip_address
				add_domain
				echo -n "请输入跳转域名:"
				read -r reverseproxy

				ldnmp_install_ssltls
				ldnmp_certs_status

				wget -qO "$nginx_dir/conf.d/$domain.conf" "https://raw.githubusercontent.com/kejilion/nginx/main/rewrite.conf"
				sed -i "s/yuming.com/$domain/g" "$nginx_dir/conf.d/$domain.conf"
				sed -i "s/baidu.com/$reverseproxy/g" "$nginx_dir/conf.d/$domain.conf"

				if nginx_check; then
					docker restart nginx >/dev/null 2>&1
				else
					_red "Nginx配置校验失败,请检查配置文件"
					return 1
				fi

				nginx_display_success
				;;
			23)
				clear
				webname="反向代理-IP+端口"

				nginx_install_status
				ip_address
				add_domain
				echo -n "请输入你的反代IP:" reverseproxy
				read -r reverseproxy
				echo -n "请输入你的反代端口:"
				read -r port

				ldnmp_install_ssltls
				ldnmp_certs_status

				wget -qO "$nginx_dir/conf.d/$domain.conf" "https://raw.githubusercontent.com/kejilion/nginx/main/reverse-proxy.conf"
				sed -i "s/yuming.com/$domain/g" "$nginx_dir/conf.d/$domain.conf"
				sed -i "s/0.0.0.0/$reverseproxy/g" "$nginx_dir/conf.d/$domain.conf"
				sed -i "s/0000/$port/g" "$nginx_dir/conf.d/$domain.conf"

				if nginx_check; then
					docker restart nginx >/dev/null 2>&1
				else
					_red "Nginx配置校验失败,请检查配置文件"
					return 1
				fi

				nginx_display_success
				;;
			24)
				clear
				webname="反向代理-域名"

				nginx_install_status
				ip_address
				add_domain
				echo -e "域名格式: ${yellow}http://www.google.com${white}"
				echo -n "请输入你的反代域名:"
				read -r proxy_domain

				ldnmp_install_ssltls
				ldnmp_certs_status

				wget -qO "$nginx_dir/conf.d/$domain.conf" "https://raw.githubusercontent.com/kejilion/nginx/main/reverse-proxy-domain.conf"
				sed -i "s/yuming.com/$domain/g" "$nginx_dir/conf.d/$domain.conf"
				sed -i "s|fandaicom|$proxy_domain|g" "$nginx_dir/conf.d/$domain.conf"

				if nginx_check; then
					docker restart nginx >/dev/null 2>&1
				else
					_red "Nginx配置校验失败,请检查配置文件"
					return 1
				fi

				nginx_display_success
				;;
			25)
				clear
				webname="静态站点"

				nginx_install_status
				add_domain
				ldnmp_install_ssltls
				ldnmp_certs_status

				wget -qO "$nginx_dir/conf.d/$domain.conf" "https://raw.githubusercontent.com/kejilion/nginx/main/html.conf"
				sed -i "s/yuming.com/$domain/g" "$nginx_dir/conf.d/$domain.conf"

				static_dir="$nginx_dir/html/$domain"
				[ ! -d $static_dir ] && mkdir -p "$static_dir"
				cd "$static_dir" || { _red "无法进入目录$static_dir"; return 1; }

				clear
				echo -e "[${yellow}1/2${white}] 上传静态源码"
				echo "-------------"
				echo "目前只允许上传zip格式的源码包,请将源码包放到$static_dir目录下"
				echo -n "也可以输入下载链接远程下载源码包,直接回车将跳过远程下载:"
				read -r url_download

				if [ -n "$url_download" ]; then
					wget -q "$url_download"
				fi

				unzip $(ls -t *.zip | head -n 1)
				rm -f $(ls -t *.zip | head -n 1)

				clear
				echo -e "[${yellow}2/6${white}] index.html所在路径"
				echo "-------------"
				find "$(realpath .)" -name "index.html" -print

				echo -n "请输入index.html的路径,如($nginx_dir/html/$domain/index/):"
				read -r index_path

				sed -i "s#root /var/www/html/$domain/#root $index_path#g" "$nginx_dir/conf.d/$domain.conf"
				sed -i "s#$nginx_dir/#/var/www/#g" "$nginx_dir/conf.d/$domain.conf"

				docker exec nginx chmod -R 777 /var/www/html

				if nginx_check; then
					docker restart nginx >/dev/null 2>&1
				else
					_red "Nginx配置校验失败,请检查配置文件"
					return 1
				fi

				nginx_display_success
				;;
			26)
				clear
				#webname="Bitwarden"

				#nginx_install_status
				#add_domain
				#ldnmp_install_ssltls
				#ldnmp_certs_status

				#docker run -d \
				#	--name bitwarden \
				#	--restart always \
				#	-p 3280:80 \
				#	-v /home/web/html/$yuming/bitwarden/data:/data \
				#	vaultwarden/server
				#duankou=3280
				#reverse_proxy

				#nginx_display_success
				;;

			27)
				clear
				#webname="halo"

				#nginx_install_status
				#add_domain
				#ldnmp_install_ssltls
				#ldnmp_certs_status

				#docker run -d --name halo --restart always -p 8010:8090 -v /home/web/html/$yuming/.halo2:/root/.halo2 halohub/halo:2
				#duankou=8010
				#reverse_proxy

				#nginx_display_success
				;;
			31)
				need_root
				while true; do
					clear
					echo "LDNMP站点管理"
					echo "LDNMP环境"
					echo "------------------------"
					ldnmp_version

					echo "站点信息                      证书到期时间"
					echo "------------------------"
					for cert_file in /data/docker_data/web/nginx/certs/*_cert.pem; do
						if [ -f "$cert_file" ]; then
							domain=$(basename "$cert_file" | sed 's/_cert.pem//')
							if [ -n "$domain" ]; then
								expire_date=$(openssl x509 -noout -enddate -in "$cert_file" | awk -F'=' '{print $2}')
								formatted_date=$(date -d "$expire_date" '+%Y-%m-%d')
								printf "%-30s%s\n" "$domain" "$formatted_date"
							fi
						fi
					done
					echo "------------------------"
					echo ""
					echo "数据库信息"
					echo "------------------------"
					if docker ps --format '{{.Names}}' | grep -q '^mysql$'; then
						DB_ROOT_PASSWD=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /data/docker_data/web/docker-compose.yml | tr -d '[:space:]')
						docker exec mysql mysql -u root -p"$DB_ROOT_PASSWD" -e "SHOW DATABASES;" 2> /dev/null | grep -Ev "Database|information_schema|mysql|performance_schema|sys"
					else
						_red "NONE"
					fi
					echo "------------------------"
					echo ""
					echo "站点目录"
					echo "------------------------"
					echo "数据目录: /data/docker_data/web/nginx/html     证书目录: /data/docker_data/web/nginx/certs     配置文件目录: /data/docker_data/web/nginx/conf.d"
					echo "------------------------"
					echo ""
					echo "操作"
					echo "------------------------"
					echo "1. 申请/更新域名证书               2. 修改域名"
					echo "3. 清理站点缓存                    4. 查看站点分析报告"
					echo "5. 编辑全局配置                    6. 编辑站点配置"
					echo "------------------------"
					echo "7. 删除指定站点                    8. 删除指定数据库"
					echo "------------------------"
					echo "0. 返回上一级选单"
					echo "------------------------"

					echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
					read -r choice

					case $choice in
						1)
							echo -n "请输入你的域名:"
							read -r domain

							ldnmp_install_certbot
							ldnmp_install_ssltls
							ldnmp_certs_status
							;;
						2)
							echo -n "请输入旧域名:"
							read -r old_domain
							echo -n "请输入新域名:"
							rand -r new_domain
							ldnmp_install_certbot
							ldnmp_install_ssltls
							ldnmp_certs_status
							mv "$nginx_dir/conf.d/$old_domain.conf" "$nginx_dir/conf.d/$new_domain.conf"
							sed -i "s/$old_domain/$new_domain/g" "/data/docker_data/web/nginx/conf.d/$new_domain.conf"
							mv "$nginx_dir/html/$old_domain" "$nginx_dir/html/$new_domain"
							
							rm -f "$nginx_dir/certs/${old_domain}_key.pem" "$nginx_dir/certs/${old_domain}_cert.pem"

							if nginx_check; then
								docker restart nginx >/dev/null 2>&1
							else
								_red "Nginx配置校验失败,请检查配置文件"
								return 1
							fi
							;;
						3)
							if docker ps --format '{{.Names}}' | grep -q '^nginx$'; then
								docker restart nginx >/dev/null 2>&1
							else
								_red "未发现Nginx容器或未运行"
								return 1
							fi
							docker exec php php -r 'opcache_reset();'
							docker restart php
							docker exec php74 php -r 'opcache_reset();'
							docker restart php74
							docker restart redis
							docker exec redis redis-cli FLUSHALL
							docker exec -it redis redis-cli CONFIG SET maxmemory 512mb
							docker exec -it redis redis-cli CONFIG SET maxmemory-policy allkeys-lru
							;;
						4)
							install goaccess
							goaccess --log-format=COMBINED $nginx_dir/log/access.log
							;;
						5)
							vim $nginx_dir/nginx.conf

							if nginx_check; then
								docker restart nginx >/dev/null 2>&1
							else
								_red "Nginx配置校验失败,请检查配置文件"
								return 1
							fi
							;;
						6)
							echo -n "编辑站点配置,请输入你要编辑的域名:"
							vim "$nginx_dir/conf.d/$edit_domain.conf"

							if nginx_check; then
								docker restart nginx >/dev/null 2>&1
							else
								_red "Nginx配置校验失败,请检查配置文件"
								return 1
							fi
							;;
						7)
							cert_live_dir="/etc/letsencrypt/live"
							cert_archive_dir="/etc/letsencrypt/archive"
							cert_renewal_dir="/etc/letsencrypt/renewal"
							echo -n "删除站点数据目录,请输入你的域名:"
							read -r del_domain

							# 删除站点数据目录和相关文件
							rm -fr "$nginx_dir/html/$del_domain"
							rm -f "$nginx_dir/conf.d/$del_domain.conf" "$nginx_dir/certs/${del_domain}_key.pem" "$nginx_dir/certs/${del_domain}_cert.pem"

							# 检查并删除证书目录
							if [ -d "$cert_live_dir/$del_domain" ]; then
								rm -fr "$cert_live_dir/$del_domain"
							fi

							if [ -d "$cert_archive_dir/$del_domain" ];then
								rm -fr "$cert_archive_dir/del_domain"
							fi

							if [ -d "$cert_renewal_dir/$del_domain" ];then
								rm -fr "$cert_renewal_dir/$del_domain"
							fi

							# 检查Nginx配置并重启Nginx
							if nginx_check; then
								docker restart nginx >/dev/null 2>&1
							else
								_red "Nginx配置校验失败,请检查配置文件"
								return 1
							fi
							;;
						8)
							echo -n "删除站点数据库,请输入数据库名:"
							read -r del_database
							DB_ROOT_PASSWD=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /data/docker_data/web/docker-compose.yml | tr -d '[:space:]')
							docker exec mysql mysql -u root -p"$DB_ROOT_PASSWD" -e "DROP DATABASE $del_database;" >/dev/null 2>&1
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
			32)
				clear

				if docker ps --format '{{.Names}}' | grep -q '^ldnmp$'; then
					cd $web_dir && manage_compose down
					cd .. && tar czvf web_$(date +"%Y%m%d%H%M%S").tar.gz web

					while true; do
						clear
						read -p "要传送文件到远程服务器吗?(y/n):"
						read -r choice

						case "$choice" in
							[Yy])
								echo -n "请输入远端服务器IP:" remote_ip
								read -r remote_ip

								if [ -z "$remote_ip" ]; then
									_red "请正确输入远端服务器IP"
									continue
								fi
								latest_tar=$(ls -t $web_dir/*.tar.gz | head -1)
								if [ -n "$latest_tar" ]; then
									ssh-keygen -f "/root/.ssh/known_hosts" -R "$remote_ip"
									sleep 2  # 添加等待时间
									scp -o StrictHostKeyChecking=no "$latest_tar" "root@$remote_ip:/opt"
									_green "文件已传送至远程服务器/opt目录"
								else
									_red "未找到要传送的文件"
								fi
								break
								;;
							[Nn])
								break
								;;
							*)
								_red "无效选项,请重新输入"
								;;
						esac
					done
				else
					_red "未检测到LDNMP环境"
				fi
				;;
			33)
				clear

				echo -n "输入远程服务器IP:"
				read -r useip
				echo -n "输入远程服务器密码:"
				read -r usepasswd

				[ ! -d /data/script ] && mkdir -p /data/script
				cd /data/script || { _red "进入目录/data/script失败"; return 1; }
				wget -qO "${useip}_beifen.sh" "https://raw.githubusercontent.com/kejilion/sh/main/beifen.sh"
				chmod +x ${useip}_beifen.sh

				sed -i "s/0.0.0.0/$useip/g" ${useip}_beifen.sh
				sed -i "s/123456/$usepasswd/g" ${useip}_beifen.sh

				echo "------------------------"
				echo "1. 每周备份                 2. 每天备份"
				echo -n "请输入你的选择: "
				read -r choice

				case $choice in
					1)
						check_crontab_installed
						echo -n "选择每周备份的星期几(0-6,0代表星期日):" weekday
						(crontab -l ; echo "0 0 * * $weekday ./${useip}_beifen.sh > /dev/null 2>&1") | crontab -
						;;
					2)
						check_crontab_installed
						read -p "选择每天备份的时间（小时，0-23）: " hour
						(crontab -l ; echo "0 $hour * * * ./${useip}_beifen.sh") | crontab - > /dev/null 2>&1
						;;
					*)
						break  # 跳出
						;;
				esac

				install sshpass
				;;
			34)
				need_root

				ldnmp_restore_check
				echo "请确认/opt目录中已经放置网站备份的gz压缩包,按任意键继续"
				read -n 1 -s -r -p ""
				_yellow "正在解压"
				cd /opt && ls -t /opt/*.tar.gz | head -1 | xargs -I {} tar -xzf {}

				# 清理并创建必要的目录
				web_dir="/data/docker_data/web"
				[ -d "$web_dir" ] && rm -fr "$web_dir"
				mkdir -p "$web_dir"

				cd "$web_dir" || { _red "无法进入目录 $web_dir"; return 1; }
				mv /opt/web .

				ldnmp_check_port
				ldnmp_install_deps
				#install_docker
				ldnmp_install_certbot
				install_ldnmp
				;;
			35)
				if docker inspect fail2ban &>/dev/null ; then
					while true; do
						clear
						echo "服务器防御程序已启动"
						echo "------------------------"
						echo "1. 开启SSH防暴力破解              2. 关闭SSH防暴力破解"
						echo "3. 开启网站保护                   4. 关闭网站保护"
						echo "------------------------"
						echo "5. 查看SSH拦截记录                6. 查看网站拦截记录"
						echo "7. 查看防御规则列表               8. 查看日志实时监控"
						echo "------------------------"
						echo "11. 配置拦截参数"
						echo "------------------------"
						echo "21. cloudflare模式                22. 高负载开启5秒盾"
						echo "------------------------"
						echo "9. 卸载防御程序"
						echo "------------------------"
						echo "0. 退出"
						echo "------------------------"

						echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
						read -r choice

						case $choice in
							1)
								[ -f /data/docker_data/fail2ban/config/fail2ban/jail.d/alpine-ssh.conf ] && sed -i 's/false/true/g' /data/docker_data/fail2ban/config/fail2ban/jail.d/alpine-ssh.conf
								[ -f /data/docker_data/fail2ban/config/fail2ban/jail.d/linux-ssh.conf ] && sed -i 's/false/true/g' /data/docker_data/fail2ban/config/fail2ban/jail.d/linux-ssh.conf
								[ -f /data/docker_data/fail2ban/config/fail2ban/jail.d/centos-ssh.conf ] && sed -i 's/false/true/g' /data/docker_data/fail2ban/config/fail2ban/jail.d/centos-ssh.conf
								fail2ban_status
								;;
							2)
								[ -f /data/docker_data/fail2ban/config/fail2ban/jail.d/alpine-ssh.conf ] && sed -i 's/true/false/g' /data/docker_data/fail2ban/config/fail2ban/jail.d/alpine-ssh.conf
								[ -f /data/docker_data/fail2ban/config/fail2ban/jail.d/linux-ssh.conf ] && sed -i 's/true/false/g' /data/docker_data/fail2ban/config/fail2ban/jail.d/linux-ssh.conf
								[ -f /data/docker_data/fail2ban/config/fail2ban/jail.d/centos-ssh.conf ] && sed -i 's/true/false/g' /data/docker_data/fail2ban/config/fail2ban/jail.d/centos-ssh.conf
								fail2ban_status
								;;
							3)
								[ -f /data/docker_data/fail2ban/config/fail2ban/jail.d/nginx-docker-cc.conf ] && sed -i 's/false/true/g' /data/docker_data/fail2ban/config/fail2ban/jail.d/nginx-docker-cc.conf
								fail2ban_status
								;;
							4)
								[ -f /data/docker_data/fail2ban/config/fail2ban/jail.d/nginx-docker-cc.conf ] && sed -i 's/true/false/g' /data/docker_data/fail2ban/config/fail2ban/jail.d/nginx-docker-cc.conf
								fail2ban_status
								;;
							5)
								echo "------------------------"
								fail2ban_sshd
								echo "------------------------"
								;;
							6)
								echo "------------------------"
								jail_name=fail2ban-nginx-cc
								fail2ban_status_jail
								echo "------------------------"
								jail_name=docker-nginx-bad-request
								fail2ban_status_jail
								echo "------------------------"
								jail_name=docker-nginx-botsearch
								fail2ban_status_jail
								echo "------------------------"
								jail_name=docker-nginx-http-auth
								fail2ban_status_jail
								echo "------------------------"
								jail_name=docker-nginx-limit-req
								fail2ban_status_jail
								echo "------------------------"
								jail_name=docker-php-url-fopen
								fail2ban_status_jail
								echo "------------------------"
								;;
							7)
								docker exec fail2ban fail2ban-client status
								;;
							8)
								timeout 5 tail -f /data/docker_data/fail2ban/config/log/fail2ban/fail2ban.log
								;;
							9)
								cd /data/docker_data/fail2ban || { _red "无法进入目录/data/docker_data/fail2ban"; return 1; }
								manage_compose clean_down

								[ -d /data/docker_data/fail2ban ] && rm -fr /data/docker_data/fail2ban
								crontab -l | grep -v "CF-Under-Attack.sh" | crontab - 2>/dev/null
								_green "Fail2Ban防御程序已卸载"
								break
								;;
							11)
								vim /data/docker_data/fail2ban/config/fail2ban/jail.d/nginx-docker-cc.conf
								fail2ban_status
								break
								;;
							21)
								echo "Cloudflare后台右上角我的个人资料,选择左侧API令牌,获取Global API Key"
								echo "https://dash.cloudflare.com/login"

								# 获取CFUSER
								while true; do
									echo -n "请输入你的Cloudflare管理员邮箱:"
									read -r CFUSER
									if [[ "$CFUSER" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
										break
									else
										_red "无效的邮箱格式,请重新输入"
									fi
								done
								# 获取CFKEY
								while true; do
									echo "cloudflare后台右上角我的个人资料,选择左侧API令牌,获取Global API Key"
									echo "https://dash.cloudflare.com/login"
									echo -n "请输入你的Global API Key:"
									read -r CFKEY
									if [[ -n "$CFKEY" ]]; then
										break
									else
										_red "CFKEY不能为空,请重新输入"
									fi
								done

								wget -qO /data/docker_data/web/nginx/conf.d/default.conf https://raw.githubusercontent.com/honeok8s/conf/main/nginx/conf.d/default11.conf

								if nginx_check; then
									docker restart nginx >/dev/null 2>&1
								else
									_red "Nginx配置校验失败,请检查配置文件"
									return 1
								fi

								cd /data/docker_data/fail2ban/config/fail2ban/jail.d || { _red "无法进入目录 /data/docker_data/fail2ban/config/fail2ban/jail.d"; return 1; }
								curl -sS -O https://raw.githubusercontent.com/honeok8s/conf/main/fail2ban/nginx-docker-cc.conf
								
								cd /data/docker_data/fail2ban/config/fail2ban/action.d || { _red "无法进入目录 /data/docker_data/fail2ban/config/fail2ban/action.d"; return 1; }
								curl -sS -O https://raw.githubusercontent.com/honeok8s/conf/main/fail2ban/cloudflare-docker.conf
								
								sed -i "s/kejilion@outlook.com/$CFUSER/g" /data/docker_data/fail2ban/config/fail2ban/action.d/cloudflare-docker.conf
								sed -i "s/APIKEY00000/$CFKEY/g" /data/docker_data/fail2ban/config/fail2ban/action.d/cloudflare-docker.conf

								fail2ban_status
								_green "已配置Cloudflare模式,可在Cloudflare后台站点-安全性-事件中查看拦截记录"
								;;
							22)
								echo "网站每5分钟自动检测,当达检测到高负载会自动开盾,低负载也会自动关闭5秒盾"
								echo "------------------------"

								# 获取CFUSER
								while true; do
									echo -n "请输入你的Cloudflare管理员邮箱:"
									read -r CFUSER
									if [[ "$CFUSER" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
										break
									else
										_red "无效的邮箱格式,请重新输入"
									fi
								done
								# 获取CFKEY
								while true; do
									echo "cloudflare后台右上角我的个人资料,选择左侧API令牌,获取Global API Key"
									echo "https://dash.cloudflare.com/login"
									echo -n "请输入你的Global API Key:"
									read -r CFKEY
									if [[ -n "$CFKEY" ]]; then
										break
									else
										_red "CFKEY不能为空,请重新输入"
									fi
								done
								# 获取ZoneID
								while true;do
									echo "Cloudflare后台域名概要页面右下方获取区域ID"
									echo -n "请输入你的ZoneID:"
									read -r CFZoneID
									if [[ -n "$CFZoneID" ]]; then
										break
									else
										_red "CFZoneID不能为空,请重新输入"
									fi
								done

								install jq bc
								check_crontab_installed

								[ ! -d /data/script ] && mkdir -p /data/script
								cd /data/script || { _red "进入目录/data/script失败"; return 1; }

								curl -sS -O https://raw.githubusercontent.com/kejilion/sh/main/CF-Under-Attack.sh
								chmod +x CF-Under-Attack.sh
								sed -i "s/AAAA/$CFUSER/g" /data/script/CF-Under-Attack.sh
								sed -i "s/BBBB/$CFKEY/g" /data/script/CF-Under-Attack.sh
								sed -i "s/CCCC/$CFZoneID/g" /data/script/CF-Under-Attack.sh

								cron_job="*/5 * * * * /data/script/CF-Under-Attack.sh >/dev/null 2>&1"
								existing_cron=$(crontab -l 2>/dev/null | grep -F "$cron_job")
								
								if [ -z "$existing_cron" ]; then
									(crontab -l 2>/dev/null; echo "$cron_job") | crontab -
									_green "高负载自动开盾脚本已添加"
								else
									_yellow "自动开盾脚本已存在,无需添加"
								fi
								;;
							0)
								break
								;;
							*)
								_red "无效选项,请重新输入"
								;;
						esac
						end_of
					done
				elif [ -x "$(command -v fail2ban-client)" ] ; then
					clear
					echo "卸载旧版Fail2ban"
					echo -n "确定继续吗?(y/n):"
					read -r choice
					
					case "$choice" in
						[Yy])
							remove fail2ban
							rm -fr /etc/fail2ban
							_green "Fail2Ban防御程序已卸载"
							;;
						[Nn])
							:
							_yellow "已取消"
							;;
						*)
							_red "无效选项,请重新输入"
							;;
					esac
				else
					clear
					#install_docker
					ldnmp_install_nginx
					fail2ban_install_sshd

					cd /data/docker_data/fail2ban/config/fail2ban/filter.d
					curl -sS -O https://raw.githubusercontent.com/kejilion/sh/main/fail2ban-nginx-cc.conf
					cd /data/docker_data/fail2ban/config/fail2ban/jail.d
					curl -sS -O https://raw.githubusercontent.com/kejilion/config/main/fail2ban/nginx-docker-cc.conf

					sed -i "/cloudflare/d" /data/docker_data/fail2ban/config/fail2ban/jail.d/nginx-docker-cc.conf

					fail2ban_status
					_green "防御程序已开启"
				fi
				;;
			36)
				while true; do
					clear
					echo "优化LDNMP环境"
					echo "------------------------"
					echo "1. 标准模式              2. 高性能模式(推荐2H2G以上)"
					echo "------------------------"
					echo "0. 退出"
					echo "------------------------"
					echo -n "请输入你的选择:"
					read -r choice

					case $choice in
						1)
							_yellow "站点标准模式"
							# nginx调优
							sed -i 's/worker_connections.*/worker_connections 1024;/' "$nginx_dir/nginx.conf"

							# php调优
							wget -qO "$web_dir/optimized_php.ini" "https://raw.githubusercontent.com/kejilion/sh/main/optimized_php.ini"
							docker cp "$web_dir/optimized_php.ini" "php:/usr/local/etc/php/conf.d/optimized_php.ini"
							docker cp "$web_dir/optimized_php.ini" "php74:/usr/local/etc/php/conf.d/optimized_php.ini"
							rm -f "$web_dir/optimized_php.ini"

							# php调优
							wget -qO "$web_dir/www.conf" "https://raw.githubusercontent.com/kejilion/sh/main/www-1.conf"
							docker cp "$web_dir/www.conf" "php:/usr/local/etc/php-fpm.d/www.conf"
							docker cp "$web_dir/www.conf" "php74:/usr/local/etc/php-fpm.d/www.conf"
							rm -f "$web_dir/www.conf"

							# mysql调优
							wget -qO "$web_dir/my.cnf" https://raw.githubusercontent.com/kejilion/sh/main/custom_mysql_config-1.cnf
							docker cp "$web_dir/my.cnf" "mysql:/etc/mysql/conf.d/"
							rm -f /home/custom_mysql_config.cnf

							docker exec -it redis redis-cli CONFIG SET maxmemory 512mb
							docker exec -it redis redis-cli CONFIG SET maxmemory-policy allkeys-lru

							docker restart nginx
							docker restart php
							docker restart php74
							docker restart mysql

							_green "LDNMP环境已设置成标准模式"
							;;
						2)
							_yellow "站点高性能模式"
							# nginx调优
							sed -i 's/worker_connections.*/worker_connections 10240;/' /home/web/nginx.conf

							# php调优
							wget -O /home/www.conf https://raw.githubusercontent.com/kejilion/sh/main/www.conf
							docker cp /home/www.conf php:/usr/local/etc/php-fpm.d/www.conf
							docker cp /home/www.conf php74:/usr/local/etc/php-fpm.d/www.conf
							rm -f /home/www.conf

							# mysql调优
							wget -O /home/custom_mysql_config.cnf https://raw.githubusercontent.com/kejilion/sh/main/custom_mysql_config.cnf
							docker cp /home/custom_mysql_config.cnf mysql:/etc/mysql/conf.d/
							rm -rf /home/custom_mysql_config.cnf

							docker exec -it redis redis-cli CONFIG SET maxmemory 1024mb
							docker exec -it redis redis-cli CONFIG SET maxmemory-policy allkeys-lru

							docker restart nginx
							docker restart php
							docker restart php74
							docker restart mysql

							_green "LDNMP环境已设置成高性能模式"
							;;
						0)
							break
							;;
						*)
							_red "无效选项,请重新输入"
							;;
					esac
					end_of
				done
				;;
			37)
				need_root
				while true; do
					clear
					echo "更新LDNMP环境"
					echo "------------------------"
					ldnmp_version
					echo "1. 更新Nginx     2. 更新MySQL(建议不做更新)     3. 更新PHP     4. 更新Redis"
					echo "------------------------"
					echo "5. 更新完整环境"
					echo "------------------------"
					echo "0. 返回上一级"
					echo "------------------------"
					echo -n "请输入你的选择:"
					read -r choice

					case $choice in
						1)
							ldnmp_pods="nginx"
							cd "$web_dir"

							docker rm -f "$ldnmp_pods" > /dev/null 2>&1
							docker images --filter=reference="$ldnmp_pods*" -q | xargs docker rmi > /dev/null 2>&1
							docker compose up -d --force-recreate "$ldnmp_pods"
							docker exec "$ldnmp_pods" chmod -R 777 /var/www/html
							docker restart "$ldnmp_pods" > /dev/null 2>&1
							_green "更新${ldnmp_pods}完成"
							;;
						2)
							ldnmp_pods="mysql"
							echo -n "请输入${ldnmp_pods}版本号(如: 8.0 8.3 8.4 9.0)(回车获取最新版):"
							read -r version
							version=${version:-latest}
							cd "$web_dir"

							sed -i "s/image: mysql/image: mysql:$version/" "$web_dir/docker-compose.yml"
							docker rm -f "$ldnmp_pods"
							docker images --filter=reference="$ldnmp_pods*" -q | xargs docker rmi > /dev/null 2>&1
							docker compose up -d --force-recreate "$ldnmp_pods"
							docker restart "$ldnmp_pods" > /dev/null 2>&1
							_green "更新${ldnmp_pods}完成"
							;;
						3)
							ldnmp_pods="php"
							echo -n "请输入${ldnmp_pods}版本号(如: 7.4 8.0 8.1 8.2 8.3)(回车获取最新版):"
							read -r version

							version=${version:-8.3}
							cd "$web_dir"
							sed -i "s/image: php:fpm-alpine/image: php:${version}-fpm-alpine/" "$web_dir/docker-compose.yml"
							docker rm -f "$ldnmp_pods" > /dev/null 2>&1
							docker images --filter=reference="php:*" -q | xargs -r docker rmi > /dev/null 2>&1
							docker compose up -d --force-recreate "$ldnmp_pods"
							docker exec "$ldnmp_pods" chmod -R 777 /var/www/html

							docker exec "$ldnmp_pods" apk update
							curl -sL https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions -o /usr/local/bin/install-php-extensions
							docker exec "$ldnmp_pods" mkdir -p /usr/local/bin/
							docker cp /usr/local/bin/install-php-extensions "$ldnmp_pods":/usr/local/bin/
							docker exec "$ldnmp_pods" chmod +x /usr/local/bin/install-php-extensions
							rm /usr/local/bin/install-php-extensions

							docker exec "$ldnmp_pods" sh -c "\
								apk add --no-cache imagemagick imagemagick-dev \
								&& apk add --no-cache git autoconf gcc g++ make pkgconfig \
								&& rm -rf /tmp/imagick \
								&& git clone https://github.com/Imagick/imagick /tmp/imagick \
								&& cd /tmp/imagick \
								&& phpize \
								&& ./configure \
								&& make \
								&& make install \
								&& echo 'extension=imagick.so' > /usr/local/etc/php/conf.d/imagick.ini \
								&& rm -rf /tmp/imagick"

							docker exec "$ldnmp_pods" install-php-extensions mysqli pdo_mysql gd intl zip exif bcmath opcache redis

							docker exec "$ldnmp_pods" sh -c 'echo "upload_max_filesize=50M" > /usr/local/etc/php/conf.d/uploads.ini' > /dev/null 2>&1
							docker exec "$ldnmp_pods" sh -c 'echo "post_max_size=50M" > /usr/local/etc/php/conf.d/post.ini' > /dev/null 2>&1
							docker exec "$ldnmp_pods" sh -c 'echo "memory_limit=256M" > /usr/local/etc/php/conf.d/memory.ini' > /dev/null 2>&1
							docker exec "$ldnmp_pods" sh -c 'echo "max_execution_time=1200" > /usr/local/etc/php/conf.d/max_execution_time.ini' > /dev/null 2>&1
							docker exec "$ldnmp_pods" sh -c 'echo "max_input_time=600" > /usr/local/etc/php/conf.d/max_input_time.ini' > /dev/null 2>&1

							docker restart "$ldnmp_pods" > /dev/null 2>&1
							_green "更新${ldnmp_pods}完成"
							;;
						4)
							ldnmp_pods="redis"

							cd "$web_dir"
							docker rm -f "$ldnmp_pods" > /dev/null 2>&1
							docker images --filter=reference="$ldnmp_pods*" -q | xargs docker rmi > /dev/null 2>&1
							docker compose up -d --force-recreate "$ldnmp_pods"
							docker exec -it "$ldnmp_pods" redis-cli CONFIG SET maxmemory 512mb
							docker exec -it "$ldnmp_pods" redis-cli CONFIG SET maxmemory-policy allkeys-lru
							docker restart "$ldnmp_pods" > /dev/null 2>&1
							_green "更新${ldnmp_pods}完成"
							;;
						5)
							echo -n "长时间不更新环境的用户请慎重更新LDNMP环境,会有数据库更新失败的风险,确定更新LDNMP环境吗?(y/n):"
							read -r choice

							case "$choice" in
								[Yy])
									_yellow "完整更新LDNMP环境"
									cd "$web_dir"
									manage_compose down_all

									ldnmp_check_port
									ldnmp_install_deps
									#install_docker
									ldnmp_install_certbot
									install_ldnmp
									;;
								*)
									;;
							esac
							;;
						0)
							break
							;;
						*)
							echo "无效的选择，请重新输入。"
							;;
					esac
					end_of
				done
				;;
			38)
				need_root
				echo "建议先备份全部网站数据再卸载LDNMP环境"
				echo "同时会移除由LDNMP建站安装的依赖"
				echo -n "确认继续?(y/n):"
				read -r choice

				case "$choice" in
					[Yy])
						if docker inspect "ldnmp" &>/dev/null; then
							cd "$web_dir" || { _red "无法进入目录 $web_dir"; return 1; }
							manage_compose clean_down
							ldnmp_uninstall_deps
							ldnmp_uninstall_certbot
							rm -fr "$web_dir"
							_green "LDNMP环境已卸载并清除相关依赖"
						elif docker inspect "nginx" &>/dev/null && [ -d "$nginx_dir" ]; then
							cd "$web_dir" || { _red "无法进入目录 $web_dir"; return 1; }
							manage_compose clean_down
							ldnmp_uninstall_deps
							ldnmp_uninstall_certbot
							rm -fr "$web_dir"
							_green "Nginx环境已卸载并清除相关依赖"
						else
							_red "未发现符合条件的LDNMP或Nginx环境"
						fi
						;;
					[Nn])
						_yellow "操作已取消"
						;;
					*)
						_red "无效选项,请重新输入"
						;;
				esac
				;;
			0)
				honeok
				;;
			*)
				_red "无效选项,请重新输入"
				;;
		esac
		end_of
	done
}
linux_ldnmp