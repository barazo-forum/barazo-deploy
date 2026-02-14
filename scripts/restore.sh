#!/usr/bin/env bash
# Barazo Restore Script
#
# Restores a PostgreSQL backup from a file created by backup.sh.
#
# Usage:
#   ./scripts/restore.sh backups/barazo-backup-20260214-020000.sql.gz
#   ./scripts/restore.sh backups/barazo-backup-20260214-020000.sql.gz.age
#
# For encrypted backups (.age), set BACKUP_PRIVATE_KEY_FILE to the path
# of your age private key file.
#
# WARNING: This will overwrite the current database contents.

set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <backup-file>" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  $0 backups/barazo-backup-20260214-020000.sql.gz" >&2
  echo "  $0 backups/barazo-backup-20260214-020000.sql.gz.age" >&2
  echo "" >&2
  echo "Environment variables:" >&2
  echo "  BACKUP_PRIVATE_KEY_FILE  Path to age private key (for .age files)" >&2
  echo "  COMPOSE_FILE             Docker Compose file (default: docker-compose.yml)" >&2
  exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
  echo "Error: Backup file not found: $BACKUP_FILE" >&2
  exit 1
fi

# Check if encrypted
IS_ENCRYPTED=false
if [[ "$BACKUP_FILE" == *.age ]]; then
  IS_ENCRYPTED=true
  if [ -z "${BACKUP_PRIVATE_KEY_FILE:-}" ]; then
    echo "Error: Encrypted backup requires BACKUP_PRIVATE_KEY_FILE environment variable" >&2
    exit 1
  fi
  if [ ! -f "$BACKUP_PRIVATE_KEY_FILE" ]; then
    echo "Error: Private key file not found: $BACKUP_PRIVATE_KEY_FILE" >&2
    exit 1
  fi
  if ! command -v age &>/dev/null; then
    echo "Error: age is required for decryption. Install: https://github.com/FiloSottile/age" >&2
    exit 1
  fi
fi

# Confirm
echo "WARNING: This will overwrite the current database."
echo "Backup file: $BACKUP_FILE"
echo ""
read -p "Continue? (y/N) " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Restore cancelled."
  exit 0
fi

# Check PostgreSQL is running
if ! docker compose -f "$COMPOSE_FILE" exec -T postgres pg_isready -U "${POSTGRES_USER:-barazo}" &>/dev/null; then
  echo "Error: PostgreSQL is not running. Start it with: docker compose -f $COMPOSE_FILE up -d postgres" >&2
  exit 1
fi

echo "Starting restore at $(date)"

# Stop API and Web to prevent writes during restore
echo "Stopping API and Web services..."
docker compose -f "$COMPOSE_FILE" stop barazo-api barazo-web 2>/dev/null || true

# Restore
DB_NAME="${POSTGRES_DB:-barazo}"
DB_USER="${POSTGRES_USER:-barazo}"

echo "Dropping and recreating database..."
docker compose -f "$COMPOSE_FILE" exec -T postgres \
  psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS $DB_NAME;"
docker compose -f "$COMPOSE_FILE" exec -T postgres \
  psql -U "$DB_USER" -d postgres -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"

echo "Restoring from backup..."
if [ "$IS_ENCRYPTED" = true ]; then
  age -d -i "$BACKUP_PRIVATE_KEY_FILE" "$BACKUP_FILE" \
    | gunzip \
    | docker compose -f "$COMPOSE_FILE" exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" -q
else
  gunzip -c "$BACKUP_FILE" \
    | docker compose -f "$COMPOSE_FILE" exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" -q
fi

# Restart services
echo "Restarting API and Web services..."
docker compose -f "$COMPOSE_FILE" up -d barazo-api barazo-web

# Verify
echo "Verifying restore..."
sleep 5
TABLE_COUNT=$(docker compose -f "$COMPOSE_FILE" exec -T postgres \
  psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';")
echo "Tables in database: $(echo "$TABLE_COUNT" | tr -d ' ')"

echo ""
echo "Restore complete at $(date)"
echo ""
echo "IMPORTANT: If this backup is older than the latest data, check the"
echo "deletion_log table and re-apply any deletions that occurred after"
echo "the backup timestamp to maintain GDPR compliance."
