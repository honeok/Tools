import subprocess
import json
import urllib.request
import time
import os
import logging

# Bark API 回调接口
bark_url = "https://api.honeok.de/to73XJ2pqf6HfHMg8WQ7n1/"
title = "P8_CN_测试服务器告警"

# 告警记录文件
alert_file = "/root/alert_time.txt"

# 告警间隔时间（20分钟）
alert_interval = 20 * 60  # 20分钟

def load_last_alert_time():
    """从文件中加载上次告警时间"""
    if os.path.exists(alert_file):
        with open(alert_file, "r") as f:
            try:
                return float(f.read().strip())
            except ValueError:
                return 0
    return 0

def save_last_alert_time(timestamp):
    """保存当前时间为最后一次告警时间"""
    with open(alert_file, "w") as f:
        f.write(str(timestamp))

def run_ps_command(sort_by, threshold):
    """执行 ps 命令获取进程信息并检查是否超出阈值"""
    result = subprocess.run(
        ["ps", "-eo", "pid,comm,%mem,%cpu", f"--sort=-{sort_by}"],
        stdout=subprocess.PIPE,
        text=True
    )
    output = result.stdout.strip().split("\n")

    # 跳过标题行
    alerts = []
    for line in output[1:]:
        fields = line.split()
        if len(fields) < 4:
            continue  # 跳过不完整的行
        try:
            pid = fields[0]
            mem_usage = fields[-2] if sort_by == "%mem" else fields[-1]
            cpu_usage = fields[-1] if sort_by == "%cpu" else fields[-1]
            name = " ".join(fields[1:-2]) if sort_by == "%mem" else " ".join(fields[1:-1])

            usage = float(mem_usage.replace(',', '.')) if sort_by == "%mem" else float(cpu_usage.replace(',', '.'))
            if usage > threshold:
                alert_message = f"进程: {name} (PID: {pid}) 占用{'内存' if sort_by == '%mem' else 'CPU'}: {usage:.1f}%"
                alerts.append(alert_message)
        except ValueError as e:
            logging.error(f"解析错误: {e}，行内容: {line}")
    return "\n".join(alerts)

# 设置日志记录
logging.basicConfig(level=logging.ERROR)

# 获取内存和 CPU 占用警报
memory_alert = run_ps_command("%mem", 30)
cpu_alert = run_ps_command("%cpu", 30)

# 合并警报信息
alert_message = ""
if memory_alert:
    alert_message += f"内存占用警报:\n{memory_alert}\n"

if cpu_alert:
    alert_message += f"CPU占用警报:\n{cpu_alert}\n"

# 发送 Bark 通知的逻辑
current_time = time.time()
last_alert_time = load_last_alert_time()

if alert_message and (current_time - last_alert_time) > alert_interval:
    data = {
        "title": title,
        "body": alert_message
    }
    headers = {
        "Content-Type": "application/json"
    }
    try:
        req = urllib.request.Request(bark_url, data=json.dumps(data).encode(), headers=headers)
        with urllib.request.urlopen(req) as response:
            response.read()
    except Exception as e:
        logging.error(f"发送通知失败: {e}")
    save_last_alert_time(current_time)
