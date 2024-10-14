#!/bin/bash

# 切换到 web 目录并创建 tar 归档
cd /data/docker_data/web && tar czvf web_$(date +"%Y%m%d%H%M%S").tar.gz .

# 将 tar 归档传输到另一台 VPS 的 /opt 目录
cd /data/docker_data/web && ls -t /data/docker_data/web/*.tar.gz | head -1 | xargs -I {} sshpass -p 123456 scp -o StrictHostKeyChecking=no -P 22 {} root@0.0.0.0:/opt/

# 保留最新的 5 个 tar 归档，删除其余的
cd /data/docker_data/web && ls -t /data/docker_data/web/*.tar.gz | tail -n +6 | xargs -I {} rm {}