FROM composer:2 AS vendor

WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-interaction --prefer-dist --optimize-autoloader

FROM php:8.4-fpm-alpine

RUN apk add --no-cache libzip-dev oniguruma-dev \
    && docker-php-ext-install pdo_mysql bcmath opcache zip \
    && apk add --no-cache libzip \
    && apk del libzip-dev oniguruma-dev

WORKDIR /var/www/html

COPY . .
COPY --from=vendor /app/vendor ./vendor
COPY docker/uploads.ini /usr/local/etc/php/conf.d/uploads.ini

RUN rm -f bootstrap/cache/*.php

RUN chown -R www-data:www-data storage bootstrap/cache

USER www-data

CMD ["php-fpm"]
