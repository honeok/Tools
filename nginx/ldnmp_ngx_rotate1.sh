#!/bin/bash

log_dir="/data/docker_data/web/nginx/log"
log_date=$(date +%Y-%m-%d)

# 切割日志
mv $log_dir/access.log $log_dir/access_$log_date.log
mv $log_dir/error.log $log_dir/error_$log_date.log

if docker inspect "nginx" &>/dev/null; then
	# 向Nginx发送信号,重新打开日志文件
	docker exec nginx nginx -s reopen
else
	exit 0
fi

# 压缩旧日志
gzip $log_dir/access_$log_date.log
gzip $log_dir/error_$log_date.log

# 删除7天前的日志
find $log_dir -type f -name "*.log.gz" -mtime +7 -exec rm {} \;
