#!/usr/bin/env bash
# Barazo Staging Reset Script
#
# Drops and recreates the staging database, then restarts all services.
# Only for use on the staging environment -- never run this on production.
#
# Usage:
#   ./scripts/reset-staging.sh              # Reset with confirmation prompt
#   ./scripts/reset-staging.sh --force      # Reset without confirmation
#
# What it does:
#   1. Stops API and Web services (keeps postgres/valkey running)
#   2. Drops and recreates the staging database
#   3. Restarts all services (schema is applied on startup)
#
# Environment:
#   COMPOSE_FILE  Docker Compose files (default: docker-compose.yml -f docker-compose.staging.yml)

set -euo pipefail

COMPOSE_CMD="docker compose -f docker-compose.yml -f docker-compose.staging.yml"
FORCE=false

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    --help|-h)
      echo "Usage: $0 [--force]"
      echo ""
      echo "Drops and recreates the staging database, then restarts services."
      echo ""
      echo "Options:"
      echo "  --force    Skip confirmation prompt"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

# Safety check: refuse to run if NODE_ENV=production is detected
if [ "${NODE_ENV:-}" = "production" ]; then
  echo "Error: NODE_ENV is set to 'production'. This script is for staging only." >&2
  exit 1
fi

# Confirmation prompt
if [ "$FORCE" = false ]; then
  echo "WARNING: This will destroy ALL data in the staging database."
  echo ""
  read -r -p "Are you sure? Type 'reset staging' to confirm: " CONFIRM
  if [ "$CONFIRM" != "reset staging" ]; then
    echo "Aborted."
    exit 0
  fi
fi

echo ""
echo "Resetting staging environment..."
echo ""

# Load .env for database credentials
if [ -f .env ]; then
  # shellcheck disable=SC2046
  export $(grep -v '^#' .env | grep -v '^\s*$' | xargs)
fi

DB_NAME="${POSTGRES_DB:-barazo_staging}"
DB_USER="${POSTGRES_USER:-barazo}"

# Step 1: Stop application services (keep infrastructure running)
echo "Stopping application services..."
$COMPOSE_CMD stop barazo-api barazo-web caddy

# Step 2: Drop and recreate database
echo "Dropping database '$DB_NAME'..."
$COMPOSE_CMD exec -T postgres psql -U "$DB_USER" -d postgres \
  -c "DROP DATABASE IF EXISTS \"$DB_NAME\";"

echo "Creating database '$DB_NAME'..."
$COMPOSE_CMD exec -T postgres psql -U "$DB_USER" -d postgres \
  -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";"

# Enable pgvector extension
echo "Enabling pgvector extension..."
$COMPOSE_CMD exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" \
  -c "CREATE EXTENSION IF NOT EXISTS vector;"

# Step 3: Flush Valkey cache
echo "Flushing Valkey cache..."
# Use FLUSHALL via direct redis protocol since the command is renamed in production compose.
# On staging, we restart valkey instead to clear all data.
$COMPOSE_CMD restart valkey

# Step 4: Restart all services (schema is applied on startup)
echo "Starting all services..."
$COMPOSE_CMD up -d

echo ""
echo "Waiting for services to become healthy..."
sleep 10

# Check health
if $COMPOSE_CMD exec -T postgres pg_isready -U "$DB_USER" &>/dev/null; then
  echo "  PostgreSQL: healthy"
else
  echo "  PostgreSQL: NOT healthy" >&2
fi

echo ""
echo "Staging reset complete."
echo "The database schema will be applied automatically on startup."
echo ""
echo "To seed test data, run: ./scripts/seed-staging.sh"
