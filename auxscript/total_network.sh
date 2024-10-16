#!/bin/bash

# 函数：将字节数转换为 GB
bytes_to_gb() {
    local bytes=$1
    # 使用整数除法计算 GB
    local gb=$((bytes / 1024 / 1024 / 1024))
    # 计算余数以获取小数部分
    local remainder=$((bytes % (1024 * 1024 * 1024)))
    local fraction=$((remainder * 100 / (1024 * 1024 * 1024)))
    echo "$gb.$fraction GB"
}

# 初始化总接收字节数和总发送字节数
total_recv_bytes=0
total_sent_bytes=0

# 遍历 /proc/net/dev 文件中的每一行
while read -r line; do
    # 提取接口名（接口名后面是冒号）
    interface=$(echo "$line" | awk -F: '{print $1}' | xargs)
    
    # 过滤掉不需要的行（只处理接口名）
    if [ -n "$interface" ] && [ "$interface" != "Inter-| Receive | Transmit" ] && [ "$interface" != "face |bytes packets errs drop fifo frame compressed multicast|bytes packets errs drop fifo colls carrier compressed" ]; then
        # 提取接收和发送字节数
        stats=$(echo "$line" | awk -F: '{print $2}' | xargs)
        recv_bytes=$(echo "$stats" | awk '{print $1}')
        sent_bytes=$(echo "$stats" | awk '{print $9}')

        # 累加接收和发送字节数
        total_recv_bytes=$((total_recv_bytes + recv_bytes))
        total_sent_bytes=$((total_sent_bytes + sent_bytes))
    fi
done < /proc/net/dev

# 输出总接收和发送字节数（以 GB 为单位）
echo "总接收数据量: $(bytes_to_gb $total_recv_bytes)"
echo "总发送数据量: $(bytes_to_gb $total_sent_bytes)"