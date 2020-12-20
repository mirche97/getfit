#!/bin/sh
set -e

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
    set -- php-fpm "$@"
fi

if [ "$1" = 'php-fpm' ] || [ "$1" = 'php' ] || [ "$1" = 'bin/console' ]; then
    mkdir -p var/cache var/log
    setfacl -R -m u:www-data:rwX -m u:"$(whoami)":rwX var || true
    setfacl -dR -m u:www-data:rwX -m u:"$(whoami)":rwX var || true

    if [ "$APP_ENV" != 'prod' ]; then
        composer install --prefer-dist --no-progress --no-suggest --no-interaction
        yarn install
        yarn encore dev
    fi

    composer run-script --no-dev post-install-cmd

    if [ "$APP_ENV" != 'prod' ]; then
        >&2 echo "Waiting for Postgres to be ready..."
        until pg_isready --timeout=0 --dbname="${DATABASE_URL}"; do
            sleep 1
        done

        bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration
    fi
fi

exec docker-php-entrypoint "$@"
