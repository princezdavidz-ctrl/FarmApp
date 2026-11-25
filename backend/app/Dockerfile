FROM composer:2 AS vendor

WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-interaction --prefer-dist --optimize-autoloader

FROM php:8.4-fpm-alpine

RUN apk add --no-cache nginx supervisor libzip libpq     && apk add --no-cache --virtual .build-deps libzip-dev oniguruma-dev postgresql-dev libxml2-dev     && docker-php-ext-install pdo_mysql pdo_pgsql bcmath mbstring xml opcache zip     && apk del .build-deps

WORKDIR /var/www/html

COPY . .
COPY --from=vendor /app/vendor ./vendor
COPY docker/uploads.ini /usr/local/etc/php/conf.d/uploads.ini
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/supervisord.conf /etc/supervisord.conf

RUN rm -f bootstrap/cache/*.php \
    && mkdir -p /run/nginx \
    && chown -R www-data:www-data storage bootstrap/cache

EXPOSE 10000

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
