# Description: This dockerfile is used to build web game Flappy-Bird.
#
# Copyright (c) 2025 honeok <honeok@duck.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM nginx:stable-alpine

LABEL maintainer="honeok <honeok@duck.com>"

# RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.nju.edu.cn/g' /etc/apk/repositories
RUN set -ex \
    && apk update && apk upgrade \
    && apk add --no-cache git \
    && rm -rf /usr/share/nginx/html/* \
    && cd /usr/share/nginx/html \
    && git clone --branch master --single-branch https://github.com/noanonoa/flappy-bird.git . \
    && sed -i 's|<title>Game Project 001</title>|<title>Flappy Bird</title>|' index.html \
    && curl -fsL https://flappybird.io/favicon.ico -o favicon.ico \
    && sed -i '/^worker_processes/s|^worker_processes.*$|worker_processes 1;|' /etc/nginx/nginx.conf \
    && printf "server_tokens off;\nautoindex off;\n" > /etc/nginx/conf.d/security.conf \
    && apk del git \
    && rm -rf /var/cache/apk/* /tmp/*