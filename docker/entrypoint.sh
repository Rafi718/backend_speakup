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

# --------------------------------------------------
# Create .env file from environment variables
# --------------------------------------------------
if [ ! -f "/var/www/html/.env" ]; then
    echo "[entrypoint] Creating .env from environment variables..."
    cat > /var/www/html/.env << EOF
APP_NAME=${APP_NAME:-SpeakUp}
APP_ENV=${APP_ENV:-production}
APP_KEY=${APP_KEY}
APP_DEBUG=${APP_DEBUG:-false}
APP_URL=${APP_URL:-http://localhost}

LOG_CHANNEL=${LOG_CHANNEL:-stderr}
LOG_LEVEL=${LOG_LEVEL:-error}

DB_CONNECTION=${DB_CONNECTION:-mysql}
DB_HOST=${DB_HOST:-mysql}
DB_PORT=${DB_PORT:-3306}
DB_DATABASE=${DB_DATABASE:-db_speakup}
DB_USERNAME=${DB_USERNAME:-speakup_user}
DB_PASSWORD=${DB_PASSWORD}

SESSION_DRIVER=${SESSION_DRIVER:-database}
SESSION_LIFETIME=${SESSION_LIFETIME:-120}
SESSION_DOMAIN=${SESSION_DOMAIN:-}
CACHE_STORE=${CACHE_STORE:-database}
QUEUE_CONNECTION=${QUEUE_CONNECTION:-database}

SANCTUM_STATEFUL_DOMAINS=${SANCTUM_STATEFUL_DOMAINS:-}
CORS_ALLOWED_ORIGINS=${CORS_ALLOWED_ORIGINS:-}
FRONTEND_URL=${FRONTEND_URL:-}

MAIL_MAILER=${MAIL_MAILER:-log}
MAIL_FROM_ADDRESS=${MAIL_FROM_ADDRESS:-noreply@speakup.local}
MAIL_FROM_NAME=${MAIL_FROM_NAME:-SpeakUp}
EOF
    echo "[entrypoint] .env created successfully."
fi

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
# Restore SQL backup if present (using PHP PDO - more reliable)
# --------------------------------------------------
if [ -f "/var/www/html/backups/backup.sql" ]; then
    echo "[entrypoint] Found backup.sql - restoring database using PHP PDO..."
    php -r "
    try {
        \$dsn = 'mysql:host=' . getenv('DB_HOST') . ';port=' . getenv('DB_PORT') . ';dbname=' . getenv('DB_DATABASE');
        \$pdo = new PDO(\$dsn, getenv('DB_USERNAME'), getenv('DB_PASSWORD'), [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]);
        
        \$sql = file_get_contents('/var/www/html/backups/backup.sql');
        if (\$sql === false) {
            echo 'Failed to read backup.sql';
            exit(1);
        }
        
        // Split by semicolons and execute each statement
        \$statements = array_filter(array_map('trim', explode(';', \$sql)));
        \$total = count(\$statements);
        \$executed = 0;
        \$errors = 0;
        
        foreach (\$statements as \$statement) {
            if (empty(\$statement)) continue;
            try {
                \$pdo->exec(\$statement);
                \$executed++;
            } catch (PDOException \$e) {
                // Skip errors for DROP TABLE IF EXISTS, etc.
                \$errors++;
            }
        }
        
        echo \"Backup restored: \$executed/\$total statements executed (\$errors errors)\n\";
    } catch (PDOException \$e) {
        echo 'Database restore failed: ' . \$e->getMessage() . \"\n\";
        exit(1);
    }
    " && echo "[entrypoint] Backup restored successfully!" || echo "[entrypoint] Backup restore failed!"
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

echo "[entrypoint] Starting PHP-FPM in background..."
php-fpm -D

echo "[entrypoint] Starting: $*"
exec "$@"
