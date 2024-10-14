#!/usr/bin/env bash
# auth: honeok
# date: 2021-12-15
# desc: H5 DEPLOY IMAGE      TIPS: OLD SCRIPT IS /opt/script
##########################

. /etc/init.d/functions
CONTRAST=`docker images | grep -iv "REPOSITORY" | awk 'BEGIN{FS=" ";OFS=":"}{print $1,$2}'`
PARAMS=("$@")
set -o errexit
echo ""
echo -e "\033[033mUPDATED ON 2022-1-14 if There is an error @OP\033[0m"
if [[ ${#} -lt 1 ]];then
  echo "#####################"
  echo "No parameters!" && exit 1
fi
VAR_PRO="
-e VUE_APP_BASE_URL="weixin.com.cn/tg-car-api/mini" \
-e VUE_APP_BASE_URL_OTHER="weixin.com.cn/tg-car-api" \
-e VUE_APP_BASE_URL_OTHER_API="weixin.com.cn/tg-car-api" \
-e VUE_APP_BASE_URL_DSP="gateway.com.cn" \
"
##########[FUNC LIBRARY]##########
# Image sha256
CHECKIMG(){
for newimg in ${PARAMS};do
  for oldimg in ${CONTRAST};do
    if [[ ${newimg} == ${oldimg} ]];then
      echo "Mirror exists! Or Please use \"docker run\" function!" && exit 2
    fi
  done
done
}
GLOBAL(){
  echo -e -n "\n######## BEGIN TO [UPDATE|DEPLOY] ${PARAM} ########\n"
  docker pull ${PARAMS} || $(echo "please check your image name and try again!";exit 3)
  RUNCON=`docker ps | egrep "${SVCNAME}" | awk '{print $1}'`
  OLD_IMG_LOG=`docker ps | egrep -i "DongFengFengXing" | awk '{print $2}'`
  echo "`date +%Y-%m-%d' '%H:%M:%S` CHANGED [${OLD_IMG_LOG}]" >> ./liveoldimage.log
  echo ""
  docker stop ${RUNCON} &>/dev/null && action "[STOP OLD SERVICE CONTAINER]"
  echo ""
  docker rm -f ${RUNCON} &>/dev/null && action "[REMOVE OLD SERVICE CONTAINER]"
  echo ""
  docker run -itd --name=${SVCNAME}-$RANDOM -p ${HPORT}:${CPORT} ${VARIABLE} --restart=always ${PARAM}
  action "[DEPLOY NEW SERVICE CONTAINER]"
  echo -e "\033[33m########## WAIR 2 SECONDS ##########\033[0m" && sleep 2 && docker ps | egrep -i "${PARAM}"
}
PRUNEIMG(){
  echo ""
  echo -e "\033[033m########## CLEAR OLD IMAGE ##########\033[0m"
  echo ""
  echo "y" | docker system prune -a
}
##########[FUNC LIBRARY]##########
for PARAM in ${PARAMS[@]};do
  echo ""
  HPORT=""
  CPORT=""
  if [[ ${PARAM} =~ "lq_car_uni" ]];then HPORT=8080 && CPORT=3000 && SVCNAME="DongFengFengXing" && VARIABLE=${VAR_PRO};
  fi
  echo -e "\033[31m%%%%% HOST_PORT:${HPORT} CONTAINER_PORT:${CPORT} %%%%%\033[0m"
  echo ""
  CHECKIMG
  GLOBAL
  PRUNEIMG
  echo -e "\033[35m%%%%% do done %%%%%\033[0m"
done
