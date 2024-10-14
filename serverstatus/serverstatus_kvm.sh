#!/bin/bash
# Author: honeok
# Blog: honeok.com
# Desc: Script to manage serverstatus probe
# Example: */1 * * * * /root/serverstatus_kvm.sh s250 >/dev/null 2>&1
# Github: https://raw.githubusercontent.com/honeok8s/shell/main/serverstatus_kvm.sh

set -o errexit

# ANSI颜色码
yellow='\033[1;33m' # 用于提示信息
red='\033[1;31m'    # 用于警告信息
green='\033[1;32m'  # 用于成功信息
white='\033[0m'     # 用于结束颜色设置

PARAMS=("$@")

if [[ $# -lt 1 ]];then
  printf "${yellow}Usage: ./$0 [server_id]${white}\n" && exit 1
elif [[ ! "${PARAMS}" =~ ^s[0-9]+$ ]];then
  printf "${red}Invalid server ID format.${white}\n" && exit 1
fi

set_timezone(){
  local ZONE=$(date -R | awk '{print $6}')
  if [[ "${ZONE}" != "+0800" ]];then
    timedatectl set-timezone Asia/Shanghai && systemctl restart cron 2>&1
  fi
}

manage_probe(){
  local LOG_TIME=$(date '+%Y-%m-%d %H:%M:%S')
  local GLOBLE_TIME=$(date '+%H:%M:%S')
  local COUNTER=$(ps -ef | grep '[c]lient-linux.py' | wc -l)

  if [[ ! -f "./client-linux.py" ]]; then
    for ((i=1; i<=10; i++)); do
      # 成都三网EndPoint
      wget --no-check-certificate -qO client-linux.py 'https://raw.githubusercontent.com/honeok8s/conf/main/client-linux.py' -N >/dev/null 2>&1
      if [[ $? -eq 0 && -s "./client-linux.py" ]]; then
        break
      fi
    done
    if [[ ! -s "./client-linux.py" ]]; then
      printf "${red}${LOG_TIME} [ERROR] Download file failed or file is empty.${white}\n"
      exit 1
    fi
  fi

  if [[ "${COUNTER}" == 0 ]]; then
    nohup python3 client-linux.py SERVER="127.0.0.1" USER="${PARAMS}" >/dev/null 2>&1 &
    echo "${LOG_TIME} [INFO] Probe started." >> ./main.log
  fi

  if [[ "${GLOBLE_TIME}" > "12:00:00" ]] && [[ "${GLOBLE_TIME}" < "12:00:50" ]]; then
    rm -f ./*.log 2>&1
  fi
}

main(){
  set_timezone
  manage_probe
}

main
