FROM php:8.3.12-fpm-alpine3.20
#FROM php:7.4.33-fpm-alpine3.16

RUN apk update && apk add --no-cache \
    imagemagick imagemagick-dev \
    git autoconf gcc g++ make pkgconfig \
    && rm -fr /tmp/imagick \
    && git clone https://github.com/Imagick/imagick /tmp/imagick \
    && cd /tmp/imagick \
    && phpize \
    && ./configure \
    && make \
    && make install \
    && echo 'extension=imagick.so' > /usr/local/etc/php/conf.d/imagick.ini \
    && rm -fr /tmp/imagick \
    && curl -fsSL https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions -o /usr/local/bin/install-php-extensions \
    && chmod +x /usr/local/bin/install-php-extensions \
    && install-php-extensions imagick mysqli pdo_mysql gd intl zip exif bcmath opcache redis \
    && rm -fr /tmp/imagick

RUN echo "upload_max_filesize=50M" > /usr/local/etc/php/conf.d/uploads.ini \
    && echo "post_max_size=50M" > /usr/local/etc/php/conf.d/post.ini \
    && echo "memory_limit=256M" > /usr/local/etc/php/conf.d/memory.ini \
    && echo "max_execution_time=1200" > /usr/local/etc/php/conf.d/max_execution_time.ini \
    && echo "max_input_time=600" > /usr/local/etc/php/conf.d/max_input_time.ini \
    && echo "max_input_vars=3000" > /usr/local/etc/php/conf.d/max_input_vars.ini \
    && echo "expose_php=Off" > /usr/local/etc/php/conf.d/custom-php-settings.ini

ENTRYPOINT ["docker-php-entrypoint"]

WORKDIR /var/www/html

EXPOSE 9000

CMD ["php-fpm"]
