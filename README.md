## VPS工具箱
Fork from kejilion：[kejilion.sh](https://github.com/kejilion/sh)
* 在线执行
```shell
bash <(curl -sL github.com/honeok/shell/raw/main/honeok.sh)
```
or
```shell
bash <(curl -sL gh-proxy.com/github.com/honeok/shell/raw/main/honeok.sh)
```

* 下载本地执行
```shell
curl -sL -O github.com/honeok/shell/raw/main/honeok.sh && chmod +x ./honeok.sh && ./honeok.sh
```
or
```
curl -sL -O gh-proxy.com/github.com/honeok/shell/raw/main/honeok.sh && chmod +x ./honeok.sh && ./honeok.sh
```
## Docker一键安装
根据IP归属地优化配置文件，安装镜像加速
* 安装
```shell
curl -sL github.com/honeok/shell/raw/main/docker/get-docker.sh | bash -
```
* 卸载
```shell
curl -sL github.com/honeok/shell/raw/main/docker/get-docker.sh | bash -s -- uninstall
```
## Serverstatus探针，客户端探针存活监控
项目地址：https://github.com/cppla/serverstatus
```shell
# 下载完成后自行修改Server端服务器IP地址

# KVM & XEN
curl -sL -O github.com/honeok/shell/raw/main/serverstatus/serverstatus_kvm.sh && chmod +x ./serverstatus_kvm.sh
sed -i 's/127\.0\.0\.1/49.51.47.101/g' ./serverstatus_kvm.sh

# LXC & OpenVZ
curl -sL -O github.com/honeok/shell/raw/main/serverstatus/serverstatus_lxc.sh && chmod +x ./serverstatus_lxc.sh
sed -i 's/127\.0\.0\.1/49.51.47.101/g' ./serverstatus_lxc.sh
```
## NGINX日志管理
适用编译安装NGINX及基于NGINX二次开发的高性能WEB服务器日志切割备份删除
LOG_DIR="/usr/local/nginx/logs"              日志路径可自行定义
BAK_DIR="/usr/local/nginx/logs/backup"       日志备份路径可自行定义
```shell
curl -sL -O github.com/honeok/shell/raw/main/nginx/ngx_logrotate.sh && chmod +x ./ngx_logrotate.sh
```
