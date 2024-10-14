#!/bin/bash
# Author: honeok
# Blog: https://www.honeok.com
# echo "*/1 * * * * ${PWD}/weather_alert.sh >/dev/null 2>&1" | crontab -
##############################

######## == 功能 == ##########
# 天气通知: 每天早上8点发送成都天气信息
# 降雨预警:每小时整点检查未来一小时降雨概率,若高于50%则发送预警
# 地震预警:每半小时检查未来12小时内是否有震级大于或等于5的地震发生在中国,如果有则发送预警
##############################

# 配置
BARK_URL="https://api.honeok.com/LYqnYRnftPnKkLiopyowvb/"
LAT="30.5728"  # 成都的纬度
LON="104.0668"  # 成都的经度
WEATHER_API="https://api.open-meteo.com/v1/forecast"
TIMEZONE="Asia/Shanghai"
EARTHQUAKE_API="https://earthquake.usgs.gov/fdsnws/event/1/query"

# 获取天气信息
function get_weather() {
    curl -s "$WEATHER_API?latitude=$LAT&longitude=$LON&hourly=temperature_2m,precipitation_probability,weathercode&current_weather=true&timezone=$TIMEZONE"
}

# 获取地震信息
function get_earthquake() {
    curl -s "$EARTHQUAKE_API?format=geojson&starttime=$(date '+%Y-%m-%dT%H:%M:%S')&endtime=$(date -d '+12 hours' '+%Y-%m-%dT%H:%M:%S')"
}

# 解析JSON并发送每日天气通知
function send_daily_weather() {
    WEATHER_JSON=$(get_weather)
    PYTHON_SCRIPT=$(cat <<EOF
import json
import sys

data = json.loads(sys.stdin.read())
current_weather_code = data['current_weather']['weathercode']
temp = data['current_weather']['temperature']

weather_desc = {
    0: "晴天",
    1: "多云",
    2: "多云",
    3: "多云",
    45: "有雾",
    48: "有雾",
    51: "小雨",
    53: "小雨",
    55: "小雨",
    56: "小雨",
    57: "小雨",
    61: "中雨",
    63: "中雨",
    65: "中雨",
    80: "大雨",
    81: "大雨",
    82: "大雨"
}.get(current_weather_code, "未知天气")

print(f"成都今日天气 当前天气：{weather_desc}，气温：{temp}°C")
EOF
    )

    # 获取解析后的天气信息
    WEATHER_INFO=$(echo "$WEATHER_JSON" | python3 -c "$PYTHON_SCRIPT")
    TITLE=$(echo "$WEATHER_INFO" | awk '{print $1}')
    BODY=$(echo "$WEATHER_INFO" | cut -d' ' -f2-)

    # 发送通知
    curl -s -X POST "$BARK_URL" \
        -H "Content-Type: application/json" \
        -d "{\"title\":\"$TITLE\",\"body\":\"$BODY\"}"
}

# 解析JSON并检查未来一小时是否下雨
function check_rain() {
    WEATHER_JSON=$(get_weather)
    PYTHON_SCRIPT=$(cat <<EOF
import json
import sys

data = json.loads(sys.stdin.read())
hourly_rain_prob = data['hourly']['precipitation_probability'][1]

if hourly_rain_prob > 50:
    print(f"成都降雨预警 未来一小时内可能下雨，降水概率为 {hourly_rain_prob}%。请注意防护。")
EOF
    )

    RAIN_ALERT=$(echo "$WEATHER_JSON" | python3 -c "$PYTHON_SCRIPT")

    if [ -n "$RAIN_ALERT" ]; then
        TITLE=$(echo "$RAIN_ALERT" | awk '{print $1}')
        BODY=$(echo "$RAIN_ALERT" | cut -d' ' -f2-)

        # 发送通知
        curl -s -X POST "$BARK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"title\":\"$TITLE\",\"body\":\"$BODY\"}"
    fi
}

# 检查地震预警
function check_earthquake() {
    EARTHQUAKE_JSON=$(get_earthquake)
    PYTHON_SCRIPT=$(cat <<EOF
import json
import sys

def is_in_china(lat, lon):
    return 18 <= lat <= 54 and 73 <= lon <= 135

data = json.loads(sys.stdin.read())
earthquakes = data.get('features', [])

for quake in earthquakes:
    magnitude = quake['properties'].get('mag', 0)
    place = quake['properties'].get('place', '未知地点')
    coords = quake['geometry'].get('coordinates', [])
    lon, lat = coords[0], coords[1] if len(coords) >= 2 else (None, None)
    
    if magnitude >= 5 and is_in_china(lat, lon):
        print(f"地震预警: {place}，震级：{magnitude}，位置：{lat}, {lon}。")
EOF
    )

    EARTHQUAKE_ALERT=$(echo "$EARTHQUAKE_JSON" | python3 -c "$PYTHON_SCRIPT")

    if [ -n "$EARTHQUAKE_ALERT" ]; then
        TITLE=$(echo "$EARTHQUAKE_ALERT" | awk '{print $1}')
        BODY=$(echo "$EARTHQUAKE_ALERT" | cut -d' ' -f2-)

        # 发送通知
        curl -s -X POST "$BARK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"title\":\"$TITLE\",\"body\":\"$BODY\"}"
    fi
}

# 时间检查
current_hour=$(date +"%H")
current_minute=$(date +"%M")

# 判断时间并执行任务
if [ "$current_minute" -eq 0 ] && [ "$current_hour" -ge 8 ] && [ "$current_hour" -le 22 ]; then
    if [ "$current_hour" -eq 8 ]; then
        send_daily_weather
    else
        check_rain
    fi
fi

# 每半小时检查一次地震
if [ "$((current_minute % 30))" -eq 0 ]; then
    check_earthquake
fi
