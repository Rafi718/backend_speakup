#!/bin/sh
set -e

echo "========================================="
echo "  Starting SpeakUp Backend (Laravel)"
echo "========================================="

echo "Waiting for database..."
max_retries=30
retry_count=0

until mysqladmin ping -h"${DB_HOST}" -P"${DB_PORT:-3306}" -u"${DB_USERNAME}" -p"${DB_PASSWORD}" --silent 2>/dev/null; do
    retry_count=$((retry_count + 1))
    if [ $retry_count -ge $max_retries ]; then
        echo "Database connection failed after $max_retries attempts"
        exit 1
    fi
    echo "Database unavailable - retrying ($retry_count/$max_retries)..."
    sleep 2
done

echo "Database is ready!"

mkdir -p /var/www/html/storage/framework/cache
mkdir -p /var/www/html/storage/framework/sessions
mkdir -p /var/www/html/storage/framework/views
mkdir -p /var/www/html/storage/logs
mkdir -p /var/www/html/bootstrap/cache
chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache
chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

echo "Running migrations..."
php artisan migrate --force --no-interaction

echo "Caching configuration..."
php artisan config:clear
php artisan config:cache
php artisan route:cache
php artisan view:cache

php artisan storage:link || true

echo "========================================="
echo "  Laravel Backend Ready!"
echo "========================================="

exec "$@"
