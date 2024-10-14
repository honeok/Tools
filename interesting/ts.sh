#!/bin/bash
# Copyright (c) 2024 honeok
# Current Author: honeok
# Blog: https://www.honeok.com

# Globle Colour
yellow='\e[33m'
green='\e[92m'
red='\e[31m'
none='\e[0m'
_yellow() { echo -e ${yellow}$@${none}; }
_green() { echo -e ${green}$@${none}; }
_red() { echo -e ${red}$@${none}; }

# Globle Install Path.
TS_WORKDIR="/data/docker_data/teamspeak"

# Country Select
if [[ "$(curl -s --connect-timeout 5 ipinfo.io/country)" == "CN" ]]; then
	COUNTRY="CN"
else
	COUNTRY=""
fi

# Github Proxy.
set_region_config() {
	if [[ "${COUNTRY}" == "CN" ]]; then
		local github_proxies=("gh-proxy.com" "gh.kejilion.pro" "github.moeyy.xyz")
		local best_proxy=""
		local best_time=9999
		local ping_time=""

		for proxy in "${github_proxies[@]}"; do
			ping_time=$(ping -c 2 -q "$proxy" | awk -F '/' 'END {print ($5 ? $5 : 9999)}')

			if (( $(echo "$ping_time" | awk '{print int($1+0.5)}') < $best_time )); then
				best_time=$(echo "$ping_time" | awk '{print int($1+0.5)}')
				best_proxy=$proxy
			fi
		done

		github_proxy="https://$best_proxy/"
	else
		github_proxy=""
	fi
}

# Use Region function set best github proxy.
set_region_config

########################################
# MAIN
# Check TeamSpeak Container.
if docker ps --format '{{.Image}}' | grep -q "teamspeak"; then
	_red "TeamSpeak容器正在运行，请不要重复安装。"
	exit 0
fi

# Check Docker Install.
if ! command -v docker >/dev/null 2>&1; then
	if [[ "${COUNTRY}" == "CN" ]]; then
		cd ~
		curl -fsSL -o "get-docker.sh" "${github_proxy}raw.githubusercontent.com/honeok8s/shell/main/docker/get-docker-official.sh" && chmod +x get-docker.sh
		sh get-docker.sh --mirror Aliyun
		rm -f get-docker.sh
	else
		curl -fsSL https://get.docker.com | sh
	fi
else
	:
fi

# Change Dir TS_WORKDIR
mkdir -p "${TS_WORKDIR}" && cd "${TS_WORKDIR}"
curl -fsSL -o "docker-compose.yml" "${github_proxy}raw.githubusercontent.com/honeok8s/conf/main/dockerapp/ts-docker-compose.yml"
if [[ "${COUNTRY}" == "CN" ]]; then
	sed -i 's|image: teamspeak:3.13.7|image: registry.cn-chengdu.aliyuncs.com/honeok/teamspeak:3.13.7|' docker-compose.yml
	sed -i 's|image: mariadb:11.4.2|image: registry.cn-chengdu.aliyuncs.com/honeok/mariadb:11.4.2|' docker-compose.yml
fi

# Run TeamSpeak Server
docker compose up -d
_yellow "您的TeamSpeak服务器搭建完毕！请在云服务器防火墙放行9987/UDP、10011/TCP、30033/TCP端口。"
sleep 1s && _yellow "Bey！"
docker compose ps