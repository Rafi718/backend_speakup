#!/bin/sh
set -e

cd /var/www/html

echo "[entrypoint] Ensuring storage directories exist..."
mkdir -p \
    storage/app/public \
    storage/app/private \
    storage/framework/cache/data \
    storage/framework/sessions \
    storage/framework/testing \
    storage/framework/views \
    storage/logs \
    bootstrap/cache

echo "[entrypoint] Fixing permissions..."
chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache

if [ -z "${APP_KEY}" ]; then
    echo "[entrypoint] WARNING: APP_KEY is empty. Generating a temporary one (set APP_KEY in env for persistence)."
    php artisan key:generate --force --no-interaction || true
fi

# Wait for database (best-effort, non-fatal)
if [ -n "${DB_HOST}" ] && [ -n "${DB_PORT}" ]; then
    echo "[entrypoint] Waiting for database ${DB_HOST}:${DB_PORT}..."
    i=0
    max=30
    until php -r "exit(@fsockopen(getenv('DB_HOST'), (int) getenv('DB_PORT')) ? 0 : 1);"; do
        i=$((i + 1))
        if [ "$i" -ge "$max" ]; then
            echo "[entrypoint] Database not reachable after ${max}s, continuing anyway."
            break
        fi
        sleep 1
    done
fi

echo "[entrypoint] Clearing stale caches..."
php artisan config:clear || true
php artisan route:clear || true
php artisan view:clear || true
php artisan cache:clear || true

echo "[entrypoint] Running migrations..."
if ! php artisan migrate --force --no-interaction; then
    echo "[entrypoint] !! Migration failed. Check DB credentials / connectivity."
    echo "[entrypoint] !! Container will keep running so you can inspect logs, but app will likely return 500."
fi

echo "[entrypoint] Ensuring storage symlink..."
php artisan storage:link || true

echo "[entrypoint] Caching config / routes / views..."
php artisan config:cache
php artisan route:cache || true
php artisan view:cache || true

echo "[entrypoint] Starting: $*"
exec "$@"
