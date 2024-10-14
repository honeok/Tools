#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2024 honeok
# Author: honeok yihaohey@gmail.com
# Blog: https://www.honeok.com
#
# Usage:
#   ./setup.sh [uninstall]

set -o errexit
set -o pipefail

yellow='\033[1;33m'       # 黄色
red='\033[1;31m'          # 红色
green='\033[1;32m'        # 绿色
purple='\033[1;35m'       # 紫色
white='\033[0m'           # 白色

_yellow() { echo -e ${yellow}$@${white}; }
_red() { echo -e ${red}$@${white}; }
_green() { echo -e ${green}$@${white}; }

##############################
# 定义安装目录和安装程序
install_dir="/data/conda3"
installer="Miniconda3-py39_24.3.0-0-Linux-x86_64.sh"
apiserver_dir="/data/bi/apiserver"
##############################

print_logo(){
    echo -e "${purple}\
       _     _        _____                      
      | |   | |      / ____|                     
      | | __| |___  | |  __  __ _ _ __ ___   ___ 
  _   | |/ _\` / __| | | |_ |/ _\` | '_ \` _ \ / _ \\
 | |__| | (_| \__ \ | |__| | (_| | | | | | |  __/
  \____/ \__,_|___/  \_____|\\__,_|_| |_| |_|\___|${white}"
}
print_logo

# 检查是否具有足够的权限
#if [ "$(id -u)" -ne 0 ]; then
#	_red "该脚本需要以root权限运行,请使用root用户执行"
#	exit 1
#fi

remove_condaenv_init() {
	grep -q '# >>> conda initialize >>>' ~/.bashrc && \
		sed -i '/# >>> conda initialize >>>/,/# <<< conda initialize <<<$/d' ~/.bashrc && \
		_green "已删除.bashrc中的Conda初始化配置块"

	grep -q '# commented out by conda initialize' ~/.bashrc && \
		sed -i '/# commented out by conda initialize/d' ~/.bashrc && \
		_green "已删除.bashrc中的Conda路径配置"
}

# 检查是否为卸载操作
if [[ "${1:-}" == "uninstall" ]]; then
	_yellow "卸载Miniconda和相关配置"

	# 删除Miniconda安装目录
	if [ -d "$install_dir" ]; then
		_yellow "删除Miniconda安装目录$install_dir"
		rm -fr "$install_dir" || { _red "删除Miniconda目录失败"; exit 1; }
	else
		_red "$install_dir不存在,跳过删除"
	fi

	# 删除环境变量
	remove_condaenv_init

	# 检查并删除虚拟环境
	if conda info --envs | grep -q 'py39'; then
		_yellow "删除Conda虚拟环境py39"
		conda remove -n py39 --all --yes || { _red "删除py3.9虚拟环境失败"; exit 1; }
	else
		_red "未找到py39虚拟环境,本次跳过"
	fi

	_green "卸载成功"
	exit 0
fi

# 检查Conda是否已安装
if command -v conda >/dev/null 2>&1; then
	_yellow "Conda已经安装在系统中,跳过安装步骤"
	exit 0
fi

# 根据IP地址确定下载链接
if [[ "$(curl -s --connect-timeout 5 ipinfo.io/country)" == "CN" ]]; then
	installer_url="https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/$installer"
	pypi_index_url="https://pypi.tuna.tsinghua.edu.cn/simple"
else
	installer_url="https://repo.anaconda.com/miniconda/$installer"
	pypi_index_url="https://pypi.org/simple"
fi

# 下载和安装Miniconda
if [ ! -f "$installer" ]; then
	_yellow "下载Miniconda安装程序"
	curl -sL "$installer_url" -o "$installer" || { _red "下载安装程序失败"; exit 1; }
fi

_yellow "安装Miniconda到$install_dir"
bash "$installer" -bfp "$install_dir" || { _red "Miniconda安装失败"; exit 1; }

# 删除安装脚本
rm -f "$installer"

# 配置全局环境变量
if ! grep -q "$install_dir/bin" ~/.bashrc; then
	_yellow "在.bashrc中添加Conda的PATH"
	echo "export PATH=\"$install_dir/bin:\$PATH\"" >> ~/.bashrc
fi

source ~/.bashrc

# 验证Miniconda安装
if ! conda --version >/dev/null 2>&1; then
	_red "Conda安装错误"
	# 删除安装目录和环境变量文件
	[ -d "$install_dir" ] && rm -fr "$install_dir"
	remove_condaenv_init
	source ~/.bashrc
	exit 1
fi

_yellow "更新Conda并安装Python3.9"
conda install -y python=3.9 || { _red "安装Python3.9失败"; exit 1; }
conda update -y conda || { _red "更新Conda失败"; exit 1; }
conda clean --all --yes || { _red "清理Conda缓存失败"; exit 1; }

_yellow "创建python39虚拟环境"
conda create -n py39 python=3.9 --yes || { _red "创建python39环境失败"; exit 1; }
source "${install_dir}/etc/profile.d/conda.sh" || { _red "加载Conda配置失败"; exit 1; }
conda init || { _red "初始化Conda失败"; exit 1; }
conda activate py39 || { _red "激活py39环境失败"; exit 1; }

if [ ! -d "$apiserver_dir" ]; then
	_red "$apiserver_dir目录不存在请检查路径"
	# 删除安装目录和环境变量文件
	[ -d "$install_dir" ] && rm -fr "$install_dir"
	remove_condaenv_init
	source ~/.bashrc
	exit 1
fi

_yellow "安装所需的Python包"
cd "$apiserver_dir"
python -m pip install -i "$pypi_index_url" --trusted-host $(echo $pypi_index_url | awk -F/ '{print $3}') -r requirements.txt || { _red "从requirements.txt安装包失败"; exit 1; }

_yellow "初始化数据库"
python manager.py initdb || { _red "初始化数据库失败"; exit 1; }

aerich init -t aerich_env.TORTOISE_ORM
aerich init-db

# 安装完成
_green "安装成功"
exit 0