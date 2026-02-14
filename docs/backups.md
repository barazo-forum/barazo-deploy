# Backup & Restore

How to back up and restore your Barazo forum data.

## What Gets Backed Up

| Data | Backed up | Priority |
|------|-----------|----------|
| PostgreSQL (topics, replies, users, settings) | Yes | Critical |
| Valkey (cache, sessions) | No | Low -- regenerated automatically |
| Caddy (SSL certificates) | No | Medium -- re-obtained automatically by Let's Encrypt |
| Tap (firehose cursor) | No | Low -- re-syncs from the relay |
| Plugins | No | Medium -- reinstallable from npm |

The backup script creates a PostgreSQL dump. This contains all forum data (topics, replies, users, categories, settings, moderation logs).

## Creating Backups

### Manual Backup

```bash
# Unencrypted (keep on server only)
./scripts/backup.sh

# Encrypted (safe to store off-server)
./scripts/backup.sh --encrypt
```

Backups are saved to `./backups/` with filenames like `barazo-backup-20260214-020000.sql.gz`.

### Automated Backups

Add a cron job for daily backups:

```bash
crontab -e
```

```
# Daily at 2 AM, encrypted
0 2 * * * cd /path/to/barazo-deploy && ./scripts/backup.sh --encrypt >> /var/log/barazo-backup.log 2>&1
```

### Backup Encryption

Backups contain user content and potentially PII. Encrypt before storing off-server.

**Setup age encryption:**

```bash
# Generate a keypair (do this once)
age-keygen -o barazo-backup-key.txt

# The public key is printed to the terminal -- add it to .env
# BACKUP_PUBLIC_KEY="age1..."

# Store the private key file securely (NOT on the same server)
# You need this to decrypt backups
```

**Install age:**

```bash
# Ubuntu/Debian
sudo apt install age

# macOS
brew install age
```

### Backup Retention

By default, backups older than 7 days are automatically deleted. Change this with `BACKUP_RETAIN_DAYS` in `.env`:

```bash
BACKUP_RETAIN_DAYS=30   # Keep 30 days
BACKUP_RETAIN_DAYS=0    # Never delete (manage manually)
```

## Restoring from Backup

### Standard Restore

```bash
./scripts/restore.sh backups/barazo-backup-20260214-020000.sql.gz
```

### Encrypted Backup Restore

```bash
BACKUP_PRIVATE_KEY_FILE=/path/to/barazo-backup-key.txt \
  ./scripts/restore.sh backups/barazo-backup-20260214-020000.sql.gz.age
```

### What the Restore Script Does

1. Stops the API and Web services (prevents writes during restore)
2. Drops and recreates the database
3. Restores the SQL dump
4. Restarts the API and Web services
5. Verifies the database has tables

### After Restoring

**GDPR compliance:** If the backup is older than the most recent data, you must re-apply deletions that occurred after the backup date. Check the `deletion_log` table for events after the backup timestamp.

## Disaster Recovery

If your server is completely lost:

1. **Provision a new server** (same OS, Docker installed)
2. **Clone the deploy repo** and copy your `.env` file
3. **Start services:** `docker compose up -d`
4. **Restore the database** from your most recent backup
5. **Run the smoke test** to verify: `./scripts/smoke-test.sh https://your-domain.com`

Caddy will automatically obtain a new SSL certificate. The Tap service will re-sync from the relay. Valkey cache will rebuild as users access the forum.

## Verifying Backups

Periodically verify that your backups are valid:

```bash
# List backup files
ls -lh backups/

# Test a backup by restoring to a separate database
docker compose exec postgres psql -U barazo -d postgres \
  -c "CREATE DATABASE barazo_test;"
gunzip -c backups/barazo-backup-LATEST.sql.gz \
  | docker compose exec -T postgres psql -U barazo -d barazo_test -q
docker compose exec postgres psql -U barazo -d barazo_test \
  -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';"
docker compose exec postgres psql -U barazo -d postgres \
  -c "DROP DATABASE barazo_test;"
```
