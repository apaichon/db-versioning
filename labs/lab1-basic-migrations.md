# Lab 1: Breaking API Compatibility with Column Rename

## Objective
Learn why database schema changes can break existing API versions and understand the real-world impact when clients haven't migrated to new API versions yet.

## Real-World Scenario

Imagine you're running a production system with:
- **Mobile app v1.0** (100,000 users) - calls `/api/v1/users`
- **Mobile app v2.0** (10,000 users) - calls `/api/v2/users`
- **Web dashboard** - calls `/api/v1/users`
- **Third-party integrations** - call `/api/v1/users`

You want to rename the `email` column to `email_address` for clarity. What happens?

## Prerequisites
- Docker and Docker Compose installed
- Node.js 18+ installed
- Basic SQL and JavaScript knowledge

## Step-by-Step Instructions

### Step 1: Apply Migrations V001-V003

```bash
# Start PostgreSQL
make setup

# Check migration status
make status

# Apply only V001-V003 (core tables)
make migrate MAX_VERSION=003
```

Expected output:
```
Applying migrations up to V003...
  APPLY V001__create_users_table.sql ...
  APPLY V002__create_orders_table.sql ...
  APPLY V003__create_products_table.sql ...
Applied 3 migration(s).
```

Verify tables:
```bash
make psql
```

```sql
\dt
-- Should see: users, orders, products, order_items, _schema_migrations

\d users
-- Check the email column exists

\q
```

### Step 2: Seed Sample Data

```bash
make seed TABLES="users products orders order_items"
```

Expected output:
```
Summary:
 table_name | count
------------+-------
 order_items|    23
 orders     |    15
 products   |    10
 users      |    10
```

Verify data:
```bash
make psql
```

```sql
SELECT id, email, username, created_at FROM users LIMIT 5;

-- Expected:
--  id |         email          |  username   |         created_at
-- ----+------------------------+-------------+----------------------------
--   1 | john.doe@example.com   | johndoe     | 2026-09-30 10:00:00+00
--   2 | jane.smith@example.com | janesmith   | 2026-09-30 10:00:00+00
--   ...

\q
```

### Step 3: Start API v1 (Current Production)

The API code is already provided in the `api/` directory. This represents your **current production API** that all clients are using.

Install dependencies:

```bash
make api-install
```

Start the API:
```bash
make api-start
```

Expected output:
```
API server running on http://localhost:3000
  v1: /api/v1/users (uses 'email' column)
  v2: /api/v2/users (uses 'email_address' column)
```

**Current state:** All clients (mobile apps, web dashboard, integrations) are using API v1.

Test API v1 (in another terminal):
```bash
make api-test
```

Or manually test:
```bash
# Mobile app v1.0 calls this endpoint
curl http://localhost:3000/api/v1/users/1

# Expected response:
# {
#   "success": true,
#   "version": "v1",
#   "data": {
#     "id": 1,
#     "email": "john.doe@example.com",
#     "username": "johndoe",
#     "created_at": "2026-09-30T10:00:00.000Z"
#   }
# }
```

**This is working perfectly in production right now.**

### Step 4: The Breaking Change - Rename Column

Your team decides to rename `email` to `email_address` for better naming consistency. 

**The migration:**

```bash
make new-migration V=007 DESC=rename_email_column
```

Edit `migrations/V007__rename_email_column.sql`:

```sql
-- Migration: V007 - Rename email to email_address
-- Risk level: HIGH (BREAKING CHANGE)
-- Impact: All API v1 clients will BREAK

BEGIN;

-- Rename the column
ALTER TABLE users RENAME COLUMN email TO email_address;

COMMIT;
```

**Apply the migration:**
```bash
make migrate
```

**What just happened:**
- The database column `email` no longer exists
- It's now called `email_address`
- **But your API v1 code still queries `email`**

Verify the column was renamed:
```bash
make psql
```

```sql
\d users
-- Should see: email_address (NOT email)

SELECT id, email_address, username FROM users LIMIT 3;
-- ✓ This works

SELECT id, email, username FROM users LIMIT 3;
-- ✗ ERROR: column "email" does not exist

\q
```

### Step 5: Production Incident - API v1 is Down!

Restart the API server to pick up the schema change:
```bash
# Stop the server (Ctrl+C)
# Restart
make api-start
```

**Now test what your clients experience:**

**Mobile app v1.0 (100,000 users) - BROKEN:**
```bash
curl http://localhost:3000/api/v1/users/1

# Response:
# {
#   "error": "Internal server error - column may not exist"
# }
```

**Server logs show:**
```
Error fetching user (v1): column "email" does not exist
```

**Impact:**
- ✗ 100,000 mobile app v1.0 users can't log in
- ✗ Web dashboard shows errors
- ✗ Third-party integrations fail
- ✗ Support tickets flooding in

**Web dashboard - BROKEN:**
```bash
curl http://localhost:3000/api/v1/users

# Response:
# {
#   "error": "Internal server error - column may not exist"
# }
```

**Only API v2 works (but only 10,000 users have the new app):**
```bash
curl http://localhost:3000/api/v2/users/1

# Response:
# {
#   "success": true,
#   "version": "v2",
#   "data": {
#     "id": 1,
#     "email_address": "john.doe@example.com",
#     "username": "johndoe",
#     "created_at": "2026-09-30T10:00:00.000Z"
#   }
# }
```

## The Real-World Problem

**You can't just tell users to update their apps:**
- Mobile app users don't update immediately (some never do)
- Third-party integrations have their own release cycles
- Web dashboard needs time to deploy fixes
- You promised API stability to your clients

**The business impact:**
- 90% of your users are locked out
- Revenue loss from failed transactions
- Reputation damage
- Emergency rollback needed

**This is why we need safe migration patterns!**

### Step 6: Verify Schema Change

```bash
make psql
```

```sql
-- Check migration history
SELECT version, filename, applied_at
FROM _schema_migrations
ORDER BY version;

-- Verify column was renamed
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'users'
  AND column_name IN ('email', 'email_address')
ORDER BY column_name;

-- Should only see 'email_address', NOT 'email'

\q
```

### Step 7: Clean Up

```bash
# Stop API server (Ctrl+C)

# Stop containers
make down
```

## Key Takeaways

1. **Database changes have real business impact** - A simple column rename broke 90% of your users
2. **You can't force immediate client updates** - Mobile apps, third-party integrations, and web dashboards have their own timelines
3. **API compatibility is a contract** - Once you publish an API version, clients depend on it
4. **Breaking changes cause outages** - 100,000 users locked out = major incident
5. **Safe migration patterns are essential** - In Lab 2, you'll learn how to rename columns without breaking existing APIs

## What Should Have Been Done?

Instead of directly renaming the column, you should:

1. **Add new column** `email_address` (keep old `email` column)
2. **Copy data** from `email` to `email_address`
3. **Deploy API v2** that uses `email_address`
4. **Wait** for clients to migrate to API v2 (months or years)
5. **Monitor** API v1 usage
6. **Only then** deprecate and remove API v1
7. **Finally** drop the old `email` column

This is called the **"Expand and Contract"** pattern, and you'll learn it in Lab 2.

## The Timeline Problem

```
Day 1: You rename the column
  └─ Database: email → email_address
  
Day 1: API v1 breaks immediately
  ├─ Mobile app v1.0 (100k users): BROKEN ✗
  ├─ Web dashboard: BROKEN ✗
  ├─ Third-party APIs: BROKEN ✗
  └─ Mobile app v2.0 (10k users): Works ✓

Day 30: Most users still haven't updated
  ├─ Mobile app v1.0 (80k users): Still broken ✗
  ├─ Web dashboard: Fixed (after emergency deploy)
  ├─ Third-party APIs: Some fixed, some still broken
  └─ Mobile app v2.0 (30k users): Works ✓

Day 90: Long tail of users
  ├─ Mobile app v1.0 (20k users): Never updated ✗
  ├─ Some third-party APIs: Still using v1
  └─ You must support BOTH versions
```

**The lesson:** You can't break old API versions until ALL clients have migrated, which can take months or years.

## Common Commands

| Command | Description |
|---------|-------------|
| `make setup` | Start PostgreSQL |
| `make migrate` | Apply all migrations |
| `make seed` | Insert sample data |
| `make status` | Show migration status |
| `make psql` | Open database shell |
| `node api/server.js` | Start API server |

## Troubleshooting

**API won't start:**
```bash
# Check if port 3000 is in use
lsof -i :3000

# Kill the process or change PORT in server.js
```

**Database connection error:**
```bash
# Check if PostgreSQL is running
docker compose ps

# Restart if needed
make reset
```

**Migration fails:**
```bash
# Check error message
# Fix the SQL
# Reset and retry
make reset
make migrate
```

## Next Steps

**Lab 2** will teach you the **safe way** to rename columns:
- Use the "Expand and Contract" pattern
- Keep both old and new columns during transition
- Support both API v1 and v2 simultaneously
- Gradually migrate clients to the new API
- Only remove old columns after all clients have migrated

This ensures **zero downtime** and **no breaking changes** for your users.
