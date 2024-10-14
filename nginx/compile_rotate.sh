#!/bin/bash
# Author: honeok
# Blog: honeok.com
# Desc: logrotate nginx log
# Example: 0 4 * * * /root/logrotate_ngx.sh >/dev/null 2>&1
# Github: https://raw.githubusercontent.com/honeok8s/shell/main/logrotate_ngx.sh

# set log and backup directories
LOG_DIR="/usr/local/nginx/logs"
BAK_DIR="/usr/local/nginx/logs/backup"
LOG_PREFIX="*.log"
LOG_FILE="/var/log/logrotate_ngx.log"  # script log

# create backup directory if it doesn't exist
if [[ ! -d "${BAK_DIR}" ]]; then
  mkdir -p "${BAK_DIR}"
  if [[ $? -ne 0 ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [ERROR] Failed to create backup directory ${BAK_DIR}" >> "${LOG_FILE}"; exit 1
  fi
fi

# use file locking to prevent concurrent script executions
LOCK_FILE="/var/lock/logrotate_ngx.lock"
exec 9>"${LOCK_FILE}"
if ! flock -n 9; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - [ERROR] Unable to acquire lock, another instance is running" >> "${LOG_FILE}"; exit 1
fi

# truncate and backup Nginx log files
find "${LOG_DIR}" -maxdepth 1 -type f -name "${LOG_PREFIX}" -exec sh -c '
  BAK_DIR="$1"
  LOG_FILE="$2"
  shift 2
  for FILE in "$@"; do
    [ "$FILE" != "$BAK_DIR" ] && [ "$FILE" != "$LOG_FILE" ] || continue
    BAK_FILE="${BAK_DIR}/$(basename "$FILE")-$(date +%Y%m%d%H%M%S).log"
    mv "$FILE" "$BAK_FILE" && echo "$(date +%Y-%m-%d\ %H:%M:%S) - [INFO] Truncated and backed up $FILE to $BAK_FILE" >> "$LOG_FILE"
    > "$FILE" && echo "$(date +%Y-%m-%d\ %H:%M:%S) - [INFO] Created new empty log file $FILE" >> "$LOG_FILE"
  done
' sh "${BAK_DIR}" "${LOG_FILE}" {} +

# delete backup log files older than 2 days
if [[ -d "${BAK_DIR}" ]]; then
  find "${BAK_DIR}" -maxdepth 1 -type f -name "*.log" -mtime +2 -delete && \
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] Deleted backup log files older than 2 days in ${BAK_DIR}" >> "${LOG_FILE}"
fi

# send USR1 signal to Nginx main process to reopen log files
NGX_PID=$(cat "${LOG_DIR}/nginx.pid" 2>/dev/null)
if [[ -n "${NGX_PID}" ]]; then
  kill -USR1 "${NGX_PID}" && \
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] Sent USR1 signal to Nginx main process (PID: ${NGX_PID})" >> "${LOG_FILE}"
fi

# close file lock
exec 9>&-

# check the log file for errors
if grep -q 'ERROR' "${LOG_FILE}"; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - [WARN] There was an error, please check ${LOG_FILE}" >> "${LOG_FILE}"; exit 1
fi

exit 0
