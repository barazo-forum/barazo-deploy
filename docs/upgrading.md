# Upgrade Guide

How to upgrade your Barazo installation to a new version.

## Standard Upgrade

```bash
cd barazo-deploy

# Pull new images
docker compose pull

# Restart with new versions
docker compose up -d

# Verify
docker compose ps
./scripts/smoke-test.sh https://your-domain.com
```

Database migrations run automatically when the API starts. No manual migration step is needed.

## Pinned Version Upgrade

If you pin image versions in `.env` (recommended for production):

```bash
# Edit .env to update versions
nano .env
# Change BARAZO_API_VERSION=1.2.3 to BARAZO_API_VERSION=1.3.0
# Change BARAZO_WEB_VERSION=1.2.3 to BARAZO_WEB_VERSION=1.3.0

# Pull and restart
docker compose pull
docker compose up -d
```

## Pre-Upgrade Checklist

1. **Read the changelog** for the new version -- check for breaking changes
2. **Create a backup** before upgrading:
   ```bash
   ./scripts/backup.sh
   ```
3. **Test on staging first** if you have a staging environment

## Rollback

If the upgrade causes issues:

```bash
# Stop services
docker compose down

# Edit .env to revert to previous version
nano .env
# Change versions back to previous values

# Pull previous images
docker compose pull

# Restore database from pre-upgrade backup
./scripts/restore.sh backups/barazo-backup-YYYYMMDD-HHMMSS.sql.gz

# Start services
docker compose up -d

# Verify
docker compose ps
```

## Breaking Changes

Major version bumps (e.g., 1.x to 2.x) may include breaking changes that require manual steps. These are documented in the release notes and CHANGELOG.md.

Common breaking changes to watch for:
- **Environment variable renames** -- update your `.env` file
- **Database schema changes** -- migrations run automatically, but rollback may require the backup
- **Caddy configuration changes** -- check if Caddyfile needs updates
