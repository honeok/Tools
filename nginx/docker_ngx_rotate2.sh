#!/usr/bin/env bash
## Author: honeok
## Blog：www.honeok.com
## Github：https://github.com/honeok/Tools

set -e

log_dir="./log"                        # 日志目录
current_date=$(date +"%Y-%m-%d")       # 当前日期
compress_cmd="gzip"                    # 压缩命令
keep_days=7                            # 保留天数
nginx_name="nginx"                     # Nginx 容器名称

# 对指定文件日志轮转
rotate_log() {
    local log_file="$1"
    [ -f "$log_file" ] && mv "$log_file" "$log_dir/$(basename "$log_file" .log)_$current_date.log"
}

# 压缩指定的日志文件
compress_log() {
    local log_file="$1"
    [ -f "$log_file" ] && $compress_cmd "$log_file"
}

# 日志轮转
rotate_log "$log_dir/access.log"
rotate_log "$log_dir/error.log"

# 向 Nginx 容器发送信号以重新打开日志文件
docker exec $nginx_name nginx -s reopen

# 压缩轮转后的日志
compress_log "$log_dir/access_$current_date.log"
compress_log "$log_dir/error_$current_date.log"

# 删除超过保留期的日志
find "$log_dir" -type f -name "*.log.gz" -mtime +$keep_days -exec rm -f {} \;

exit 0