#!/bin/bash
# Author: honeok

yellow='\033[1;33m'       # 黄色
red='\033[1;31m'          # 红色
green='\033[1;32m'        # 绿色
white='\033[0m'           # 白色

_yellow() { echo -e ${yellow}$@${white}; }
_red() { echo -e ${red}$@${white}; }
_green() { echo -e ${green}$@${white}; }

if [ "$(id -u)" -ne 0 ]; then
	_red "脚本必须以root用户运行"
	exit 1
fi

if ! grep -q "Ubuntu" /etc/os-release; then
	exit 1
fi

current_version=$(gcc -dumpversion 2>/dev/null)

if [ -z "$current_version" ]; then
	_yellow "GCC未安装,正在安装GCC11.x"
else
	_green "当前GCC版本: $current_version"
fi

# 获取当前安装的GCC版本包的确切名称
gcc_packages=$(dpkg -l | grep '^ii' | grep 'gcc-' | awk '{print $2}')

# 确定需要卸载的包
remove_packages=""

if [ -n "$current_version" ]; then
	# 提取主版本号
	major_version=$(echo $current_version | cut -d. -f1)

	# 处理当前版本大于11.x的情况
	if [ "$major_version" -gt 11 ]; then
		_yellow "当前GCC版本高于11.x,正在准备卸载当前版本的GCC"
		for package in $gcc_packages; do
			if [[ "$package" == gcc-${major_version}* || "$package" == gcc-${major_version}-base* ]]; then
				remove_packages+="$package "
			fi
		done

		if [ -n "$remove_packages" ]; then
			_yellow "正在卸载以下包: $remove_packages"
			apt remove --purge -y $remove_packages
		else
			_yellow "未找到需要卸载的GCC包"
		fi
	fi
fi

# 检查并安装 add-apt-repository
if ! command -v add-apt-repository &> /dev/null; then
	apt install -y software-properties-common
fi

# 添加 Ubuntu Toolchain PPA,以获取 GCC 11.x
add-apt-repository -y ppa:ubuntu-toolchain-r/test
apt update

# 安装 GCC 11.x
_yellow "正在安装GCC 11.x"
apt install -y gcc-11

# 设置 GCC 11.x 为默认版本
_yellow "正在设置 GCC11.x为默认版本"
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 100

# 验证安装结果
gcc_version=$(gcc -dumpversion)
_yellow "GCC版本已设置为: $gcc_version"

# 确认GCC11.x是默认版本
_green "GCC默认版本确认:"
gcc --version