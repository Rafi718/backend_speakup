#!/bin/bash
# ============================================
# SpeakUp - Database Restore Script
# ============================================
# Usage:
#   ./restore-db.sh                           # Auto-find backup.sql in ./backups/
#   ./restore-db.sh /path/to/backup.sql       # Restore specific file
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Load .env
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

DB_ROOT_PASS=${DB_ROOT_PASSWORD:-rootpass}
DB_NAME=${DB_DATABASE:-db_speakup}
DB_USER=${DB_USERNAME:-speakup_user}
DB_PASS=${DB_PASSWORD:-speakup_pass}

# Find backup file
BACKUP_FILE="$1"
if [ -z "$BACKUP_FILE" ]; then
    # Auto-find in backups/ folder
    if [ -f "backups/backup.sql" ]; then
        BACKUP_FILE="backups/backup.sql"
    elif [ -f "db_speakup.sql" ]; then
        BACKUP_FILE="db_speakup.sql"
    else
        echo -e "${RED}No backup file specified and no default found.${NC}"
        echo ""
        echo "Usage:"
        echo "  $0                           # Auto-find backup.sql"
        echo "  $0 /path/to/backup.sql      # Restore specific file"
        echo ""
        echo "Place your backup file in one of these locations:"
        echo "  ./backups/backup.sql"
        echo "  ./db_speakup.sql"
        exit 1
    fi
fi

if [ ! -f "${BACKUP_FILE}" ]; then
    echo -e "${RED}File not found: ${BACKUP_FILE}${NC}"
    exit 1
fi

echo "============================================"
echo "  SpeakUp Database Restore"
echo "============================================"
echo ""
echo -e "Database: ${YELLOW}${DB_NAME}${NC}"
echo -e "Backup:   ${YELLOW}${BACKUP_FILE}${NC}"
echo -e "Size:     ${YELLOW}$(du -h ${BACKUP_FILE} | cut -f1)${NC}"
echo ""
echo -e "${RED}WARNING: This will OVERWRITE the '${DB_NAME}' database!${NC}"
echo ""
read -p "Continue? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo -e "${YELLOW}Step 1: Dropping existing database...${NC}"
docker compose exec -T mysql mysql -u root -p"${DB_ROOT_PASS}" -e "DROP DATABASE IF EXISTS ${DB_NAME};" 2>/dev/null \
    || docker compose exec -T mysql mysqladmin -u root -p"${DB_ROOT_PASS}" drop "${DB_NAME}" --force 2>/dev/null

echo -e "${YELLOW}Step 2: Creating fresh database...${NC}"
docker compose exec -T mysql mysql -u root -p"${DB_ROOT_PASS}" -e "
CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
"

echo -e "${YELLOW}Step 3: Restoring data from backup...${NC}"
docker compose exec -T mysql mysql -u root -p"${DB_ROOT_PASS}" "${DB_NAME}" < "${BACKUP_FILE}"

echo -e "${YELLOW}Step 4: Verifying restore...${NC}"
TABLE_COUNT=$(docker compose exec -T mysql mysql -u root -p"${DB_ROOT_PASS}" "${DB_NAME}" -e "SHOW TABLES;" 2>/dev/null | wc -l)
echo -e "${GREEN}Tables restored: ${TABLE_COUNT}${NC}"

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Restore Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Tables in database:"
docker compose exec -T mysql mysql -u root -p"${DB_ROOT_PASS}" "${DB_NAME}" -e "SHOW TABLES;" 2>/dev/null
echo ""
echo "Note: Laravel will skip migrations on next start (since data is restored)."
echo "Restart app: docker compose restart app"
