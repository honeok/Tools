import subprocess
import json
import urllib.request
from datetime import datetime, timedelta
import time

# 配置部分
BARK_API_URL = "https://api.honeok.de/to73XJ2pqf6HfHMg8WQ7n1/"
TITLE = "天气警报"
DISTRICTS = ['武侯区', '锦江区', '青羊区', '金牛区', '成华区', '龙泉驿区', '郫都区']
CHECK_INTERVAL = 60  # 每隔 60 秒检查一次时间
CITY = 'Chengdu'  # 替换为你想查询的城市名称

def get_weather(district):
    """通过 Shell 命令获取特定区的天气信息"""
    try:
        result = subprocess.run(
            ['curl', '-s', f'wttr.in/{district}?format=%t,%h,%w,%c,%p'],
            stdout=subprocess.PIPE,
            text=True
        )
        weather_info = result.stdout.strip()
        
        if weather_info:
            temperature, humidity, wind, weather, precipitation = weather_info.split(',')
            # 处理降雨量
            if 'mm' in precipitation:
                precipitation_value = float(precipitation.replace('mm', ''))
            else:
                precipitation_value = float(precipitation.replace('%', '')) / 100.0  # 处理百分比情况

            alert_message = (
                f"区域: {district}\n"
                f"温度: {temperature}\n"
                f"湿度: {humidity}\n"
                f"风速: {wind}\n"
                f"天气: {weather}\n"
                f"降雨量: {precipitation}"
            )
            return alert_message, precipitation_value
        else:
            return None, None
    except Exception:
        return None, None

def send_bark_notification(message):
    """通过 Bark API 发送通知"""
    data = {
        "title": TITLE,
        "body": message
    }
    headers = {
        "Content-Type": "application/json"
    }
    try:
        req = urllib.request.Request(BARK_API_URL, data=json.dumps(data).encode(), headers=headers)
        with urllib.request.urlopen(req) as response:
            response.read()
    except Exception:
        pass

def should_send_weather_report():
    """检查是否该发送天气预报"""
    now = datetime.utcnow() + timedelta(hours=8)  # 转换为东八区时间
    return now.hour in [6, 12, 18] and now.minute == 0

def should_check_rain():
    """检查当前时间是否在降雨预警检测时间范围内"""
    now = datetime.utcnow() + timedelta(hours=8)  # 获取东八区时间
    return 6 <= now.hour < 22

def check_rain_forecast(alert_for_rain_only=False):
    """检查每个区未来半小时是否有降雨预警"""
    rain_alerts = []
    for district in DISTRICTS:
        weather_message, precipitation = get_weather(district)
        if precipitation is not None and precipitation > 0.5:  # 降雨量大于0.5mm
            rain_alerts.append(weather_message)

    if rain_alerts:
        if alert_for_rain_only:
            send_bark_notification("降雨预警:\n" + "\n\n".join(rain_alerts))
        else:
            send_bark_notification("天气预报:\n" + "\n\n".join(rain_alerts))

if __name__ == '__main__':
    last_rain_alert = None
    last_weather_report = None

    while True:
        now = datetime.utcnow() + timedelta(hours=8)  # 获取东八区时间

        # 每小时检测一次降雨预警
        if should_check_rain() and (last_rain_alert is None or (now - last_rain_alert).seconds >= 3600):
            check_rain_forecast(alert_for_rain_only=True)
            last_rain_alert = now

        # 在早上6点、中午12点、下午18点发送天气预报
        if should_send_weather_report() and (last_weather_report is None or (now - last_weather_report).seconds >= 3600):
            check_rain_forecast(alert_for_rain_only=False)  # 包含降雨预警的天气预报
            last_weather_report = now

        time.sleep(CHECK_INTERVAL)  # 每隔 CHECK_INTERVAL 秒检查一次