#!/usr/bin/env bash
# Barazo Backup Script
#
# Creates a compressed PostgreSQL backup with timestamp.
# Optionally encrypts with age for off-server storage.
#
# Usage:
#   ./scripts/backup.sh                  # Plain backup (local storage only)
#   ./scripts/backup.sh --encrypt        # Encrypted backup (requires BACKUP_PUBLIC_KEY)
#
# Environment:
#   BACKUP_DIR          Backup directory (default: ./backups)
#   BACKUP_RETAIN_DAYS  Days to keep old backups (default: 7)
#   BACKUP_PUBLIC_KEY   age public key for encryption (required with --encrypt)
#   COMPOSE_FILE        Docker Compose file (default: docker-compose.yml)

set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-./backups}"
BACKUP_RETAIN_DAYS="${BACKUP_RETAIN_DAYS:-7}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
ENCRYPT=false

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --encrypt) ENCRYPT=true ;;
    --help|-h)
      echo "Usage: $0 [--encrypt]"
      echo ""
      echo "Options:"
      echo "  --encrypt    Encrypt backup with age (requires BACKUP_PUBLIC_KEY)"
      echo ""
      echo "Environment variables:"
      echo "  BACKUP_DIR          Backup directory (default: ./backups)"
      echo "  BACKUP_RETAIN_DAYS  Days to keep old backups (default: 7)"
      echo "  BACKUP_PUBLIC_KEY   age public key for encryption"
      echo "  COMPOSE_FILE        Docker Compose file (default: docker-compose.yml)"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

# Validate encryption prerequisites
if [ "$ENCRYPT" = true ] && [ -z "${BACKUP_PUBLIC_KEY:-}" ]; then
  echo "Error: --encrypt requires BACKUP_PUBLIC_KEY environment variable" >&2
  exit 1
fi

if [ "$ENCRYPT" = true ] && ! command -v age &>/dev/null; then
  echo "Error: age is required for encryption. Install: https://github.com/FiloSottile/age" >&2
  exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/barazo-backup-$TIMESTAMP.sql.gz"

echo "Starting backup at $(date)"

# Check PostgreSQL is running
if ! docker compose -f "$COMPOSE_FILE" exec -T postgres pg_isready -U "${POSTGRES_USER:-barazo}" &>/dev/null; then
  echo "Error: PostgreSQL is not running" >&2
  exit 1
fi

# Dump PostgreSQL
echo "Dumping PostgreSQL..."
docker compose -f "$COMPOSE_FILE" exec -T postgres \
  pg_dump -U "${POSTGRES_USER:-barazo}" "${POSTGRES_DB:-barazo}" \
  | gzip > "$BACKUP_FILE"

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "Backup created: $BACKUP_FILE ($BACKUP_SIZE)"

# Encrypt if requested
if [ "$ENCRYPT" = true ]; then
  echo "Encrypting backup..."
  age -r "$BACKUP_PUBLIC_KEY" -o "${BACKUP_FILE}.age" "$BACKUP_FILE"
  rm "$BACKUP_FILE"
  BACKUP_FILE="${BACKUP_FILE}.age"
  echo "Encrypted backup: $BACKUP_FILE"
fi

# Clean up old backups
if [ "$BACKUP_RETAIN_DAYS" -gt 0 ]; then
  DELETED=$(find "$BACKUP_DIR" -name "barazo-backup-*" -mtime +"$BACKUP_RETAIN_DAYS" -delete -print | wc -l | tr -d ' ')
  if [ "$DELETED" -gt 0 ]; then
    echo "Cleaned up $DELETED old backup(s) (older than $BACKUP_RETAIN_DAYS days)"
  fi
fi

echo "Backup complete at $(date)"
