#!/bin/bash
# ============================================
# SpeakUp Backend - Setup Script for VPS
# ============================================
# Usage: ./setup.sh
# Run this script on your VPS after cloning the repo

set -e

echo "============================================"
echo "  SpeakUp Backend Setup"
echo "============================================"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed. Installing...${NC}"
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    echo -e "${GREEN}Docker installed. Please log out and back in for group changes to take effect.${NC}"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker compose &> /dev/null; then
    echo -e "${RED}Docker Compose is not installed. Installing...${NC}"
    sudo apt-get update
    sudo apt-get install -y docker-compose-plugin
fi

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}.env file not found. Creating from .env.production...${NC}"
    if [ -f .env.production ]; then
        cp .env.production .env
        echo -e "${GREEN}.env created. Please edit it with your actual values:${NC}"
        echo "  nano .env"
        echo ""
        echo "Required changes:"
        echo "  1. APP_KEY - Generate with: docker compose run --rm app php artisan key:generate --show"
        echo "  2. DB_ROOT_PASSWORD - Set a secure root password"
        echo "  3. DB_PASSWORD - Set a secure database password"
        echo "  4. APP_DOMAIN - Your actual domain"
        echo "  5. APP_URL - Your actual API URL"
        echo "  6. ACME_EMAIL - Your email for Let's Encrypt"
        echo ""
        exit 0
    else
        echo -e "${RED}No .env.production found. Please create .env manually.${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}Found .env file.${NC}"

# Generate APP_KEY if empty
if grep -q "APP_KEY=$" .env || grep -q "APP_KEY=CHANGE_THIS" .env; then
    echo -e "${YELLOW}APP_KEY is empty. Generating...${NC}"
    # We need to build first to generate key
    docker compose build app
    APP_KEY=$(docker compose run --rm app php artisan key:generate --show)
    sed -i "s/APP_KEY=.*/APP_KEY=$APP_KEY/" .env
    echo -e "${GREEN}APP_KEY generated and saved.${NC}"
fi

echo ""
echo "============================================"
echo "  Building and Starting Services"
echo "============================================"
echo ""

# Build and start
docker compose build --no-cache
docker compose up -d

echo ""
echo "============================================"
echo "  Waiting for services to be ready..."
echo "============================================"
echo ""

# Wait for MySQL
echo -n "Waiting for MySQL..."
until docker compose exec mysql mysqladmin ping -h localhost -u root -p"$(grep DB_ROOT_PASSWORD .env | cut -d '=' -f2)" --silent 2>/dev/null; do
    echo -n "."
    sleep 2
done
echo -e " ${GREEN}Ready!${NC}"

# Wait for app
echo -n "Waiting for Laravel app..."
until docker compose exec app curl -fsS http://127.0.0.1/up > /dev/null 2>&1; do
    echo -n "."
    sleep 2
done
echo -e " ${GREEN}Ready!${NC}"

echo ""
echo "============================================"
echo "  Running Laravel Setup"
echo "============================================"
echo ""

# Run migrations
echo -e "${YELLOW}Running migrations...${NC}"
docker compose exec app php artisan migrate --force

# Seed database (optional)
read -p "Do you want to seed the database? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Seeding database...${NC}"
    docker compose exec app php artisan db:seed --force
fi

# Storage link
echo -e "${YELLOW}Creating storage link...${NC}"
docker compose exec app php artisan storage:link

# Cache config
echo -e "${YELLOW}Caching configuration...${NC}"
docker compose exec app php artisan config:cache
docker compose exec app php artisan route:cache
docker compose exec app php artisan view:cache

echo ""
echo "============================================"
echo -e "  ${GREEN}Setup Complete!${NC}"
echo "============================================"
echo ""
echo "Your API is available at:"
echo "  $(grep APP_URL .env | cut -d '=' -f2)"
echo ""
echo "Useful commands:"
echo "  docker compose logs -f          # View logs"
echo "  docker compose exec app bash    # Enter container"
echo "  docker compose exec app php artisan tinker  # Laravel Tinker"
echo "  docker compose down             # Stop services"
echo "  docker compose up -d            # Start services"
echo ""
echo "To restore MySQL backup:"
echo "  docker compose exec -T mysql mysql -u root -p\"PASSWORD\" db_speakup < backup.sql"
echo ""
