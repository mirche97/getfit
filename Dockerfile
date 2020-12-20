ARG ALPINE_VERSION=3.10

FROM php:7.4-fpm-alpine$ALPINE_VERSION AS php-fpm

ARG ALPINE_VERSION

# https://gitlab.com/gitlab-com/support-forum/issues/4506#note_168031167
RUN echo "http://mirror.leaseweb.com/alpine/v$ALPINE_VERSION/main" > /etc/apk/repositories
RUN echo "http://mirror.leaseweb.com/alpine/v$ALPINE_VERSION/community" >> /etc/apk/repositories

ENV APP_ENV=prod

RUN set -eux; \
    apk add --no-cache icu postgresql-dev acl make postgresql-client nodejs yarn; \
    apk add --no-cache --virtual .phpize $PHPIZE_DEPS icu-dev; \
    docker-php-ext-install pdo_pgsql intl; \
    apk del .phpize

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY dev/docker/php/development.ini $PHP_INI_DIR/conf.d/

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

ENV COMPOSER_ALLOW_SUPERUSER=1
RUN set -eux; \
    composer clear-cache

WORKDIR /app

COPY composer.json composer.lock symfony.lock package.json webpack.config.js ./

RUN set -eux; \
    composer install --prefer-dist --no-dev --no-autoloader --no-scripts --no-progress --no-suggest; \
    composer clear-cache

RUN yarn install

COPY assets assets/
COPY config config/
COPY bin bin/
COPY public public/
COPY src src/
COPY templates templates/
COPY translations translations/
COPY .env ./

RUN set -eux; \
    mkdir -p var/cache var/log; \
    composer dump-autoload --classmap-authoritative --no-dev; \
    chmod +x bin/console; \
#    bin/console assets:install public; \
    yarn encore production; \
    sync

COPY dev/docker/php/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint

ENTRYPOINT ["docker-entrypoint"]
CMD ["php-fpm"]

#------------------------------------

FROM php-fpm AS php-fpm-test

RUN set -eux; \
    composer install --prefer-dist --no-scripts --no-progress --no-suggest; \
    composer clear-cache

COPY Makefile phpstan.neon .php_cs.dist ./
COPY tests tests/

#------------------------------------

FROM php-fpm-test AS php-fpm-dev

ARG ENABLE_XDEBUG=false

RUN set -eux; \
    if [ "$ENABLE_XDEBUG" = "true" ]; then \
        apk add --no-cache $PHPIZE_DEPS --virtual .build-deps; \
        pecl install xdebug; \
        docker-php-ext-enable xdebug; \
        apk del .build-deps; \
    fi;

RUN set -eux; \
    if [ "$ENABLE_XDEBUG" = "true" ]; then \
        HOST_IP="$(/sbin/ip route|awk '/default/ { print $3 }')"; \
        echo "xdebug.remote_enable=on" >> /usr/local/etc/php/conf.d/xdebug.ini; \
        echo "xdebug.remote_autostart=off" >> /usr/local/etc/php/conf.d/xdebug.ini; \
        echo "xdebug.remote_host=${HOST_IP}" >> /usr/local/etc/php/conf.d/xdebug.ini; \
    fi;

#------------------------------------

FROM nginx:1.17-alpine AS nginx

COPY dev/docker/nginx/production.conf /etc/nginx/conf.d/default.conf

COPY --from=php-fpm /app/public /app/public
