# Barazo Deploy

Docker Compose templates for self-hosting [Barazo](https://github.com/barazo-forum) -- a federated forum on the AT Protocol.

![Status: Alpha](https://img.shields.io/badge/Status-Alpha-orange)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## Docker Compose Templates

| File | Purpose |
|------|---------|
| `docker-compose.dev.yml` | Local development -- infrastructure services only (PostgreSQL, Valkey, Tap). Run API and Web separately with `pnpm dev`. |
| `docker-compose.yml` | Production single-community deployment with automatic SSL via Caddy. Full stack. |
| `docker-compose.global.yml` | Global aggregator override -- layers on top of `docker-compose.yml` with higher resource limits and PostgreSQL tuning for indexing all communities network-wide. |

## Services

| Service | Image | Description |
|---------|-------|-------------|
| PostgreSQL 16 | `pgvector/pgvector:pg16` | Primary database with pgvector for full-text and optional semantic search |
| Valkey 8 | `valkey/valkey:8-alpine` | Redis-compatible cache for sessions, rate limiting, and queues |
| Tap | `ghcr.io/bluesky-social/indigo/tap:latest` | AT Protocol firehose consumer, filters `forum.barazo.*` records |
| Barazo API | `ghcr.io/barazo-forum/barazo-api` | AppView backend (Fastify, REST API, firehose indexing) |
| Barazo Web | `ghcr.io/barazo-forum/barazo-web` | Next.js frontend |
| Caddy | `caddy:2-alpine` | Reverse proxy with automatic SSL via Let's Encrypt, HTTP/3 support |

Production uses two-network segmentation: PostgreSQL and Valkey sit on the `backend` network only and are unreachable from Caddy or the frontend. Only ports 80 and 443 are exposed externally.

## Deployment Modes

### Development

Infrastructure services only. The API and Web containers are not included -- run those locally with `pnpm dev:api` / `pnpm dev:web`.

```bash
cp .env.example .env.dev
docker compose -f docker-compose.dev.yml up -d
```

Services exposed on the host: PostgreSQL (5432), Valkey (6379), Tap (2480).

### Production -- Single Community

Full stack deployment for one forum community with automatic SSL.

```bash
cp .env.example .env
# Edit .env: set COMMUNITY_DOMAIN, passwords, COMMUNITY_DID, OAuth settings
docker compose up -d
```

The forum will be available at `https://<COMMUNITY_DOMAIN>` once Caddy obtains the SSL certificate.

### Global Aggregator

Indexes all Barazo communities across the AT Protocol network. Uses the same codebase as single-community mode but with `COMMUNITY_MODE=global` and higher resource allocation.

```bash
cp .env.example .env
# Edit .env: set COMMUNITY_MODE=global, domain, passwords
docker compose -f docker-compose.yml -f docker-compose.global.yml up -d
```

The global override applies PostgreSQL performance tuning (`shared_buffers`, `effective_cache_size`, `work_mem`) and sets higher memory and CPU limits on all services.

**Minimum requirements:**

| Mode | CPU | RAM | Storage | Bandwidth |
|------|-----|-----|---------|-----------|
| Single Community | 2 vCPU | 4 GB | 20 GB SSD | 1 TB/month |
| Global Aggregator | 4 vCPU | 8 GB | 100 GB SSD | 5 TB/month |

## Scripts

| Script | Description |
|--------|-------------|
| `scripts/backup.sh` | Creates a compressed PostgreSQL backup with timestamp. Supports optional encryption via [age](https://github.com/FiloSottile/age) (`--encrypt` flag). Automatically cleans up backups older than `BACKUP_RETAIN_DAYS` (default: 7). |
| `scripts/restore.sh` | Restores a PostgreSQL backup from a `.sql.gz` or `.sql.gz.age` file. Stops the API and Web during restore, then restarts them. Supports encrypted backups via `BACKUP_PRIVATE_KEY_FILE`. |
| `scripts/smoke-test.sh` | Validates a running Barazo instance. Checks Docker service health, database connectivity, API endpoints, frontend response, SSL certificate, and HTTPS redirect. Works locally or against a remote URL. |

## Quick Start

```bash
git clone https://github.com/barazo-forum/barazo-deploy.git
cd barazo-deploy

# Configure
cp .env.example .env
nano .env   # Set domain, passwords, community DID, OAuth

# Start all services
docker compose up -d

# Verify
docker compose ps           # All services should show "healthy"
./scripts/smoke-test.sh     # Run smoke tests
```

## Environment Variables

All variables are documented in [`.env.example`](.env.example). Key groups:

| Group | Variables | Notes |
|-------|-----------|-------|
| Community Identity | `COMMUNITY_NAME`, `COMMUNITY_DOMAIN`, `COMMUNITY_DID`, `COMMUNITY_MODE` | `COMMUNITY_MODE` is `single` or `global` |
| Database | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `DATABASE_URL` | Change default passwords before production use |
| Cache | `VALKEY_PASSWORD`, `VALKEY_URL` | Password required in production |
| AT Protocol | `TAP_RELAY_URL`, `TAP_ADMIN_PASSWORD`, `RELAY_URL` | Default relay: `bsky.network` |
| OAuth | `OAUTH_CLIENT_ID`, `OAUTH_REDIRECT_URI` | Set to your forum's public URL |
| Frontend | `NEXT_PUBLIC_API_URL`, `NEXT_PUBLIC_SITE_URL` | As seen by the browser |
| Search | `EMBEDDING_URL`, `AI_EMBEDDING_DIMENSIONS` | Optional semantic search via Ollama or compatible API |
| Encryption | `AI_ENCRYPTION_KEY` | AES-256-GCM key for BYOK API key encryption at rest |
| Cross-Posting | `FEATURE_CROSSPOST_FRONTPAGE` | Frontpage cross-posting toggle |
| Plugins | `PLUGINS_ENABLED`, `PLUGIN_REGISTRY_URL` | Plugin system toggle and registry |
| Monitoring | `GLITCHTIP_DSN`, `LOG_LEVEL` | GlitchTip/Sentry error reporting |
| Backups | `BACKUP_PUBLIC_KEY` | age public key for encrypted backups |

## Documentation

Detailed guides are in the [`docs/`](docs/) directory:

- [Installation](docs/installation.md) -- step-by-step setup
- [Configuration](docs/configuration.md) -- all configuration options
- [Administration](docs/administration.md) -- managing your forum
- [Backups](docs/backups.md) -- backup and restore procedures
- [Upgrading](docs/upgrading.md) -- version upgrade process

## Related Repositories

- [barazo-api](https://github.com/barazo-forum/barazo-api) -- AppView backend (AGPL-3.0)
- [barazo-web](https://github.com/barazo-forum/barazo-web) -- Forum frontend (MIT)
- [barazo-lexicons](https://github.com/barazo-forum/barazo-lexicons) -- AT Protocol lexicon schemas (MIT)
- [barazo-forum](https://github.com/barazo-forum) -- GitHub organization

## License

MIT -- Self-hosting templates should be freely usable.
