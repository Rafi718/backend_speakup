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

# ---------------------------------------------------------------------------
# Wait for database (best-effort, non-fatal)
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# One-shot seed: import /var/www/html/database/seed.sql when DB is empty.
# Guarded by .seeded marker on persistent storage volume so it runs once.
# ---------------------------------------------------------------------------
SEED_FILE="/var/www/html/database/seed.sql"
SEED_MARKER="/var/www/html/storage/.seed_imported"

if [ -f "$SEED_FILE" ] && [ ! -f "$SEED_MARKER" ] && \
   [ -n "${DB_HOST}" ] && [ -n "${DB_DATABASE}" ] && \
   [ -n "${DB_USERNAME}" ] && [ -n "${DB_PASSWORD}" ]; then

    echo "[entrypoint] Seed check: counting existing tables in ${DB_DATABASE}..."
    TABLE_COUNT=$(MYSQL_PWD="$DB_PASSWORD" mariadb \
        --protocol=tcp -h "$DB_HOST" -P "${DB_PORT:-3306}" -u "$DB_USERNAME" \
        --skip-ssl \
        -N -B -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$DB_DATABASE';" 2>/dev/null || echo "err")

    if [ "$TABLE_COUNT" = "err" ]; then
        echo "[entrypoint] Could not query information_schema (skipping seed)."
    elif [ "$TABLE_COUNT" = "0" ]; then
        echo "[entrypoint] Database is empty. Importing seed.sql ..."
        if MYSQL_PWD="$DB_PASSWORD" mariadb \
                --protocol=tcp -h "$DB_HOST" -P "${DB_PORT:-3306}" \
                --skip-ssl \
                -u "$DB_USERNAME" "$DB_DATABASE" < "$SEED_FILE"; then
            echo "[entrypoint] Seed import OK."
            touch "$SEED_MARKER"
        else
            echo "[entrypoint] !! Seed import FAILED. Will retry on next boot."
        fi
    else
        echo "[entrypoint] Database already has ${TABLE_COUNT} tables. Skipping seed import."
        touch "$SEED_MARKER"
    fi
fi

# ---------------------------------------------------------------------------
# Clear stale caches + run pending migrations
# ---------------------------------------------------------------------------
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
