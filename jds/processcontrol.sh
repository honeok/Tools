#!/bin/bash
# Author: honeok 2024.8.2

# 定义日志目录
log_dir="/data/tool"
logback_dir="/data/logback"

# 动态生成服务器路径和名称
generate_servers() {
    local -n servers_ref=$1
    local -n names_ref=$2

    # 生成服务器路径和名称
    for i in {1..5}; do
        servers_ref+=("/data/server${i}/game/p8_app_server")
        names_ref+=("game${i}")
    done

    # 添加额外的服务器路径和名称
    servers_ref+=("/data/server/gate/p8_app_server" "/data/server/login/p8_app_server")
    names_ref+=("gate" "login")
}

# 定义监控和重启
check_and_restart() {
    local server_path=$1
    local server_name=$2

    # 检查服务器是否在运行
    if ! pgrep -f "${server_path}" > /dev/null; then
        # 记录重启日志
        echo "$(date '+%Y-%m-%d %H:%M:%S') ${server_name}-restart" >> "${log_dir}/dump.txt"

		# 备份并删除旧的 nohup.txt
		local server_dir=$(dirname "${server_path}")
		cp -f "${server_dir}/nohup.txt" "${logback_dir}/nohup_${server_name}_$(date +%Y%m%d%H%M%S).txt"
		rm -f "${server_dir}/nohup.txt"

        # 启动服务器
        (cd "${server_dir}" && ./server.sh start)
		
	else
		# 记录服务器正在运行
		echo "$(date '+%Y-%m-%d %H:%M:%S') ${server_name}-isrunning" >> "${log_dir}/control.txt"
    fi
}

# 初始化数组
declare -a servers
declare -a server_names

# 生成服务器路径和名称
generate_servers servers server_names

while true; do
    # 遍历所有服务器进行检查和处理
    for i in "${!servers[@]}"; do
        check_and_restart "${servers[$i]}" "${server_names[$i]}"
        sleep 5
    done
done