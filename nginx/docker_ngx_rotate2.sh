#!/bin/bash
# Author: honeok
# Blog: https://www.honeok.com

set -e

log_dir="./log"
current_date=$(date +"%Y-%m-%d")
compress_cmd="gzip"
keep_days=7
nginx_name="nginx"

# Rotate the specified log file
rotate_log() {
	local log_file="$1"
	[ -f "$log_file" ] && mv "$log_file" "$log_dir/$(basename "$log_file" .log)_$current_date.log"
}

# Compress the specified log file
compress_log() {
	local log_file="$1"
	[ -f "$log_file" ] && $compress_cmd "$log_file"
}

# Execute log rotation for access and error logs
rotate_log "$log_dir/access.log"
rotate_log "$log_dir/error.log"

# Send a signal to the Nginx container to reopen the log files
docker exec $nginx_name nginx -s reopen

# Compress the rotated logs
compress_log "$log_dir/access_$current_date.log"
compress_log "$log_dir/error_$current_date.log"

# Remove logs older than the specified retention period
find "$log_dir" -type f -name "*.log.gz" -mtime +$keep_days -exec rm -f {} \;

exit 0