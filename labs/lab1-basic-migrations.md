# Lab 1: Migration-Driven API Evolution (V001-V003)

## Objective
Learn how database migrations drive API evolution. You'll create a user profile API, then evolve the schema by renaming a column and create a v2 API while maintaining backward compatibility.

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

### Step 3: Create API v1 (User Profile)

The API code is already provided in the `api/` directory. Install dependencies:

```bash
make api-install
```

This installs:
- `express` - Web framework
- `pg` - PostgreSQL client
- `cors` - CORS middleware

The API server (`api/server.js`) provides:
- `GET /api/v1/users/:id` - Get user by ID
- `GET /api/v1/users` - Get all users

Start the API:
```bash
make api-start
```

Expected output:
```
Starting API server...
API will be available at http://localhost:3000
Press Ctrl+C to stop
API v1 running on http://localhost:3000
```

Test API v1 (in another terminal):
```bash
make api-test
```

Or manually test:
```bash
# Get user by ID
curl http://localhost:3000/api/v1/users/1

# Expected response:
# {
#   "success": true,
#   "data": {
#     "id": 1,
#     "email": "john.doe@example.com",
#     "username": "johndoe",
#     "created_at": "2026-09-30T10:00:00.000Z"
#   }
# }

# Get all users
curl http://localhost:3000/api/v1/users
```

### Step 4: Rename Email Column (BREAKING CHANGE)

Now let's see what happens when we rename a column. This demonstrates why we need safe migration patterns.

**Create migration for column rename:**

```bash
# Go back to project root
cd ..

# Create migration
make new-migration V=007 DESC=rename_email_column
```

Edit `migrations/V007__rename_email_column.sql`:

```sql
-- Migration: V007 - Rename email to email_address
-- Risk level: HIGH (BREAKING CHANGE)
-- Backward compatible: NO
-- Impact: API v1 will break, only API v2 will work

BEGIN;

-- Rename the column (this breaks existing queries!)
ALTER TABLE users RENAME COLUMN email TO email_address;

COMMIT;
```

Apply migration:
```bash
make migrate
```

Verify the column was renamed:
```bash
make psql
```

```sql
\d users
-- Should see: email_address (NOT email)

SELECT id, email_address, username FROM users LIMIT 3;
-- This works

SELECT id, email, username FROM users LIMIT 3;
-- ERROR: column "email" does not exist

\q
```

**Update API to v2 (uses new column name):**

The `api/server.js` already has both v1 and v2 endpoints. After the migration:
- v1 queries `email` column → FAILS
- v2 queries `email_address` column → WORKS

Restart the API:
```bash
# Stop the server (Ctrl+C)
node server.js
```

### Step 5: Test API v2 (v1 is now broken)

Test API v1 (should FAIL):
```bash
# This will fail because column "email" no longer exists
curl http://localhost:3000/api/v1/users/1

# Expected error:
# {
#   "error": "Internal server error - column may not exist"
# }
# 
# Server logs show:
# Error fetching user (v1): column "email" does not exist
```

Test API v2 (should WORK):
```bash
# Get user v2
curl http://localhost:3000/api/v2/users/1

# Expected:
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

# Get all users v2
curl http://localhost:3000/api/v2/users
```

**Key Lesson:** The column rename broke API v1 immediately. This is why we need safe migration patterns!

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

1. **Column renames are BREAKING CHANGES** - They immediately break existing queries
2. **API v1 broke** - Because it queried the old column name `email`
3. **API v2 works** - Because it queries the new column name `email_address`
4. **This is dangerous in production** - You need safe migration patterns
5. **Next lab** - Learn the safe way to rename columns without breaking changes

## Schema Evolution Timeline

```
Initial State (V001-V003):
  users table: id, email, username, password, created_at, updated_at
  API v1: SELECT id, email, username FROM users ✓ WORKS

After V007 Migration (BREAKING CHANGE):
  users table: id, email_address, username, password, created_at, updated_at
  API v1: SELECT id, email, username FROM users ✗ FAILS
  API v2: SELECT id, email_address, username FROM users ✓ WORKS
```

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

Proceed to **Lab 2** to learn about more advanced safe schema changes.
