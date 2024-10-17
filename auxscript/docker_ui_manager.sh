#!/usr/bin/env bash
# Author: honeok
# Blog：www.honeok.com
# Github：https://github.com/honeok/shell

export LANG=en_US.UTF-8

yellow='\033[93m'        # 亮黄色
red='\033[91m'           # 亮红色
green='\033[92m'         # 亮绿色
blue='\033[94m'          # 亮蓝色
cyan='\033[96m'          # 亮青色
purple='\033[95m'        # 亮紫色
gray='\033[37m'          # 亮灰色
orange='\033[38;5;214m'  # 亮橙色
white='\033[0m'          # 重置为默认颜色

_yellow() { echo -e ${yellow}$@${white}; }
_red() { echo -e ${red}$@${white}; }
_green() { echo -e ${green}$@${white}; }
_blue() { echo -e ${blue}$@${white}; }
_cyan() { echo -e ${cyan}$@${white}; }
_purple() { echo -e ${purple}$@${white}; }
_gray() { echo -e ${gray}$@${white}; }
_orange() { echo -e ${orange}$@${white}; }
########################################
# 无任何操作，只调用没有更新的函数，不用merge
manage_compose() {
    local compose_cmd
    # 检查 docker compose 版本
    if docker compose version >/dev/null 2>&1; then
        compose_cmd="docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        compose_cmd="docker-compose"
    fi

    case "$1" in
        start)    # 启动容器
            $compose_cmd up -d
            ;;
        restart)
            $compose_cmd restart
            ;;
        stop)    # 停止容器
            $compose_cmd stop
            ;;
        recreate)
            $compose_cmd up -d --force-recreate
            ;;
        down)    # 停止并删除容器
            $compose_cmd down
            ;;
        pull)
            $compose_cmd pull
            ;;
        down_all) # 停止并删除容器、镜像、卷、未使用的网络
            $compose_cmd down --rmi all --volumes --remove-orphans
            ;;
        version)
            $compose_cmd version
            ;;
    esac
}

# 结尾任意键结束
end_of() {
    _green "操作完成"
    _yellow "按任意键继续"
    read -n 1 -s -r -p ""
    echo ""
    clear
}

#######################################################################################################################






# 获取公网IP地址
ip_address() {
    local ipv4_services=("ipv4.ip.sb" "api.ipify.org" "checkip.amazonaws.com" "ipinfo.io/ip")
    local ipv6_services=("ipv6.ip.sb" "api6.ipify.org" "v6.ident.me" "ipv6.icanhazip.com")

    ipv4_address=""  # 初始化全局变量
    ipv6_address=""

    # 获取IPv4地址
    for service in "${ipv4_services[@]}"; do
        ipv4_address=$(curl -s "$service")
        if [[ "$ipv4_address" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            break
        fi
    done

    # 获取IPv6地址
    for service in "${ipv6_services[@]}"; do
        ipv6_address=$(curl -s --max-time 1 "$service")
        if [[ "$ipv6_address" =~ ^[0-9a-fA-F:]+$ ]]; then
            break
        fi
    done
}

# 检查当前服务器是否启用了 IPv4 和 IPv6
check_network_protocols() {
    ip_address

    ipv4_enabled=false
    ipv6_enabled=false

    if [ -n "$ipv4_address" ]; then
        ipv4_enabled=true
    fi
    if [ -n "$ipv6_address" ]; then
        ipv6_enabled=true
    fi
}

display_docker_access() {
    local docker_web_port
    docker_web_port=$(docker inspect "$docker_name" --format '{{ range $p, $conf := .NetworkSettings.Ports }}{{ range $conf }}{{ $p }}:{{ .HostPort }}{{ end }}{{ end }}' | grep -oP '(\d+)$')

    echo "------------------------"
    echo "访问地址:"
    if [ "$ipv4_enabled" = true ]; then
        echo -e "http://$ipv4_address:$docker_web_port"
    fi
    if [ "$ipv6_enabled" = true ]; then
        echo -e "http://[$ipv6_address]:$docker_web_port"
    fi
}

check_dockerapp_status() {
    if docker inspect "$docker_name" &>/dev/null; then
        dockerapp_status="${green}已安装${white}"
    else
        dockerapp_status="${yellow}未安装${white}"
    fi
}

checkport_netools_dep() {
    # 检查可用的命令
    if command -v ss >/dev/null 2>&1; then
        check_command="ss -tuln"
    elif command -v netstat >/dev/null 2>&1; then
        check_command="netstat -tuln"
    else
        _yellow "未找到可用的网络工具（ss或netstat），尝试安装net-tools"
        install net-tools

        if command -v netstat >/dev/null 2>&1; then
            check_command="netstat -tuln"
        else
            _red "安装net-tools失败，请手动检查"
            return 1
        fi
    fi
}    

find_available_port() {
    local start_port=$1
    local end_port=$2
    local port
    local check_command

    checkport_netools_dep

    for port in $(seq $start_port $end_port); do
        if ! eval "$check_command" | grep -q ":$port "; then
            echo "$port"
            return
        fi
    done

    _red "在范围（$start_port-$end_port）内没有找到可用的端口" >&2
    return 1
}

# 检查指定的默认端口是否被占用，若被占用则使用端口跳跃重新赋值
check_available_port() {
    local check_command
    local default_ports=( "$default_port_1" "$default_port_2" "$default_port_3" )
    local docker_ports=( "" "" "" )  # 存储最终可用端口

    checkport_netools_dep

    # 如果Docker容器未运行，检查每个端口
    if ! docker inspect "$docker_name" >/dev/null 2>&1; then
        for i in "${!default_ports[@]}"; do
            default_port=${default_ports[i]}
            # 确保 default_port 不为空
            if [ -n "$default_port" ]; then
                # 检查端口是否被占用
                if eval "$check_command" | grep -q ":$default_port "; then
                    # 端口被占用，查找可用端口
                    docker_ports[i]=$(find_available_port $((30000 + i * 5000)) 50000)  # 每个端口增加5000的步进进行端口跳跃
                    _yellow "默认端口$default_port被占用，端口跳跃为${docker_ports[i]}"
                else
                    docker_ports[i]="$default_port"
                    _yellow "使用默认端口${docker_ports[i]}"
                fi
            fi
        done
    fi

    # 将可用端口赋值给全局变量
    for i in "${!docker_ports[@]}"; do
        eval "docker_port_$((i + 1))=\"${docker_ports[i]}\""
    done
}

manage_dockerapplication() {
    local choice
    check_network_protocols
    while true; do
        clear
        check_dockerapp_status
        # 显示容器名字并且显示容器是否安装
        echo -e "$docker_name $dockerapp_status"
        # 显示容器描述介绍容器功能
        echo "$docker_describe"
        # 显示容器官方链接
        echo "$docker_url"

        # 获取并显示当前端口
        if docker inspect "$docker_name" &>/dev/null; then
            display_docker_access
        fi
        echo "------------------------"
        echo "1. 安装            2. 更新"
        echo "3. 编辑            4. 卸载"
        echo "------------------------"
        echo "0. 返回上一级"
        echo "------------------------"

        echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
        read -r choice

        case $choice in
            1)
                #install_docker
                # 处理安装操作
                [ ! -d "$docker_workdir" ] && mkdir -p "$docker_workdir"
                cd "$docker_workdir"

                if [ -n "$docker_port_1" ]; then
                    # 如果 docker_port_1 已硬性赋值，直接写入配置文件
                    echo "$docker_compose_content" > docker-compose.yml
                else
                    # 如果没有硬性赋值，则进行端口检查和替换
                    check_available_port
                    echo "$docker_compose_content" > docker-compose.yml

                    # 构建并执行Sed命令
                    sed_commands="s#default_port_1#$docker_port_1#g;"
                    [ -n "$docker_port_2" ] && sed_commands+="s#default_port_2#$docker_port_2#g;"
                    [ -n "$docker_port_3" ] && sed_commands+="s#default_port_3#$docker_port_3#g;"
                    [ -n "$random_password" ] && sed_commands+="s#random_password#$random_password#g;"
                    sed -i -e "$sed_commands" docker-compose.yml
                fi

                # 启动容器并执行后续操作
                manage_compose start
                clear
                _green "${docker_name}安装完成"
                display_docker_access
                echo ""

                # 执行相关 Docker 命令
                eval "$docker_exec_command"
                eval "$docker_password"

                # 重置端口变量
                docker_port_1=""
                docker_port_2=""
                docker_port_3=""
                ;;
            2)
                cd "$docker_workdir"

                # 尝试拉取镜像并捕获输出
                pull_output=$(manage_compose pull 2>&1)

                # 输出拉取信息
                echo "$pull_output"

                # 检查退出状态
                if [ $? -eq 0 ]; then
                    shopt -s nocasematch
                    # 检查输出内容
                    if [[ $pull_output == *"Downloaded newer image for"* ]]; then
                        manage_compose start
                        clear
                        _green "$docker_name更新完成"
                        display_docker_access
                        echo ""

                        # 执行相关 Docker 命令
                        eval "$docker_exec_command"
                        eval "$docker_password"
                    elif [[ $pull_output == *"Image is up to date for"* ]]; then
                        _yellow "当前已经是最新版的镜像，无需更新"
                    else
                        _yellow "拉取镜像成功但未检测到更新"
                    fi
                    shopt -u nocasematch
                else
                    _red "拉取镜像失败，请检查错误信息"
                    echo "$pull_output"  # 显示错误信息以供调试
                fi
                ;;
            3)
                cd "$docker_workdir"

                vim docker-compose.yml
                manage_compose start

                if [ "$?" -eq 0 ]; then
                    _green "$docker_name重启成功"
                else
                    _red "$docker_name重启失败"
                fi
                ;;
            4)
                cd "$docker_workdir"
                manage_compose down_all
                [ -d "$docker_workdir" ] && rm -fr "${docker_workdir}"
                _green "${docker_name}应用已卸载"
                break
                ;;
            0)
                break
                ;;
            *)
                _red "无效选项，请重新输入"
                ;;
        esac
        end_of
    done
}

linux_panel() {
    local choice
    while true; do
        clear
        echo "▶ 面板工具"
        echo "------------------------"
        echo "5. AList多存储文件列表程序             6. Ubuntu远程桌面网页版"
        echo "7. 哪吒探针VPS监控面板                 8. QB离线BT磁力下载面板"
        echo "9. Poste.io邮件服务器程序"
        echo "------------------------"
        echo "11. 禅道项目管理软件                   12. 青龙面板定时任务管理平台"
        echo "14. 简单图床图片管理程序"
        echo "15. emby多媒体管理系统                 16. Speedtest测速面板"
        echo "17. AdGuardHome去广告软件              18. Onlyoffice在线办公OFFICE"
        echo "19. 雷池WAF防火墙面板"
        echo "------------------------"
        echo "51. PVE开小鸡面板"
        echo "------------------------"
        echo "0. 返回主菜单"
        echo "------------------------"

        echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
        read -r choice

        case $choice in
            5)
                docker_name="alist"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="一个支持多种存储，支持网页浏览和WebDAV的文件列表程序，由gin和Solidjs驱动"
                docker_url="官网介绍: https://alist.nn.ci/zh/"
                default_port_1=5244
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/alist-docker-compose.yml)
                docker_exec_command="docker exec -it alist ./alist admin random"
                docker_password=""
                manage_dockerapplication
                ;;
            6)
                docker_name="webtop-ubuntu"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="webtop基于Ubuntu的容器，包含官方支持的完整桌面环境，可通过任何现代Web浏览器访问"
                docker_url="官网介绍: https://docs.linuxserver.io/images/docker-webtop/"
                default_port_1=3000
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/webtop-ubuntu-docker-compose.yml)
                docker_exec_command=""
                docker_password=""
                manage_dockerapplication
                ;;
            7)
                local choice
                while true; do
                    clear
                    echo "哪吒监控管理"
                    echo "开源、轻量、易用的服务器监控与运维工具"
                    echo "------------------------"
                    echo "1. 使用           0. 返回上一级"
                    echo "------------------------"
                    
                    echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
                    read -r choice

                    case $choice in
                        1)
                            curl -fsSL -o "nezha.sh" "${github_proxy}raw.githubusercontent.com/naiba/nezha/master/script/install.sh" && chmod +x nezha.sh
                            ./nezha.sh
                            ;;
                        0)
                            break
                            ;;
                        *)
                            _red "无效选项，请重新输入"
                            ;;
                    esac
                    end_of
                done
                ;;
            8)
                docker_name="qbittorrent"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="qbittorrent离线BT磁力下载服务"
                docker_url="官网介绍: https://hub.docker.com/r/linuxserver/qbittorrent"
                default_port_1=8081
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/qbittorrent-docker-compose.yml)
                docker_exec_command="sleep 3"
                docker_password="docker logs qbittorrent"
                manage_dockerapplication
                ;;
            9)
                clear
                install telnet
                docker_name="poste"
                docker_workdir="/data/docker_data/$docker_name"
                while true; do
                    check_dockerapp_status
                    clear
                    echo -e "邮局服务 $dockerapp_status"
                    echo "Poste.io是一个开源的邮件服务器解决方案"
                    echo ""
                    echo "端口检测"
                    if echo "quit" | timeout 3 telnet smtp.qq.com 25 | grep 'Connected'; then
                        echo -e "${green}端口25当前可用${white}"
                    else
                        echo -e "${red}端口25当前不可用${white}"
                    fi
                    echo ""
                    if docker inspect "$docker_name" &>/dev/null; then
                        domain=$(cat $docker_workdir/mail.txt)
                        echo "访问地址:"
                        echo "https://$domain"
                    fi

                    echo "------------------------"
                    echo "1. 安装     2. 更新     3. 卸载"
                    echo "------------------------"
                    echo "0. 返回上一级"
                    echo "------------------------"

                    echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
                    read -r choice

                    case $choice in
                        1)
                            echo -n "请设置邮箱域名，例如mail.google.com:"
                            read -r domain

                            [ ! -d "$docker_workdir" ] && mkdir "$docker_workdir" -p
                            echo "$domain" > "$docker_workdir/mail.txt"
                            cd "$docker_workdir"

                            echo "------------------------"
                            ip_address
                            echo "先解析这些DNS记录"
                            echo "A           mail            $ipv4_address"
                            echo "CNAME       imap            $domain"
                            echo "CNAME       pop             $domain"
                            echo "CNAME       smtp            $domain"
                            echo "MX          @               $domain"
                            echo "TXT         @               v=spf1 mx ~all"
                            echo "TXT         ?               ?"
                            echo ""
                            echo "------------------------"
                            _yellow "按任意键继续"
                            read -n 1 -s -r -p ""

                            install_docker
                            docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/poste-docker-compose.yml)
                            echo "$docker_compose_content" > docker-compose.yml
                            sed -i "s/\${domain}/$domain/g" docker-compose.yml

                            clear
                            echo "poste.io安装完成"
                            echo "------------------------"
                            echo "您可以使用以下地址访问poste.io:"
                            echo "https://$domain"
                            echo ""
                            ;;
                        2)
                            cd "$docker_workdir"
                            manage_compose pull && manage_compose start
                            echo "poste.io更新完成"
                            echo "------------------------"
                            echo "您可以使用以下地址访问poste.io:"
                            echo "https://$domain"
                            ;;
                        3)
                            cd "$docker_workdir"
                            manage_compose down_all
                            [ -d "$docker_workdir" ] && rm -fr "$docker_workdir"
                            _green "Poste卸载完成"
                            ;;
                        0)
                            break
                            ;;
                        *)
                            _red "无效选项，请重新输入"
                            ;;
                    esac
                    end_of
                done
                ;;
            11)
                docker_name="zentao-server"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="禅道是通用的项目管理软件"
                docker_url="官网介绍: https://www.zentao.net/"
                default_port_1=8080
                default_port_2=3306
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/zentao-server-docker-compose.yml)
                docker_exec_command="echo 初始用户名: admin"
                docker_password="echo 初始密码: 123456"
                manage_dockerapplication
                ;;
            12)
                docker_name="qinglong"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="青龙面板是一个定时任务管理平台"
                docker_url="官网介绍: https://github.com/whyour/qinglong"
                default_port_1=5700
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/qinglong-docker-compose.yml)
                docker_exec_command=""
                docker_password=""
                manage_dockerapplication
                ;;
            14)
                docker_name="easyimage"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="简单图床是一个简单的图床程序"
                docker_url="官网介绍: https://github.com/icret/EasyImages2.0"
                default_port_1=8080
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/easyimage-docker-compose.yml)
                docker_exec_command=""
                docker_password=""
                manage_dockerapplication
                ;;
            15)
                docker_name="emby"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="emby是一个主从式架构的媒体服务器软件,可以用来整理服务器上的视频和音频,并将音频和视频流式传输到客户端设备"
                docker_url="官网介绍: https://emby.media/"
                default_port_1=8096
                default_port_2=8920
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/emby-docker-compose.yml)
                docker_exec_command=""
                docker_password=""
                manage_dockerapplication
                ;;
            16)
                docker_name="looking-glass"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="Speedtest测速面板是一个VPS网速测试工具，多项测试功能，还可以实时监控VPS进出站流量"
                docker_url="官网介绍: https://github.com/wikihost-opensource/als"
                default_port_1=8080
                default_port_2=30000
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/looking-glass-docker-compose.yml)
                docker_exec_command=""
                docker_password=""
                manage_dockerapplication
                ;;
            17)
                docker_name="adguardhome"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="AdGuardHome是一款全网广告拦截与反跟踪软件，未来将不止是一个DNS服务器"
                docker_url="官网介绍: https://hub.docker.com/r/adguard/adguardhome"
                default_port_1=3000
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/adguardhome-docker-compose.yml)
                docker_exec_command=""
                docker_password=""
                manage_dockerapplication
                ;;
            18)
                docker_name="onlyoffice"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="onlyoffice是一款开源的在线office工具，太强大了！"
                docker_url="官网介绍: https://www.onlyoffice.com/"
                default_port_1=8080
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/onlyoffice-docker-compose.yml)
                docker_exec_command=""
                docker_password=""
                manage_dockerapplication
                ;;
            19)
                check_network_protocols
                docker_name="safeline-mgt"
                docker_port_1=9443
                while true; do
                    check_dockerapp_status
                    clear
                    echo -e "雷池服务 $dockerapp_status"
                    echo "雷池是长亭科技开发的WAF站点防火墙程序面板，可以反代站点进行自动化防御"

                    if docker inspect "$docker_name" &>/dev/null; then
                    	display_docker_access
                    fi
                    echo ""

                    echo "------------------------"
                    echo "1. 安装           2. 更新           3. 重置密码           4. 卸载"
                    echo "------------------------"
                    echo "0. 返回上一级"
                    echo "------------------------"

                    echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
                    read -r choice

                    case $choice in
                    	1)
                    		install_docker
                    		bash -c "$(curl -fsSLk https://waf-ce.chaitin.cn/release/latest/setup.sh)"
                    		clear
                    		_green "雷池WAF面板已经安装完成"
                    		display_docker_access
                    		docker exec safeline-mgt resetadmin
                    		;;
                    	2)
                    		bash -c "$(curl -fsSLk https://waf-ce.chaitin.cn/release/latest/upgrade.sh)"
                    		docker rmi $(docker images | grep "safeline" | grep "none" | awk '{print $3}')
                    		echo ""
                    		clear
                    		_green "雷池WAF面板已经更新完成"
                    		display_docker_access
                    		;;
                    	3)
                    		docker exec safeline-mgt resetadmin
                    		;;
                    	4)
                    		cd /data/safeline
                    		manage_compose down_all
                    		echo "如果你是默认安装目录那现在项目已经卸载，如果你是自定义安装目录你需要到安装目录下自行执行:"
                    		echo "docker compose down --rmi all --volumes"
                    		;;
                    	0)
                    		break
                    		;;
                    	*)
                    		_red "无效选项，请重新输入"
                    		;;
                    esac
                    end_of
                done
                ;;
            20)
                docker_name="portainer"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="portainer是一个轻量级的docker容器管理面板"
                docker_url="官网介绍: https://www.portainer.io/"
                default_port_1=9000
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/portainer-docker-compose.yml)
                docker_exec_command=""
                docker_password=""
                manage_docker_application
                ;;
            21)
                docker_name="vscode-web"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="VScode是一款强大的在线代码编写工具"
                docker_url="官网介绍: https://github.com/coder/code-server"
                default_port_1=8080
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/vscode-web-docker-compose.yml)
                docker_exec_command="sleep 3"
                docker_password="docker exec vscode-web cat /home/coder/.config/code-server/config.yaml"
                manage_docker_application
                ;;
            51)
                clear
                curl -fsSL -O ${github_proxy}raw.githubusercontent.com/oneclickvirt/pve/main/scripts/install_pve.sh && chmod +x install_pve.sh && bash install_pve.sh
                ;;
            0)
                honeok
                ;;
            *)
                _red "无效选项，请重新输入"
                ;;
        esac
        end_of
    done
}
#################### Docker END ####################

linux_panel