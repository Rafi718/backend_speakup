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
chown -R www-data:www-data public 2>/dev/null || true
chmod -R 775 storage bootstrap/cache

if [ -z "${APP_KEY}" ]; then
    echo "[entrypoint] WARNING: APP_KEY is empty. Generating a temporary one."
    php artisan key:generate --force --no-interaction || true
fi

# Wait for database (best-effort, non-fatal)
if [ -n "${DB_HOST}" ] && [ -n "${DB_PORT}" ]; then
    echo "[entrypoint] Waiting for database ${DB_HOST}:${DB_PORT}..."
    i=0
    max=60
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

# --------------------------------------------------
# Check if database has been migrated already
# --------------------------------------------------
echo "[entrypoint] Checking database state..."

# Use a simple PHP check to see if migrations table exists
HAS_MIGRATIONS=$(php -r "
try {
    \$pdo = new PDO('mysql:host='.getenv('DB_HOST').';port='.getenv('DB_PORT').';dbname='.getenv('DB_DATABASE'), getenv('DB_USERNAME'), getenv('DB_PASSWORD'));
    \$stmt = \$pdo->query(\"SHOW TABLES LIKE 'migrations'\");
    echo \$stmt->rowCount() > 0 ? 'yes' : 'no';
} catch (Exception \$e) {
    echo 'no';
}
" 2>/dev/null || echo "no")

# --------------------------------------------------
# Restore SQL backup if present
# --------------------------------------------------
if [ -f "/var/www/html/docker-entrypoint-initdb.d/backup.sql" ]; then
    echo "[entrypoint] Found backup.sql - restoring database..."
    mysql -h "${DB_HOST}" -P "${DB_PORT}" -u root -p"${DB_ROOT_PASSWORD}" "${DB_DATABASE}" < /var/www/html/docker-entrypoint-initdb.d/backup.sql 2>/dev/null \
        || mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USERNAME}" -p"${DB_PASSWORD}" "${DB_DATABASE}" < /var/www/html/docker-entrypoint-initdb.d/backup.sql
    echo "[entrypoint] Backup restored successfully!"
    HAS_MIGRATIONS="yes"
fi

# --------------------------------------------------
# Run migrations (skip if already migrated or SKIP_MIGRATION=true)
# --------------------------------------------------
if [ "${SKIP_MIGRATION}" = "true" ] || [ "${HAS_MIGRATIONS}" = "yes" ]; then
    echo "[entrypoint] Skipping migrations (database already initialized)"
else
    echo "[entrypoint] Running migrations..."
    php artisan migrate --force --no-interaction || echo "[entrypoint] Migrations failed - check DB credentials."
fi

echo "[entrypoint] Ensuring storage symlink..."
php artisan storage:link || true

echo "[entrypoint] Caching config / routes / views..."
php artisan config:cache
php artisan route:cache || true
php artisan view:cache || true

echo "[entrypoint] Starting: $*"
exec "$@"
