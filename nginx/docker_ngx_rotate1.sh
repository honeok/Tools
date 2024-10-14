#!/bin/bash

LOG_DIR="/data/docker_data/nginx/log"
DATE=$(date +%Y-%m-%d-%H-%M-%S)

# 切割日志
mv $LOG_DIR/access.log $LOG_DIR/access_$DATE.log
mv $LOG_DIR/error.log $LOG_DIR/error_$DATE.log

# 向Nginx发送信号,重新打开日志文件
docker exec nginx nginx -s reopen

# 压缩旧日志
gzip $LOG_DIR/access_$DATE.log
gzip $LOG_DIR/error_$DATE.log

# 删除7天前的日志
find $LOG_DIR -type f -name "*.log.gz" -mtime +7 -exec rm {} \;