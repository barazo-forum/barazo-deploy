<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/barazo-forum/.github/main/assets/logo-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/barazo-forum/.github/main/assets/logo-light.svg">
  <img alt="Barazo Logo" src="https://raw.githubusercontent.com/barazo-forum/.github/main/assets/logo-dark.svg" width="120">
</picture>

# barazo-deploy

**Docker Compose templates for deploying Barazo**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

</div>

---

## What is this?

Docker Compose configurations and documentation for running Barazo -- a federated forum on the AT Protocol.

**Available profiles:**

| Profile | Use Case | File | Status |
|---------|----------|------|--------|
| **Development** | Local dev (infrastructure only) | `docker-compose.dev.yml` | Available |
| **Single Forum** | One community, production | `docker-compose.yml` | Planned |
| **Global Aggregator** | Cross-community aggregator | `docker-compose.global.yml` | Planned |

---

## Development Setup

The dev compose provides infrastructure services for local development of `barazo-api` and `barazo-web`. It does **not** include the API or web containers -- run those separately with `pnpm dev:api` / `pnpm dev:web`.

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (v24+) with Docker Compose v2
- [Node.js](https://nodejs.org/) 24 LTS and [pnpm](https://pnpm.io/) (for running API/web locally)

### Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| **postgres** | `pgvector/pgvector:pg16` | 5432 | PostgreSQL 16 with pgvector for full-text and semantic search |
| **valkey** | `valkey/valkey:8-alpine` | 6379 | Redis-compatible cache for sessions, rate limiting, queues |
| **tap** | `ghcr.io/bluesky-social/indigo/tap:latest` | 2480 | AT Protocol firehose consumer (filters `forum.barazo.*` records) |

### Quick Start

```bash
# Clone the deploy repo (or use from monorepo workspace)
cd barazo-deploy

# Copy environment template
cp .env.example .env.dev

# Start infrastructure
docker compose -f docker-compose.dev.yml up -d

# Verify all services are healthy
docker compose -f docker-compose.dev.yml ps
```

All three services should show `healthy` status within 30 seconds.

### From the Monorepo Workspace

If using the pnpm workspace at `~/Documents/Git/barazo-forum/`:

```bash
# Start infrastructure (references barazo-deploy/docker-compose.dev.yml)
pnpm dev:infra

# Stop infrastructure
pnpm dev:infra:down

# View logs
pnpm dev:infra:logs
```

### Common Commands

```bash
# Start all services
docker compose -f docker-compose.dev.yml up -d

# Stop all services (preserves data)
docker compose -f docker-compose.dev.yml down

# Stop and remove all data volumes
docker compose -f docker-compose.dev.yml down -v

# View logs (all services)
docker compose -f docker-compose.dev.yml logs -f

# View logs (single service)
docker compose -f docker-compose.dev.yml logs -f postgres

# Restart a single service
docker compose -f docker-compose.dev.yml restart valkey

# Connect to PostgreSQL
docker compose -f docker-compose.dev.yml exec postgres psql -U barazo
```

### Environment Variables

All variables have sensible defaults for development. Override them in `.env.dev`:

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_USER` | `barazo` | PostgreSQL superuser name |
| `POSTGRES_PASSWORD` | `barazo_dev` | PostgreSQL superuser password |
| `POSTGRES_DB` | `barazo` | Database name |
| `POSTGRES_PORT` | `5432` | Host port for PostgreSQL |
| `VALKEY_PORT` | `6379` | Host port for Valkey |
| `TAP_RELAY_URL` | `https://bsky.network` | AT Protocol relay URL |
| `TAP_PORT` | `2480` | Host port for Tap admin API |
| `TAP_ADMIN_PASSWORD` | `tap_dev_secret` | Tap admin API password |

See [`.env.example`](.env.example) for the full list including production variables.

### Troubleshooting

**Port already in use:**

If port 5432, 6379, or 2480 is occupied, change the host port mapping in `.env.dev`:

```bash
POSTGRES_PORT=5433
VALKEY_PORT=6380
TAP_PORT=2481
```

**PostgreSQL won't start:**

Check if an existing volume has incompatible data:

```bash
docker compose -f docker-compose.dev.yml down -v
docker compose -f docker-compose.dev.yml up -d
```

Warning: `-v` deletes all data. Back up first if needed.

**Tap fails on Apple Silicon:**

Tap uses `platform: linux/amd64`. Docker Desktop on Apple Silicon runs it via Rosetta emulation. If it crashes:

1. Verify Docker Desktop has Rosetta enabled (Settings > General > "Use Rosetta")
2. Restart Docker Desktop
3. Try again: `docker compose -f docker-compose.dev.yml up -d tap`

**Containers start but API can't connect:**

Verify the services are healthy:

```bash
docker compose -f docker-compose.dev.yml ps
```

If a service shows `starting` or `unhealthy`, check its logs:

```bash
docker compose -f docker-compose.dev.yml logs postgres
```

---

## Production Deployment

Production Docker Compose with Caddy SSL, two-network segmentation, and health checks will be added in a future release.

### Minimum Requirements

| Deployment | CPU | RAM | Storage | Bandwidth |
|------------|-----|-----|---------|-----------|
| **Single Forum** | 2 vCPU | 4 GB | 20 GB SSD | 1 TB/month |
| **Global Aggregator** | 4 vCPU | 8 GB | 100 GB SSD | 5 TB/month |

**Recommended VPS:** Hetzner CX22 or higher.

---

## License

**MIT** -- Self-hosting templates should be freely usable.

---

## Related Repositories

- **[barazo-api](https://github.com/barazo-forum/barazo-api)** -- Backend (AGPL-3.0)
- **[barazo-web](https://github.com/barazo-forum/barazo-web)** -- Frontend (MIT)
- **[barazo-lexicons](https://github.com/barazo-forum/barazo-lexicons)** -- AT Protocol lexicon schemas (MIT)
- **[Organization](https://github.com/barazo-forum)** -- All repos

---

(c) 2026 Barazo. Licensed under MIT.
