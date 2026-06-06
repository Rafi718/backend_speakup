#!/bin/bash
# ============================================
# SpeakUp - MySQL Backup & Restore Script
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
CONTAINER_NAME="speakup-mysql"

case "$1" in
    backup)
        echo -e "${YELLOW}Creating backup...${NC}"
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        BACKUP_FILE="backup_${DB_NAME}_${TIMESTAMP}.sql"
        
        docker compose exec mysql mysqldump \
            -u root \
            -p"${DB_ROOT_PASS}" \
            --single-transaction \
            --routines \
            --triggers \
            --all-databases > "${BACKUP_FILE}"
        
        echo -e "${GREEN}Backup created: ${BACKUP_FILE}${NC}"
        echo "Size: $(du -h ${BACKUP_FILE} | cut -f1)"
        ;;
        
    restore)
        if [ -z "$2" ]; then
            echo -e "${RED}Usage: $0 restore <backup_file.sql>${NC}"
            exit 1
        fi
        
        BACKUP_FILE="$2"
        
        if [ ! -f "${BACKUP_FILE}" ]; then
            echo -e "${RED}File not found: ${BACKUP_FILE}${NC}"
            exit 1
        fi
        
        echo -e "${YELLOW}Restoring from: ${BACKUP_FILE}${NC}"
        echo -e "${RED}WARNING: This will overwrite the current database!${NC}"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Restoring...${NC}"
            docker compose exec -T mysql mysql \
                -u root \
                -p"${DB_ROOT_PASS}" \
                < "${BACKUP_FILE}"
            echo -e "${GREEN}Restore complete!${NC}"
        else
            echo "Cancelled."
        fi
        ;;
        
    restore-to-db)
        if [ -z "$2" ]; then
            echo -e "${RED}Usage: $0 restore-to-db <backup_file.sql>${NC}"
            exit 1
        fi
        
        BACKUP_FILE="$2"
        
        if [ ! -f "${BACKUP_FILE}" ]; then
            echo -e "${RED}File not found: ${BACKUP_FILE}${NC}"
            exit 1
        fi
        
        echo -e "${YELLOW}Restoring to database: ${DB_NAME}${NC}"
        echo -e "${RED}WARNING: This will overwrite the ${DB_NAME} database!${NC}"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Restoring...${NC}"
            docker compose exec -T mysql mysql \
                -u root \
                -p"${DB_ROOT_PASS}" \
                "${DB_NAME}" < "${BACKUP_FILE}"
            echo -e "${GREEN}Restore complete!${NC}"
        else
            echo "Cancelled."
        fi
        ;;
        
    auto-backup)
        # Create backup directory
        mkdir -p backups
        
        # Create backup with timestamp
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        BACKUP_FILE="backups/backup_${DB_NAME}_${TIMESTAMP}.sql"
        
        docker compose exec mysql mysqldump \
            -u root \
            -p"${DB_ROOT_PASS}" \
            --single-transaction \
            --routines \
            --triggers \
            "${DB_NAME}" > "${BACKUP_FILE}"
        
        # Compress
        gzip "${BACKUP_FILE}"
        
        # Keep only last 7 backups
        ls -t backups/backup_*.sql.gz | tail -n +8 | xargs -r rm
        
        echo -e "${GREEN}Auto-backup complete: ${BACKUP_FILE}.gz${NC}"
        ;;
        
    *)
        echo "SpeakUp MySQL Backup & Restore"
        echo ""
        echo "Usage:"
        echo "  $0 backup              # Create full backup"
        echo "  $0 restore <file.sql>  # Restore full backup"
        echo "  $0 restore-to-db <file.sql>  # Restore to specific database"
        echo "  $0 auto-backup         # Auto backup with rotation (keep 7 days)"
        echo ""
        echo "Examples:"
        echo "  $0 backup"
        echo "  $0 restore backup_db_speakup_20240101_120000.sql"
        echo ""
        ;;
esac
