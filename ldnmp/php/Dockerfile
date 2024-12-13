ARG PHP_VERSION
ARG ALPINE_VERSION

FROM php:${PHP_VERSION}-fpm-alpine${ALPINE_VERSION}

RUN apk update && apk add --no-cache \
    imagemagick imagemagick-dev libgomp \
    git autoconf gcc g++ make pkgconfig \
    && git clone https://github.com/Imagick/imagick /tmp/imagick \
    && cd /tmp/imagick \
    && phpize \
    && ./configure \
    && make \
    && make install \
    && echo 'extension=imagick.so' > /usr/local/etc/php/conf.d/imagick.ini \
    && rm -rf /tmp/imagick \
    && curl -fsSL https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions -o /usr/local/bin/install-php-extensions \
    && chmod +x /usr/local/bin/install-php-extensions \
    && /usr/local/bin/install-php-extensions mysqli pdo_mysql gd intl zip exif bcmath opcache redis \
    && apk del git autoconf gcc g++ make pkgconfig \
    && rm -rf /var/cache/apk/*

RUN echo "upload_max_filesize=50M" > /usr/local/etc/php/conf.d/uploads.ini \
    && echo "post_max_size=50M" > /usr/local/etc/php/conf.d/post.ini \
    && echo "memory_limit=256M" > /usr/local/etc/php/conf.d/memory.ini \
    && echo "max_execution_time=1200" > /usr/local/etc/php/conf.d/max_execution_time.ini \
    && echo "max_input_time=600" > /usr/local/etc/php/conf.d/max_input_time.ini \
    && echo "max_input_vars=3000" > /usr/local/etc/php/conf.d/max_input_vars.ini \
    && echo "expose_php=Off" > /usr/local/etc/php/conf.d/custom-php-settings.ini
