# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

**Do not open a public issue for security vulnerabilities.**

Instead, use GitHub's private vulnerability reporting:

1. Go to the repository
2. Click "Security" tab
3. Click "Report a vulnerability"
4. Fill in the details

Or email: security@barazo.forum

We will respond within 72 hours with next steps.

## Security Scope for This Repo

barazo-deploy contains Docker Compose templates, Caddyfile, and operational scripts. The following areas are in scope for security reports:

### Container Security
- **Exposed ports** -- services other than Caddy (ports 80/443) reachable from external networks
- **Network segmentation bypass** -- backend services (PostgreSQL, Valkey) accessible from the frontend network
- **Privileged containers** -- containers running with elevated privileges or unnecessary capabilities
- **Non-root violations** -- containers running as root when they should not be
- **Base image vulnerabilities** -- known CVEs in the Docker images referenced by compose files

### Secret Management
- **Secrets in compose files** -- passwords, API keys, or tokens hardcoded in docker-compose.yml or Caddyfile
- **Default credentials** -- real passwords or tokens shipped as defaults (all defaults must be clearly marked as development-only)
- **.env file exposure** -- .env files committed to Git or accessible via web server
- **Backup encryption bypass** -- backup scripts producing unencrypted output when encryption is expected

### Caddy / Reverse Proxy
- **SSL misconfiguration** -- weak TLS settings, missing HSTS, expired certificates
- **Admin API exposure** -- Caddy admin API accessible externally (should be disabled with `admin off`)
- **Internal endpoint exposure** -- health check or debug endpoints reachable from outside the Docker network
- **Path traversal** -- reverse proxy routing that exposes unintended backend paths

### Operational Scripts
- **Command injection** -- user-controlled input in backup.sh, restore.sh, or smoke-test.sh reaching shell execution without sanitization
- **Unsafe file operations** -- scripts following symlinks, writing to attacker-controlled paths, or using predictable temp file names
- **Credential leakage in logs** -- scripts logging passwords or tokens to stdout/stderr

### Valkey Hardening
- **Dangerous command access** -- FLUSHALL, FLUSHDB, CONFIG, DEBUG, or KEYS commands not properly disabled
- **Authentication bypass** -- connecting to Valkey without the required password

## Security Practices

- Only Caddy exposed externally (ports 80, 443)
- Two-network segmentation (frontend + backend)
- Caddy admin API disabled (`admin off`)
- `/api/health/ready` blocked at Caddy level (internal monitoring only)
- Valkey dangerous commands renamed/disabled
- Secrets via environment variables only (never in compose files)
- `.env` in `.gitignore` (`.env.example` uses `CHANGE_ME` placeholders)
- Backup encryption via age (mandatory for off-server storage)
- Dependencies monitored weekly via Dependabot (base images + GitHub Actions)

## Disclosure Policy

We follow responsible disclosure:
- 90 days before public disclosure
- Credit given to reporter (if desired)
- CVE assigned when applicable
