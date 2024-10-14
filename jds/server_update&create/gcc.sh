#!/bin/bash

# ANSI颜色码，用于彩色输出
yellow='\033[1;33m' # 提示信息
red='\033[1;31m'    # 警告信息
green='\033[1;32m'  # 成功信息
cyan='\033[1;36m'   # 特殊信息
white='\033[0m'     # 结束颜色设置

# 软件安装路径
SOFTWARE_DIR="/opt/software"

create_software_dir() {
    if [ ! -d "$SOFTWARE_DIR" ]; then
        mkdir -p "$SOFTWARE_DIR" || { printf "${red}创建安装路径失败。请检查权限或路径。${white}\n"; return 1; }
    fi
}

install_gcc_scl() {
    printf "${yellow}尝试通过SCL安装GCC 9.3.0...${white}\n"
    
    if ! yum install -y centos-release-scl scl-utils-build; then
        printf "${red}安装SCL源失败。${white}\n"
        return 1
    fi

    if ! yum install -y devtoolset-9-gcc devtoolset-9-gcc-c++ devtoolset-9-gcc-gdb-plugin devtoolset-9-gcc-gfortran devtoolset-9-gcc-plugin-devel devtoolset-9-libgccjit devtoolset-9-libgccjit-devel devtoolset-9-libgccjit-docs; then
        printf "${red}安装GCC 9.3.0失败。${white}\n"
        return 1
    fi

    printf "${green}GCC 9.3.0通过SCL成功安装。${white}\n"
    printf "${cyan}使用命令 'scl enable devtoolset-9 bash' 进入SCL环境。${white}\n"
    return 0
}

install_gcc_from_source() {
    create_software_dir
    printf "${yellow}尝试从源代码编译安装GCC 9.3.0...${white}\n"

    cd "$SOFTWARE_DIR" || { printf "${red}无法进入 ${SOFTWARE_DIR} 目录。${white}\n"; return 1; }
    wget https://mirrors.aliyun.com/gnu/gcc/gcc-9.3.0/gcc-9.3.0.tar.gz || { printf "${red}下载GCC 9.3.0源码失败。${white}\n"; return 1; }
    tar xf gcc-9.3.0.tar.gz || { printf "${red}解压GCC 9.3.0源码失败。${white}\n"; return 1; }
    cd gcc-9.3.0 || { printf "${red}无法进入gcc-9.3.0目录。${white}\n"; return 1; }

    ./contrib/download_prerequisites || { printf "${red}下载依赖失败。${white}\n"; return 1; }
    mkdir build
    cd build || { printf "${red}无法进入build目录。${white}\n"; return 1; }

    ../configure --enable-checking=release --enable-language=c,c++ --disable-multilib --prefix=/usr || { printf "${red}配置GCC 9.3.0失败。${white}\n"; return 1; }
    make -j$(nproc) || { printf "${red}编译GCC 9.3.0失败。${white}\n"; return 1; }
    make install || { printf "${red}安装GCC 9.3.0失败。${white}\n"; return 1; }

    printf "${green}GCC 9.3.0成功安装。${white}\n"
    gcc --version
}

install_gcc_check() {
    local method=$1

    case "$method" in
        scl)
            if install_gcc_scl; then
                printf "${cyan}SCL安装成功。${white}\n"
            else
                printf "${yellow}SCL安装失败，尝试从源代码编译安装。${white}\n"
                if install_gcc_from_source; then
                    printf "${cyan}源代码编译安装成功。${white}\n"
                else
                    printf "${red}源代码编译安装也失败。${white}\n"
                fi
            fi
            ;;
        source)
            if install_gcc_from_source; then
                printf "${cyan}源代码编译安装成功。${white}\n"
            else
                printf "${red}源代码编译安装失败。${white}\n"
            fi
            ;;
        *)
            printf "${red}无效的安装方式。${white}\n"
            ;;
    esac
}


main() {
    while true; do
        clear
		clear
		printf "${cyan}=================================${white}\n"
		printf "${cyan}       安装和升级工具菜单       ${white}\n"
		printf "${cyan}=================================${white}\n"
		printf "${cyan}1. 安装GCC 9.3.0（SCL方式）${white}\n"
		printf "${cyan}2. 从源代码编译安装GCC 9.3.0${white}\n"
		printf "${cyan}3. 退出${white}\n"
		printf "${cyan}=================================${white}\n"
		printf "${cyan}请输入选项并按回车: ${white}"
        read -r choice

        case "$choice" in
            1)
                install_gcc_check "scl"
                ;;
            2)
                install_gcc_check "source"
                ;;
            3)
                printf "${green}退出程序。${white}\n"
                exit 0
                ;;
            *)
                printf "${red}无效的选项，请重新选择。${white}\n"
                ;;
        esac

        printf "${cyan}按任意键继续.${white}\n"
        read -n 1 -s -r -p ""
    done
}

main

