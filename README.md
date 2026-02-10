<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/atgora-forum/.github/main/assets/logo-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/atgora-forum/.github/main/assets/logo-light.svg">
  <img alt="ATgora Logo" src="https://raw.githubusercontent.com/atgora-forum/.github/main/assets/logo-dark.svg" width="120">
</picture>

# atgora-deploy

**Docker Compose templates for self-hosting ATgora**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

</div>

---

## 🚧 Status: Pre-Alpha Development

Self-hosting deployment templates for ATgora forums.

**Current phase:** Planning complete, templates coming Q2 2026

---

## What is this?

The atgora-deploy repo provides everything you need to self-host an ATgora forum:

- **Docker Compose files** - Single-forum, global aggregator, staging configs
- **Environment templates** - `.env.example` with all variables documented
- **Setup scripts** - Database initialization, backups, migrations
- **Documentation** - Installation guide, upgrade guide, troubleshooting

**Goal:** `docker compose up` gets a working forum in 5 minutes.

---

## Deployment Profiles

| Profile | Use Case | File |
|---------|----------|------|
| **Single Forum** | One community forum | `docker-compose.yml` |
| **Global Aggregator** | Cross-forum feed (atgora.forum) | `docker-compose.global.yml` |
| **Development** | Local development (DB only) | `docker-compose.dev.yml` |
| **Staging** | Integration testing | `docker-compose.staging.yml` |

---

## Quick Start

**Prerequisites:**
- Docker + Docker Compose
- Domain pointing to your server
- 4 GB RAM minimum

**Deploy:**
```bash
git clone https://github.com/atgora-forum/atgora-deploy.git
cd atgora-deploy

# Configure
cp .env.example .env
nano .env  # Edit forum name, domain, etc.

# Start
docker compose up -d

# Verify
docker compose logs -f
```

Your forum will be available at `https://your-domain.com`

SSL certificates are automatic via Caddy.

---

## What's Included

**Services:**
- `atgora-api` - Backend AppView
- `atgora-web` - Frontend
- `postgres` - PostgreSQL 16 + pgvector
- `valkey` - Cache
- `caddy` - Reverse proxy + automatic SSL

**Volumes (persistent data):**
- PostgreSQL data
- Caddy SSL certificates
- Valkey cache (optional persistence)

**Networking:**
- Only Caddy exposed externally (ports 80, 443)
- Internal network for all other services

---

## Minimum Requirements

| Deployment | CPU | RAM | Storage | Bandwidth |
|------------|-----|-----|---------|-----------|
| **Single Forum** | 2 vCPU | 4 GB | 20 GB SSD | 1 TB/month |
| **Global Aggregator** | 4 vCPU | 8 GB | 100 GB SSD | 5 TB/month |

**Recommended VPS:** Hetzner CX22 (€5.83/month) or higher

---

## Upgrading

```bash
# Pull latest images
docker compose pull

# Restart with new versions
docker compose up -d

# Verify
docker compose ps
```

Database migrations run automatically on API startup.

---

## Backups

**Automated daily backups:**
```bash
# Included in deployment
./scripts/backup.sh
```

Backs up PostgreSQL to `backups/` directory. Configure cron:
```bash
0 2 * * * /path/to/atgora-deploy/scripts/backup.sh
```

---

## Documentation

- **Installation Guide:** [docs/installation.md](docs/installation.md)
- **Configuration Reference:** [docs/configuration.md](docs/configuration.md)
- **Upgrade Guide:** [docs/upgrading.md](docs/upgrading.md)
- **Troubleshooting:** [docs/troubleshooting.md](docs/troubleshooting.md)
- **Backups:** [docs/backups.md](docs/backups.md)

---

## Managed Hosting Alternative

Don't want to self-host? Managed hosting available (Phase 3):

- Automatic updates
- Backups included
- Custom domain support
- EU hosting (GDPR-compliant)

See [atgora.forum/pricing](https://atgora.forum/pricing) (coming soon)

---

## License

**MIT** - Self-hosting templates should be freely usable.

---

## Related Repositories

- **[atgora-api](https://github.com/atgora-forum/atgora-api)** - Backend (AGPL-3.0)
- **[atgora-web](https://github.com/atgora-forum/atgora-web)** - Frontend (MIT)
- **[Organization](https://github.com/atgora-forum)** - All repos

---

## Community

- 🌐 **Website:** [atgora.forum](https://atgora.forum) (coming soon)
- 💬 **Discussions:** [GitHub Discussions](https://github.com/orgs/atgora-forum/discussions)
- 🐛 **Issues:** [Report bugs](https://github.com/atgora-forum/atgora-deploy/issues)

---

© 2026 ATgora. Licensed under MIT.
