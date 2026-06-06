# SpeakUp Backend - Deployment Guide

## Arsitektur

```
┌─────────────────────────────────────────────────────────────┐
│                        VPS (Ubuntu)                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   Caddy     │  │  PHP-FPM    │  │      MySQL 8        │ │
│  │  (Port 80,  │─▶│  (Laravel)  │  │  (Port 3306)        │ │
│  │   443)      │  │             │  │                     │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
│         │                │                    │             │
│         └────────────────┴────────────────────┘             │
│                       Docker Network                        │
└─────────────────────────────────────────────────────────────┘
         │
         │ HTTPS (Auto Let's Encrypt)
         ▼
┌─────────────────┐     ┌─────────────────┐
│   Vercel        │     │   Users         │
│   (Frontend)    │◀────│   (Browser)     │
└─────────────────┘     └─────────────────┘
```

## Prasyarat

- VPS dengan Ubuntu 20.04+ (2GB RAM minimum)
- Domain yang mengarah ke IP VPS (A record)
- Docker & Docker Compose terinstall

## Quick Start

### 1. Clone Repository

```bash
git clone <repo-url> /opt/speakup
cd /opt/speakup/backend_speakup
```

### 2. Setup Environment

```bash
# Copy env template
cp .env.production .env

# Edit dengan values yang sesuai
nano .env
```

**Yang perlu diubah:**
- `APP_KEY` - Generate nanti
- `DB_ROOT_PASSWORD` - Password root MySQL
- `DB_PASSWORD` - Password database user
- `APP_DOMAIN` - Domain API kamu
- `APP_URL` - URL API (https://api.xxx.com)
- `ACME_EMAIL` - Email untuk Let's Encrypt
- `SANCTUM_STATEFUL_DOMAINS` - Domain frontend
- `CORS_ALLOWED_ORIGINS` - Domain frontend
- `FRONTEND_URL` - URL frontend

### 3. Jalankan Setup

```bash
chmod +x setup.sh
./setup.sh
```

Atau manual:

```bash
# Build & Start
docker compose -f docker-compose.caddy.yml build
docker compose -f docker-compose.caddy.yml up -d

# Generate APP_KEY
docker compose exec app php artisan key:generate --show
# Copy output ke .env APP_KEY

# Restart untuk apply key baru
docker compose restart app

# Run migrations
docker compose exec app php artisan migrate --force

# Create storage link
docker compose exec app php artisan storage:link

# Cache config
docker compose exec app php artisan config:cache
docker compose exec app php artisan route:cache
```

### 4. Restore Backup MySQL

```bash
# Copy backup file ke server
scp backup.sql user@server:/opt/speakup/backend_speakup/

# Restore
docker compose exec -T mysql mysql -u root -p"ROOT_PASSWORD" db_speakup < backup.sql

# Atau gunakan script
chmod +x backup.sh
./backup.sh restore backup.sql
```

### 5. Verifikasi

```bash
# Check containers running
docker compose ps

# Check logs
docker compose logs -f

# Test API
curl https://api.speakup.web.id/up
```

## Commands

### Docker Compose

```bash
# Start services
docker compose up -d

# Stop services
docker compose down

# View logs
docker compose logs -f

# Restart specific service
docker compose restart app

# Enter container
docker compose exec app bash

# Laravel commands
docker compose exec app php artisan tinker
docker compose exec app php artisan migrate
docker compose exec app php artisan db:seed
```

### Backup & Restore

```bash
# Create backup
./backup.sh backup

# Restore backup
./backup.sh restore backup_file.sql

# Auto backup (add to cron)
./backup.sh auto-backup
```

**Add to cron for daily backup:**
```bash
# Edit crontab
crontab -e

# Add this line (runs at 2 AM daily)
0 2 * * * cd /opt/speakup/backend_speakup && ./backup.sh auto-backup >> /var/log/speakup-backup.log 2>&1
```

## Domain & DNS Setup

### DNS Records

```
Type    Name                    Value
A       api.speakup.web.id      YOUR_VPS_IP
A       speakup.web.id          YOUR_VPS_IP (optional)
CNAME   www.speakup.web.id      speakup.web.id (optional)
```

### Vercel Frontend

Di Vercel, set environment variable:
```
VITE_API_URL = https://api.speakup.web.id/api
```

## Troubleshooting

### Caddy tidak bisa dapat SSL

```bash
# Check Caddy logs
docker compose logs app | grep -i caddy

# Pastikan port 80 dan 443 terbuka
sudo ufw allow 80
sudo ufw allow 443

# Pastikan domain mengarah ke IP yang benar
dig api.speakup.web.id
```

### MySQL connection refused

```bash
# Check MySQL status
docker compose exec mysql mysqladmin ping -h localhost -u root -p"PASSWORD"

# Check MySQL logs
docker compose logs mysql

# Test connection from app
docker compose exec app php artisan tinker
# >>> DB::connection()->getPdo();
```

### Permission issues

```bash
docker compose exec app chown -R www-data:www-data storage bootstrap/cache
docker compose exec app chmod -R 775 storage bootstrap/cache
```

### Reset everything

```bash
# Stop and remove all containers, networks, and volumes
docker compose down -v

# Remove all data (WARNING: deletes database!)
sudo rm -rf /var/lib/docker/volumes/speakup_mysql_data

# Rebuild
docker compose build --no-cache
docker compose up -d
```

## File Structure

```
backend_speakup/
├── docker-compose.caddy.yml    # Production compose file
├── Dockerfile.caddy            # Dockerfile with Caddy
├── .env.production             # Production env template
├── setup.sh                    # Setup script
├── backup.sh                   # Backup/restore script
├── docker/
│   ├── caddy/
│   │   └── Caddyfile           # Caddy configuration
│   ├── php/
│   │   ├── php.ini             # PHP configuration
│   │   └── www.conf            # PHP-FPM pool config
│   └── mysql/
│       └── init.sql            # MySQL init script
└── ...
```
