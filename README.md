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
| **Single Forum** | One community, production | `docker-compose.yml` | Available |
| **Global Aggregator** | Cross-community aggregator | `docker-compose.global.yml` | Available |

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

Deploy a single Barazo community with automatic SSL via Caddy.

### Quick Start (Production)

```bash
git clone https://github.com/barazo-forum/barazo-deploy.git
cd barazo-deploy

# Configure
cp .env.example .env
nano .env  # Set domain, passwords, community DID, etc.

# Start
docker compose up -d

# Verify
docker compose ps        # All services should be "healthy"
docker compose logs -f   # Watch startup logs
```

Your forum will be available at `https://your-domain.com` once Caddy obtains the SSL certificate (automatic via Let's Encrypt).

### Production Services

| Service | Image | Network | Purpose |
|---------|-------|---------|---------|
| **caddy** | `caddy:2-alpine` | frontend | Reverse proxy, automatic SSL (only exposed service: ports 80, 443) |
| **barazo-api** | `ghcr.io/barazo-forum/barazo-api` | frontend + backend | AppView backend (Fastify, REST API, firehose indexing) |
| **barazo-web** | `ghcr.io/barazo-forum/barazo-web` | frontend | Next.js frontend |
| **postgres** | `pgvector/pgvector:pg16` | backend | PostgreSQL 16 with pgvector |
| **valkey** | `valkey/valkey:8-alpine` | backend | Redis-compatible cache |
| **tap** | `ghcr.io/bluesky-social/indigo/tap` | backend | AT Protocol firehose consumer |

Two-network segmentation: PostgreSQL and Valkey are on the `backend` network only, unreachable from Caddy or the frontend.

### Headless API (No Frontend)

To run without the frontend container (e.g., custom frontend or API-only access):

```bash
docker compose up -d postgres valkey tap caddy barazo-api
```

Update the Caddyfile to remove or adjust the frontend route as needed.

---

## Global Aggregator

The global aggregator indexes **all** Barazo communities across the AT Protocol network. It uses the same codebase as a single community but with different configuration and higher resource allocation.

### Differences from Single Community

| Aspect | Single Community | Global Aggregator |
|--------|-----------------|-------------------|
| `COMMUNITY_MODE` | `single` | `global` |
| Indexes | One community's records | All `forum.barazo.*` records network-wide |
| Features | Standard forum | Cross-community search, reputation aggregation |
| PostgreSQL | 1 GB RAM | 4 GB RAM (more data) |
| API | 1 GB RAM | 2 GB RAM (more indexing) |
| Minimum server | 2 vCPU / 4 GB RAM | 4 vCPU / 8 GB RAM |

### Quick Start (Global Aggregator)

```bash
cp .env.example .env
nano .env  # Set COMMUNITY_MODE=global, domain, passwords

# Start with the global override
docker compose -f docker-compose.yml -f docker-compose.global.yml up -d
```

The global override file (`docker-compose.global.yml`) layers on top of the production compose to:
- Set `COMMUNITY_MODE=global` on the API
- Apply PostgreSQL performance tuning (`shared_buffers`, `effective_cache_size`, `work_mem`)
- Set higher memory and CPU limits on all services

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
