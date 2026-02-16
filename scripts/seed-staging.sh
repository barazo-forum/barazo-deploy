#!/usr/bin/env bash
# Barazo Staging Seed Script
#
# Populates the staging database with test data for development and QA.
# Run after reset-staging.sh or on a fresh staging deployment.
#
# Usage:
#   ./scripts/seed-staging.sh                # Seed all test data
#   ./scripts/seed-staging.sh --minimal      # Seed only categories (faster)
#
# What it creates:
#   - 5 categories (General, Feedback, Development, AT Protocol, Off-Topic)
#   - 3 test users (admin, moderator, member) with known DIDs
#   - 10 sample topics across categories
#   - 30 sample replies
#   - Sample reactions
#
# Prerequisites:
#   - Staging services must be running
#   - Database must have migrations applied (API does this on startup)
#
# Environment:
#   COMPOSE_CMD   Docker Compose command override

set -euo pipefail

COMPOSE_CMD="${COMPOSE_CMD:-docker compose -f docker-compose.yml -f docker-compose.staging.yml}"
MINIMAL=false

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --minimal) MINIMAL=true ;;
    --help|-h)
      echo "Usage: $0 [--minimal]"
      echo ""
      echo "Seeds the staging database with test data."
      echo ""
      echo "Options:"
      echo "  --minimal    Only create categories (skip users, topics, replies)"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

# Load .env for database credentials
if [ -f .env ]; then
  # shellcheck disable=SC2046
  export $(grep -v '^#' .env | grep -v '^\s*$' | xargs)
fi

DB_NAME="${POSTGRES_DB:-barazo_staging}"
DB_USER="${POSTGRES_USER:-barazo}"

# Verify PostgreSQL is running
if ! $COMPOSE_CMD exec -T postgres pg_isready -U "$DB_USER" &>/dev/null; then
  echo "Error: PostgreSQL is not running. Start services first:" >&2
  echo "  docker compose -f docker-compose.yml -f docker-compose.staging.yml up -d" >&2
  exit 1
fi

echo "Seeding staging database..."
echo ""

# --- Categories ---
echo "Creating categories..."
$COMPOSE_CMD exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" <<'SQL'
INSERT INTO categories (slug, name, description, sort_order, created_at, updated_at)
VALUES
  ('general',      'General',      'General discussion about anything',               1, NOW(), NOW()),
  ('feedback',     'Feedback',     'Feature requests, bug reports, and suggestions',   2, NOW(), NOW()),
  ('development',  'Development',  'Technical discussions about building with Barazo', 3, NOW(), NOW()),
  ('atproto',      'AT Protocol',  'AT Protocol ecosystem, standards, and tooling',    4, NOW(), NOW()),
  ('off-topic',    'Off-Topic',    'Casual conversations and community hangout',       5, NOW(), NOW())
ON CONFLICT (slug) DO NOTHING;
SQL
echo "  Categories created."

if [ "$MINIMAL" = true ]; then
  echo ""
  echo "Minimal seed complete (categories only)."
  exit 0
fi

# --- Test Users ---
echo "Creating test users..."
$COMPOSE_CMD exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" <<'SQL'
INSERT INTO users (did, handle, display_name, role, created_at, updated_at)
VALUES
  ('did:plc:staging-admin-001',     'staging-admin.bsky.social',     'Staging Admin',     'admin',     NOW(), NOW()),
  ('did:plc:staging-moderator-001', 'staging-mod.bsky.social',       'Staging Moderator', 'moderator', NOW(), NOW()),
  ('did:plc:staging-member-001',    'staging-member.bsky.social',    'Staging Member',    'member',    NOW(), NOW()),
  ('did:plc:staging-member-002',    'staging-member2.bsky.social',   'Test User Two',     'member',    NOW(), NOW()),
  ('did:plc:staging-member-003',    'staging-member3.bsky.social',   'Test User Three',   'member',    NOW(), NOW())
ON CONFLICT (did) DO NOTHING;
SQL
echo "  Test users created."

# --- Topics ---
echo "Creating sample topics..."
$COMPOSE_CMD exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" <<'SQL'
-- Get user and category IDs for reference
WITH admin_user AS (SELECT id FROM users WHERE did = 'did:plc:staging-admin-001' LIMIT 1),
     mod_user AS (SELECT id FROM users WHERE did = 'did:plc:staging-moderator-001' LIMIT 1),
     member_user AS (SELECT id FROM users WHERE did = 'did:plc:staging-member-001' LIMIT 1),
     general_cat AS (SELECT id FROM categories WHERE slug = 'general' LIMIT 1),
     feedback_cat AS (SELECT id FROM categories WHERE slug = 'feedback' LIMIT 1),
     dev_cat AS (SELECT id FROM categories WHERE slug = 'development' LIMIT 1),
     atproto_cat AS (SELECT id FROM categories WHERE slug = 'atproto' LIMIT 1),
     offtopic_cat AS (SELECT id FROM categories WHERE slug = 'off-topic' LIMIT 1)
INSERT INTO topics (title, slug, body, author_id, category_id, created_at, updated_at)
VALUES
  ('Welcome to Barazo Staging',
   'welcome-to-barazo-staging',
   'This is the staging instance of Barazo, used for testing and development. Feel free to create topics and test features.',
   (SELECT id FROM admin_user), (SELECT id FROM general_cat), NOW() - INTERVAL '7 days', NOW() - INTERVAL '7 days'),

  ('How to report bugs',
   'how-to-report-bugs',
   'Found a bug? Describe what you expected to happen, what actually happened, and steps to reproduce.',
   (SELECT id FROM admin_user), (SELECT id FROM feedback_cat), NOW() - INTERVAL '6 days', NOW() - INTERVAL '6 days'),

  ('Getting started with the Barazo API',
   'getting-started-barazo-api',
   'The Barazo API is a RESTful API built with Fastify. You can explore the API documentation at /docs.',
   (SELECT id FROM mod_user), (SELECT id FROM dev_cat), NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days'),

  ('AT Protocol identity and portability',
   'atproto-identity-portability',
   'One of the key features of building on AT Protocol is portable identity. Your DID stays with you across communities.',
   (SELECT id FROM mod_user), (SELECT id FROM atproto_cat), NOW() - INTERVAL '4 days', NOW() - INTERVAL '4 days'),

  ('Favorite open source projects?',
   'favorite-open-source-projects',
   'What open source projects are you excited about right now? Share your favorites!',
   (SELECT id FROM member_user), (SELECT id FROM offtopic_cat), NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days'),

  ('Feature request: dark mode improvements',
   'feature-request-dark-mode',
   'The dark mode is great but could use some contrast improvements in the sidebar and category labels.',
   (SELECT id FROM member_user), (SELECT id FROM feedback_cat), NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days'),

  ('Understanding the firehose and Tap',
   'understanding-firehose-tap',
   'Tap filters the AT Protocol firehose for forum.barazo.* records. Here is how it works and why it matters.',
   (SELECT id FROM admin_user), (SELECT id FROM dev_cat), NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days'),

  ('Cross-community reputation design',
   'cross-community-reputation',
   'How should reputation work across multiple Barazo communities? Let us discuss the design considerations.',
   (SELECT id FROM mod_user), (SELECT id FROM atproto_cat), NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day'),

  ('Self-hosting Barazo on a Raspberry Pi',
   'self-hosting-raspberry-pi',
   'Has anyone tried running Barazo on a Raspberry Pi? Curious about the performance on ARM hardware.',
   (SELECT id FROM member_user), (SELECT id FROM general_cat), NOW() - INTERVAL '12 hours', NOW() - INTERVAL '12 hours'),

  ('Weekend project ideas',
   'weekend-project-ideas',
   'Looking for weekend project ideas that integrate with AT Protocol. What are you building?',
   (SELECT id FROM member_user), (SELECT id FROM offtopic_cat), NOW() - INTERVAL '6 hours', NOW() - INTERVAL '6 hours')
ON CONFLICT DO NOTHING;
SQL
echo "  Sample topics created."

# --- Replies ---
echo "Creating sample replies..."
$COMPOSE_CMD exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" <<'SQL'
WITH admin_user AS (SELECT id FROM users WHERE did = 'did:plc:staging-admin-001' LIMIT 1),
     mod_user AS (SELECT id FROM users WHERE did = 'did:plc:staging-moderator-001' LIMIT 1),
     member_user AS (SELECT id FROM users WHERE did = 'did:plc:staging-member-001' LIMIT 1),
     member2_user AS (SELECT id FROM users WHERE did = 'did:plc:staging-member-002' LIMIT 1),
     member3_user AS (SELECT id FROM users WHERE did = 'did:plc:staging-member-003' LIMIT 1),
     welcome_topic AS (SELECT id FROM topics WHERE slug = 'welcome-to-barazo-staging' LIMIT 1),
     bugs_topic AS (SELECT id FROM topics WHERE slug = 'how-to-report-bugs' LIMIT 1),
     api_topic AS (SELECT id FROM topics WHERE slug = 'getting-started-barazo-api' LIMIT 1),
     identity_topic AS (SELECT id FROM topics WHERE slug = 'atproto-identity-portability' LIMIT 1),
     oss_topic AS (SELECT id FROM topics WHERE slug = 'favorite-open-source-projects' LIMIT 1),
     dark_topic AS (SELECT id FROM topics WHERE slug = 'feature-request-dark-mode' LIMIT 1)
INSERT INTO replies (body, author_id, topic_id, created_at, updated_at)
VALUES
  -- Welcome topic replies
  ('Great to see the staging environment up and running!',
   (SELECT id FROM mod_user), (SELECT id FROM welcome_topic), NOW() - INTERVAL '6 days 23 hours', NOW() - INTERVAL '6 days 23 hours'),
  ('Testing the reply functionality. Markdown **bold** and *italic* work well.',
   (SELECT id FROM member_user), (SELECT id FROM welcome_topic), NOW() - INTERVAL '6 days 20 hours', NOW() - INTERVAL '6 days 20 hours'),
  ('Confirmed everything looks good on mobile too.',
   (SELECT id FROM member2_user), (SELECT id FROM welcome_topic), NOW() - INTERVAL '6 days 18 hours', NOW() - INTERVAL '6 days 18 hours'),

  -- Bug report topic replies
  ('I can help triage bugs as they come in.',
   (SELECT id FROM mod_user), (SELECT id FROM bugs_topic), NOW() - INTERVAL '5 days 22 hours', NOW() - INTERVAL '5 days 22 hours'),
  ('Is there a template for bug reports?',
   (SELECT id FROM member_user), (SELECT id FROM bugs_topic), NOW() - INTERVAL '5 days 20 hours', NOW() - INTERVAL '5 days 20 hours'),
  ('Not yet, but that is a good idea. Will add one.',
   (SELECT id FROM admin_user), (SELECT id FROM bugs_topic), NOW() - INTERVAL '5 days 18 hours', NOW() - INTERVAL '5 days 18 hours'),

  -- API topic replies
  ('The Fastify integration is really clean. Love the Zod validation.',
   (SELECT id FROM member_user), (SELECT id FROM api_topic), NOW() - INTERVAL '4 days 20 hours', NOW() - INTERVAL '4 days 20 hours'),
  ('How does rate limiting work on the API?',
   (SELECT id FROM member2_user), (SELECT id FROM api_topic), NOW() - INTERVAL '4 days 16 hours', NOW() - INTERVAL '4 days 16 hours'),
  ('Rate limiting uses a sliding window stored in Valkey. Configurable per endpoint.',
   (SELECT id FROM admin_user), (SELECT id FROM api_topic), NOW() - INTERVAL '4 days 14 hours', NOW() - INTERVAL '4 days 14 hours'),

  -- Identity topic replies
  ('This is the killer feature of AT Protocol-based forums.',
   (SELECT id FROM member_user), (SELECT id FROM identity_topic), NOW() - INTERVAL '3 days 20 hours', NOW() - INTERVAL '3 days 20 hours'),
  ('Can I use my existing Bluesky handle to sign in?',
   (SELECT id FROM member3_user), (SELECT id FROM identity_topic), NOW() - INTERVAL '3 days 16 hours', NOW() - INTERVAL '3 days 16 hours'),
  ('Yes! Any AT Protocol account works via OAuth. Bluesky, Blacksky, self-hosted PDS, all supported.',
   (SELECT id FROM mod_user), (SELECT id FROM identity_topic), NOW() - INTERVAL '3 days 14 hours', NOW() - INTERVAL '3 days 14 hours'),

  -- OSS topic replies
  ('Valkey has been great as a Redis replacement.',
   (SELECT id FROM mod_user), (SELECT id FROM oss_topic), NOW() - INTERVAL '2 days 20 hours', NOW() - INTERVAL '2 days 20 hours'),
  ('I have been enjoying Caddy for reverse proxy. So much simpler than nginx.',
   (SELECT id FROM member2_user), (SELECT id FROM oss_topic), NOW() - INTERVAL '2 days 16 hours', NOW() - INTERVAL '2 days 16 hours'),
  ('Drizzle ORM is another good one. TypeScript-first database queries.',
   (SELECT id FROM admin_user), (SELECT id FROM oss_topic), NOW() - INTERVAL '2 days 12 hours', NOW() - INTERVAL '2 days 12 hours'),

  -- Dark mode topic replies
  ('Agreed on the sidebar contrast. The category pills are hard to read in dark mode.',
   (SELECT id FROM mod_user), (SELECT id FROM dark_topic), NOW() - INTERVAL '1 day 20 hours', NOW() - INTERVAL '1 day 20 hours'),
  ('We use Radix Colors which should handle this well. Will investigate.',
   (SELECT id FROM admin_user), (SELECT id FROM dark_topic), NOW() - INTERVAL '1 day 16 hours', NOW() - INTERVAL '1 day 16 hours'),
  ('Maybe the Flexoki accent hues need adjustment for the dark palette.',
   (SELECT id FROM member3_user), (SELECT id FROM dark_topic), NOW() - INTERVAL '1 day 12 hours', NOW() - INTERVAL '1 day 12 hours')
ON CONFLICT DO NOTHING;
SQL
echo "  Sample replies created."

# --- Update topic reply counts ---
echo "Updating topic reply counts..."
$COMPOSE_CMD exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" <<'SQL'
UPDATE topics SET reply_count = (
  SELECT COUNT(*) FROM replies WHERE replies.topic_id = topics.id
);
SQL
echo "  Reply counts updated."

echo ""
echo "Staging seed complete."
echo ""
echo "Test users:"
echo "  Admin:     did:plc:staging-admin-001     (staging-admin.bsky.social)"
echo "  Moderator: did:plc:staging-moderator-001 (staging-mod.bsky.social)"
echo "  Member:    did:plc:staging-member-001    (staging-member.bsky.social)"
echo "  Member 2:  did:plc:staging-member-002    (staging-member2.bsky.social)"
echo "  Member 3:  did:plc:staging-member-003    (staging-member3.bsky.social)"
echo ""
echo "Categories: general, feedback, development, atproto, off-topic"
echo "Topics: 10 | Replies: 18"
