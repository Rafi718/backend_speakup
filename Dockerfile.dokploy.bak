# syntax=docker/dockerfile:1.6

# ---------------------------------------------------------------------------
# Stage 1 - Composer (PHP vendor dependencies)
# ---------------------------------------------------------------------------
FROM composer:2 AS vendor

WORKDIR /app

COPY composer.json composer.lock ./

RUN composer install \
        --no-dev \
        --no-scripts \
        --no-autoloader \
        --prefer-dist \
        --no-interaction \
        --no-progress

COPY . .

RUN composer dump-autoload --optimize --no-dev --classmap-authoritative


# ---------------------------------------------------------------------------
# Stage 2 - Node (build Vite assets)
# ---------------------------------------------------------------------------
FROM node:20-alpine AS frontend

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install --no-audit --no-fund

COPY . .
COPY --from=vendor /app/vendor ./vendor

RUN npm run build


# ---------------------------------------------------------------------------
# Stage 3 - Runtime (PHP-FPM + Nginx + Supervisor)
# ---------------------------------------------------------------------------
FROM php:8.2-fpm-alpine AS runtime

ENV TZ=Asia/Jakarta \
    COMPOSER_ALLOW_SUPERUSER=1 \
    PHP_OPCACHE_ENABLE=1 \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS=0

# System & PHP extensions
RUN set -eux; \
    apk add --no-cache \
        nginx \
        supervisor \
        bash \
        curl \
        tzdata \
        icu-libs \
        libzip \
        oniguruma \
        freetype \
        libjpeg-turbo \
        libpng \
        mariadb-client \
        fcgi; \
    apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        icu-dev \
        libzip-dev \
        oniguruma-dev \
        freetype-dev \
        libjpeg-turbo-dev \
        libpng-dev; \
    cp /usr/share/zoneinfo/$TZ /etc/localtime; \
    echo "$TZ" > /etc/timezone; \
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-install -j"$(nproc)" \
        pdo_mysql \
        mbstring \
        bcmath \
        zip \
        opcache \
        gd \
        exif \
        pcntl \
        intl; \
    apk del --no-network .build-deps; \
    rm -rf /var/cache/apk/* /tmp/*

# Config files
COPY docker/php/php.ini            /usr/local/etc/php/conf.d/zz-app.ini
COPY docker/php/www.conf           /usr/local/etc/php-fpm.d/zz-www.conf
COPY docker/nginx/nginx.conf       /etc/nginx/nginx.conf
COPY docker/nginx/default.conf     /etc/nginx/http.d/default.conf
COPY docker/supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY docker/entrypoint.sh          /usr/local/bin/entrypoint.sh

RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh \
    && chmod +x /usr/local/bin/entrypoint.sh \
    && rm -f /etc/nginx/http.d/default.conf.default \
    && mkdir -p /run/nginx /var/log/supervisor

WORKDIR /var/www/html

# Application code (with vendor) from composer stage
COPY --from=vendor --chown=www-data:www-data /app /var/www/html

# Built Vite assets
COPY --from=frontend --chown=www-data:www-data /app/public/build /var/www/html/public/build

RUN set -eux; \
    mkdir -p storage/framework/cache/data \
             storage/framework/sessions \
             storage/framework/views \
             storage/logs \
             bootstrap/cache; \
    chown -R www-data:www-data storage bootstrap/cache; \
    chmod -R 775 storage bootstrap/cache

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD curl -fsS http://127.0.0.1/up || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf", "-n"]
