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

check_available_port() {
    local check_command
    local default_ports=( "$default_port_1" "$default_port_2" "$default_port_3" )
    local docker_ports=( "" "" "" )  # 存储最终可用端口
    local used_ports=()  # 存储已使用的端口

    # 确定可用的端口检测工具
    if command -v netstat >/dev/null 2>&1; then
        check_command="netstat -tuln"
    elif command -v ss >/dev/null 2>&1; then
        check_command="ss -tuln"
    else
        _yellow "未检测到可用的端口检测工具，正在安装net-tools"
        install net-tools
        if command -v netstat >/dev/null 2>&1; then
            check_command="netstat -tuln"
        else
            _red "安装失败且默认网络工具无法使用，请自行检查"
            return 1
        fi
    fi

    # 如果Docker容器未运行，检查每个端口
    if ! docker inspect "$docker_name" >/dev/null 2>&1; then
        for i in "${!default_ports[@]}"; do
            local default_port="${default_ports[i]}"

            # 确保default_port不为空
            if [ -n "$default_port" ]; then
                # 检查端口是否被占用
                if $check_command | grep -q ":$default_port "; then
                    # 端口被占用，查找可用端口
                    local found_port=false

                    for port in $(seq "$default_port" 50000); do
                        if ! $check_command | grep -q ":$port " && ! [[ " ${default_ports[@]} " =~ " $port " ]] && ! [[ " ${used_ports[@]} " =~ " $port " ]]; then
                            docker_ports[i]="$port"
                            used_ports+=("$port")  # 将新端口添加到已使用的端口列表
                            _yellow "默认端口${default_port}被占用，端口跳跃为${port}"
                            found_port=true
                            break  # 找到可用端口后退出循环
                        fi
                    done

                    # 如果没有找到可用端口，输出错误信息
                    if [ "$found_port" = false ]; then
                        _red "没有找到可用的端口" >&2
                        return 1
                    fi
                else
                    docker_ports[i]="$default_port"
                    used_ports+=("$default_port")  # 将默认端口添加到已使用的端口列表
                    _yellow "使用默认端口${docker_ports[i]}"
                fi
            fi
        done
    fi

    # 赋值变量
    docker_port_1="${docker_ports[0]}"
    docker_port_2="${docker_ports[1]}"
    docker_port_3="${docker_ports[2]}"
}

manage_panelapp() {
    local choice
    while true; do
        clear
        if [ -d "$path" ]; then
            panelapp_status="${green}已安装${white}"
        else
            panelapp_status="${yellow}未安装${white}"
        fi
        echo -e "$panelname $panelapp_status"
        echo "${panelname}是一款时下流行且强大的运维管理面板"
        echo "官网介绍: $panelurl "

        echo ""
        echo "------------------------"
        echo "1. 安装            2. 管理            3. 卸载"
        echo "------------------------"
        echo "0. 返回上一级"
        echo "------------------------"

        echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
        read -r choice

        case $choice in
            1)
                iptables_open
                install wget
                if grep -q 'Alpine' /etc/issue; then
                    $ubuntu_command
                    $ubuntu_command2
                elif command -v dnf &>/dev/null; then
                    $centos_command
                    $centos_command2
                elif grep -qi 'Ubuntu' /etc/os-release; then
                    $ubuntu_command
                    $ubuntu_command2
                elif grep -qi 'Debian' /etc/os-release; then
                    $ubuntu_command
                    $ubuntu_command2
                else
                    _red "不支持的系统"
                fi
                ;;
            2)
                [ -n "$feature1" ] && $feature1
                [ -n "$feature1_1" ] && $feature1_1
                ;;
            3)
                [ -n "$feature2" ] && $feature2
                [ -n "$feature2_1" ] && $feature2_1
                [ -n "$feature2_2" ] && $feature2_2
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

manage_dockerapp() {
    local choice
    check_network_protocols
    while true; do
        clear
        check_dockerapp_status
        echo -e "$docker_name $dockerapp_status"
        echo "$docker_describe"
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
                [ ! -d "$docker_workdir" ] && mkdir -p "$docker_workdir"
                cd "$docker_workdir"

                # 判断$docker_port_1是否已硬性赋值
                if [ ! -z "$docker_port_1" ]; then
                    echo "$docker_compose_content" > docker-compose.yml
                else
                    # 只有在端口未硬性赋值时才进行端口检查和替换
                    check_available_port
                    echo "$docker_compose_content" > docker-compose.yml
                    # 构建并执行Sed命令替换端口
                    sed_commands="s#default_port_1#$docker_port_1#g;"
                    [ -n "$docker_port_2" ] && sed_commands+="s#default_port_2#$docker_port_2#g;"
                    [ -n "$docker_port_3" ] && sed_commands+="s#default_port_3#$docker_port_3#g;"
                    [ -n "$random_password" ] && sed_commands+="s#random_password#$random_password#g;"
                    sed -i -e "$sed_commands" docker-compose.yml
                fi

                manage_compose start
                clear
                _green "${docker_name}安装完成"
                display_docker_access
                echo ""

                # 前置变量非空则执行
                [ -n "$docker_exec_command" ] && $docker_exec_command
                [ -n "$docker_password" ] && $docker_password

                # 清空端口变量
                docker_port_1=""
                docker_port_2=""
                docker_port_3=""
                ;;
            2)
                cd "$docker_workdir"

                # 尝试拉取镜像并捕获输出
                pull_output=$(manage_compose pull 2>&1)
                echo "$pull_output"  # 输出拉取信息

                # 检查退出状态
                if [ $? -eq 0 ]; then
                    # 启用不区分大小写的匹配
                    shopt -s nocasematch

                    # 检查输出内容
                    case "$pull_output" in
                        *"downloaded newer image for"*)
                            manage_compose start
                            clear
                            _green "$docker_name更新完成"
                            display_docker_access
                            echo ""
                            # 前置变量非空则执行
                            [ -n "$docker_exec_command" ] && $docker_exec_command
                            [ -n "$docker_password" ] && $docker_password
                            ;;
                        *"image is up to date for"*)
                            _yellow "当前已经是最新版的镜像，无需更新"
                            ;;
                        *)
                            _yellow "拉取镜像成功，但未检测到更新"
                            ;;
                    esac

                    # 关闭不区分大小写的匹配
                    shopt -u nocasematch
                else
                    _red "拉取镜像失败，请检查错误信息"
                    echo "$pull_output"  # 显示错误信息以供调试
                fi
                ;;
            3)
                cd "$docker_workdir"

                if [ -f "docker-compose.yml" ]; then
                    command -v vim >/dev/null 2>&1 && { vim docker-compose.yml; } || { vi docker-compose.yml; }

                    manage_compose start

                    # 检查重启状态
                    [ "$?" -eq 0 ] && _green "$docker_name重启成功" || _red "$docker_name重启失败"
                else
                    _red "docker-compose.yml文件不存在，请检查工作目录"
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
        echo "1. 宝塔面板官方版                      2. aaPanel宝塔国际版"
        echo "3. 1Panel新一代管理面板                4. NginxProxyManager可视化面板"
        echo "5. AList多存储文件列表程序             6. Ubuntu远程桌面网页版"
        echo "7. 哪吒探针VPS监控面板                 8. QB离线BT磁力下载面板"
        echo "9. Poste.io邮件服务器程序"
        echo "------------------------"
        echo "11. 禅道项目管理软件                   12. 青龙面板定时任务管理平台"
        echo "14. 简单图床图片管理程序"
        echo "15. emby多媒体管理系统                 16. Speedtest测速面板"
        echo "17. AdGuardHome去广告软件              18. Onlyoffice在线办公OFFICE"
        echo "19. 雷池WAF防火墙面板                  20. Portainer容器管理面板"
        echo "------------------------"
        echo "21. VScode网页版                       22. UptimeKuma监控工具"
        echo "23. Memos网页备忘录                    24. Webtop远程桌面网页版"
        echo "25. Nextcloud网盘                      26. QD Today定时任务管理框架"
        echo "27. Dockge容器堆栈管理面板             28. LibreSpeed测速工具"
        echo "29. Searxng聚合搜索站                  30. PhotoPrism私有相册系统"
        echo "------------------------"
        echo "31. StirlingPDF工具大全                32. Drawio免费的在线图表软件"
        echo "33. Sun Panel导航面板                  34. Pingvin Share文件分享平台"
        echo "35. 极简朋友圈                         36. LobeChatAI聊天聚合网站"
        echo "37. MyIP工具箱                         38. 小雅Alist全家桶"
        echo "39. Bililive直播录制工具                40.  Webssh网页版SSH连接工具"
        echo "41. It-tools工具箱"
        echo "------------------------"
        echo "51. PVE开小鸡面板"
        echo "------------------------"
        echo "0. 返回主菜单"
        echo "------------------------"

        echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
        read -r choice

        case $choice in
            1)
                path="/www/server/panel"
                panelname="宝塔面板"

                feature1="bt"
                feature1_1=""
                feature2="curl -o bt-uninstall.sh http://download.bt.cn/install/bt-uninstall.sh > /dev/null 2>&1 && chmod +x bt-uninstall.sh && ./bt-uninstall.sh"
                feature2_1="chmod +x bt-uninstall.sh"
                feature2_2="./bt-uninstall.sh"

                panelurl="https://www.bt.cn/new/index.html"

                centos_command="wget -O install.sh https://download.bt.cn/install/install_6.0.sh"
                centos_command2="sh install.sh ed8484bec"

                ubuntu_command="wget -O install.sh https://download.bt.cn/install/install-ubuntu_6.0.sh"
                ubuntu_command2="bash install.sh ed8484bec"

                manage_panelapp
                ;;
            2)
                path="/www/server/panel"
                panelname="aapanel"

                feature1="bt"
                feature1_1=""
                feature2="curl -o bt-uninstall.sh http://download.bt.cn/install/bt-uninstall.sh > /dev/null 2>&1 && chmod +x bt-uninstall.sh && ./bt-uninstall.sh"
                feature2_1="chmod +x bt-uninstall.sh"
                feature2_2="./bt-uninstall.sh"

                panelurl="https://www.aapanel.com/new/index.html"

                centos_command="wget -O install.sh http://www.aapanel.com/script/install_6.0_en.sh"
                centos_command2="bash install.sh aapanel"

                ubuntu_command="wget -O install.sh http://www.aapanel.com/script/install-ubuntu_6.0_en.sh"
                ubuntu_command2="bash install.sh aapanel"

                manage_panelapp
                ;;
            3)
                path="command -v 1pctl &> /dev/null"
                panelname="1Panel"

                feature1="1pctl user-info"
                feature1_1="1pctl update password"
                feature2="1pctl uninstall"
                feature2_1=""
                feature2_2=""

                panelurl="https://1panel.cn/"

                centos_command="curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o quick_start.sh"
                centos_command2="sh quick_start.sh"

                ubuntu_command="curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o quick_start.sh"
                ubuntu_command2="bash quick_start.sh"

                manage_panelapp
                ;;
            4)
                docker_name="npm"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="如果您已经安装了其他面板工具或者LDNMP建站环境，建议先卸载，再安装npm！"
                docker_url="官网介绍: https://nginxproxymanager.com/"
                docker_port_1=81

                if ! docker inspect "$docker_name" >/dev/null 2>&1; then
                    while true;do
                        echo "------------------------"
                        echo "1. 完整安装npm，基于mariadb（默认）"
                        echo "2. 精简安装npm，基于SQLlite"
                        echo "------------------------"
                        echo "0. 返回上一级"
                        echo "------------------------"
                        echo -n -e "${yellow}请输入选项并按回车键确认（回车使用默认值：完整安装）:${white}"

                        # 重置choice变量
                        choice=""
                        read -r choice

                        case $choice in
                            1|"")
                                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/npm/docker-compose-latest.yml)
                                break
                                ;;
                            2)
                                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/docker_app/npm-docker-compose.yml)
                                break
                                ;;
                            0)
                                linux_panel # 返回面板管理界面
                                ;;
                            *)
                                _red "无效选项，请重新输入"
                                ;;
                        esac
                    done
                fi

                docker_exec_command="echo 初始用户名: admin@example.com"
                docker_password="echo 初始密码: changeme"
                manage_dockerapp
                ;;
            5)
                docker_name="alist"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="一个支持多种存储，支持网页浏览和WebDAV的文件列表程序，由gin和Solidjs驱动"
                docker_url="官网介绍: https://alist.nn.ci/zh/"
                default_port_1=5244
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/alist-docker-compose.yml)
                docker_exec_command="docker exec -it alist ./alist admin random"
                docker_password=""
                manage_dockerapp
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
                manage_dockerapp
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
                            cd ~
                            [ ! -f ./nezha.sh ] && curl -fsSL -o "nezha.sh" "${github_proxy}raw.githubusercontent.com/naiba/nezha/master/script/install.sh" && chmod +x nezha.sh && ./nezha.sh || { chmod +x nezha.sh && ./nezha.sh; }
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
                manage_dockerapp
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
                    echo "Poste.io 是一个开源的邮件服务器解决方案"
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
                    echo "1. 安装           2. 更新           3. 卸载"
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
                            echo "A           mail          $ipv4_address"
                            echo "CNAME       imap          $domain"
                            echo "CNAME       pop           $domain"
                            echo "CNAME       smtp          $domain"
                            echo "MX          @             $domain"
                            echo "TXT         @             v=spf1 mx ~all"
                            echo "TXT         ?             ?"
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
                manage_dockerapp
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
                manage_dockerapp
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
                manage_dockerapp
                ;;
            15)
                docker_name="emby"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="emby是一个主从式架构的媒体服务器软件，可以用来整理服务器上的视频和音频，并将音频和视频流式传输到客户端设备"
                docker_url="官网介绍: https://emby.media/"
                default_port_1=8096
                default_port_2=8920
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/emby-docker-compose.yml)
                docker_exec_command=""
                docker_password=""
                manage_dockerapp
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
                manage_dockerapp
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
                manage_dockerapp
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
                manage_dockerapp
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
                manage_dockerapp
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
                manage_dockerapp
                ;;
            22)
                docker_name="uptimekuma"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="uptimekuma易于使用的自托管监控工具"
                docker_url="官网介绍: https://github.com/louislam/uptime-kuma"
                default_port_1=3001
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/uptimekuma-docker-compose.yml)
                docker_exec_command=""
                docker_password=""
                manage_dockerapp
                ;;
            23)
                docker_name="memeos"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="Memos是一款轻量级，自托管的备忘录中心"
                docker_url="官网介绍: https://github.com/usememos/memos"
                default_port_1=5230
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/memeos-docker-compose.yml)
                docker_exec_command=""
                docker_password=""
                manage_dockerapp
                ;;
            24)
                docker_name="webtop"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="webtop基于Alpine、Ubuntu、Fedora和Arch的容器，包含官方支持的完整桌面环境，可通过任何现代Web浏览器访问"
                docker_url="官网介绍: https://docs.linuxserver.io/images/docker-webtop/"
                default_port_1=3000
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/webtop-docker-compose.yml)
                docker_exec_command=""
                docker_password=""
                manage_dockerapp
                ;;
            25)
                docker_name="nextcloud"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="Nextcloud拥有超过400,000个部署，是您可以下载的最受欢迎的本地内容协作平台"
                docker_url="官网介绍: https://nextcloud.com/"
                default_port_1=8080
                random_password=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c16)
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/nextcloud-simple-docker-compose.yml)
                docker_exec_command="echo 账号: nextcloud  密码: $random_password"
                docker_password=""
                manage_dockerapp
                ;;
            26)
                docker_name="qd"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="QD-Today是一个HTTP请求定时任务自动执行框架"
                docker_url="官网介绍: https://qd-today.github.io/qd/zh_CN/"
                default_port_1=8080
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/qd-docker-compose.yml)
                docker_exec_command=""
                docker_password=""
                manage_dockerapp
                ;;
            27)
                docker_name="dockge"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="dockge是一个可视化的docker-compose容器管理面板"
                docker_url="官网介绍: https://github.com/louislam/dockge"
                default_port_1=5001
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/dockge-docker-compose.yml)
                docker_exec_command=""
                docker_password=""
                manage_dockerapp
                ;;
            28)
                docker_name="speedtest"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="speedtest是用Javascript实现的轻量级速度测试工具，即开即用"
                docker_url="官网介绍: https://github.com/librespeed/speedtest"
                default_port_1=8080
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/speedtest-docker-compose.yml)
                docker_exec_command=""
                docker_password=""
                manage_dockerapp
                ;;
            29)
                docker_name="searxng"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="searxng是一个私有且隐私的搜索引擎站点"
                docker_url="官网介绍: https://hub.docker.com/r/alandoyle/searxng"
                default_port_1=8080
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/searxng-docker-compose.yml)
                docker_exec_command=""
                docker_password=""
                manage_dockerapp
                ;;
            30)
                docker_name="photoprism"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="photoprism非常强大的私有相册系统"
                docker_url="官网介绍: https://www.photoprism.app/"
                default_port_1=2342
                random_password=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c16)
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/photoprism-docker-compose.yml)
                docker_exec_command="echo 账号: admin  密码: $random_password"
                docker_password=""
                manage_dockerapp
                ;;
            31)
                docker_name="s-pdf"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="这是一个强大的本地托管基于Web的PDF操作工具使用docker，允许您对PDF文件执行各种操作，例如拆分合并、转换、重新组织、添加图像、旋转、压缩等"
                docker_url="官网介绍: https://github.com/Stirling-Tools/Stirling-PDF"
                default_port_1=8080
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/s-pdf-docker-compose.yml)
                docker_exec_command=""
                docker_password=""
                manage_dockerapp
                ;;
            32)
                docker_name="drawio"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="这是一个强大图表绘制软件，思维导图、拓扑图、流程图、都能画"
                docker_url="官网介绍: https://www.drawio.com/"
                default_port_1=8080
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/drawio-docker-compose.yml)
                docker_exec_command=""
                docker_password=""
                manage_dockerapp
                ;;
            33)
                docker_name="sun-panel"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="Sun-Panel服务器，NAS导航面板、Homepage、浏览器首页"
                docker_url="官网介绍: https://doc.sun-panel.top/zh_cn/"
                default_port_1=3002
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/sun-panel-docker-compose.yml)
                docker_exec_command="echo 账号: admin@sun.cc  密码: 12345678"
                docker_password=""
                manage_dockerapp
                ;;
            34)
                docker_name="pingvin-share"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="Pingvin Share是一个可自建的文件分享平台，是WeTransfer的一个替代品"
                docker_url="官网介绍: https://github.com/stonith404/pingvin-share"
                default_port_1=3000
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/pingvin-share-docker-compose.yml)
                docker_exec_command=""
                docker_password=""
                manage_dockerapp
                ;;
            35)
                docker_name="moments"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="极简朋友圈，高仿微信朋友圈，记录你的美好生活"
                docker_url="官网介绍: https://github.com/kingwrcy/moments?tab=readme-ov-file"
                default_port_1=3000
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/moments-docker-compose.yml)
                docker_exec_command="echo 账号: admin  密码: a123456"
                docker_password=""
                manage_dockerapp
                ;;
            36)
                docker_name="lobe-chat"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="LobeChat聚合市面上主流的AI大模型，ChatGPT/Claude/Gemini/Groq/Ollama"
                docker_url="官网介绍: https://github.com/lobehub/lobe-chat"
                default_port_1=3210
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/lobe-chat-docker-compose.yml)
                docker_exec_command=""
                docker_password=""
                manage_dockerapp
                ;;
            37)
                docker_name="myip"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="是一个多功能IP工具箱，可以查看自己IP信息及连通性，用网页面板呈现"
                docker_url="官网介绍: https://github.com/jason5ng32/MyIP/blob/main/README_ZH.md"
                default_port_1=18966
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/myip-docker-compose.yml)
                docker_exec_command=""
                docker_password=""
                manage_dockerapp
                ;;
            38)
                clear
                install_docker
                bash -c "$(curl --insecure -fsSL https://ddsrem.com/xiaoya_install.sh)"
                ;;
            39)
                docker_name="bililive"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="Bililive-go是一个支持多种直播平台的直播录制工具"
                docker_url="官网介绍: https://github.com/hr3lxphr6j/bililive-go"
                default_port_1=8080

                if [ ! -d "$docker_workdir" ]; then
                    mkdir -p "$docker_workdir" > /dev/null 2>&1
                    wget -qO "$docker_workdir/config.yml" "${github_proxy}raw.githubusercontent.com/hr3lxphr6j/bililive-go/master/config.yml"
                fi

                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/bililive-docker-compose.yml)
                docker_exec_command=""
                docker_password=""
                manage_dockerapp
                ;;
            40)
                docker_name="webssh"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="简易在线SSH和sftp工具，可在线敲命令和上传下载文件"
                docker_url="官网介绍: https://github.com/Jrohy/webssh"
                default_port_1=5032
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/webssh-docker-compose.yml)
                docker_exec_command=""
                docker_password=""
                manage_dockerapp
                ;;
            41)
                docker_name="it-tools"
                docker_workdir="/data/docker_data/$docker_name"
                docker_describe="为方便开发人员提供的在线工具"
                docker_url="官网介绍: https://github.com/CorentinTh/it-tools"
                default_port_1=8080
                docker_compose_content=$(curl -fsSL ${github_proxy}raw.githubusercontent.com/honeok/conf/main/dockerapp/it-tools-docker-compose.yml)
                docker_exec_command=""
                docker_password=""
                manage_dockerapp
                ;;
            51)
                clear
                curl -fsSL -o "install_pve.sh" ${github_proxy}https://raw.githubusercontent.com/oneclickvirt/pve/main/scripts/install_pve.sh && chmod +x install_pve.sh && bash install_pve.sh
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


linux_panel