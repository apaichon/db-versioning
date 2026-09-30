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

Create the API project:

```bash
mkdir -p api
cd api
npm init -y
npm install express pg cors
```

Create `api/server.js`:

```javascript
const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// Database connection
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER || 'tutorial',
  password: process.env.DB_PASSWORD || 'tutorial_secret',
  database: process.env.DB_NAME || 'app_db',
});

// API v1: Get user profile
// Returns: id, email, username, created_at
app.get('/api/v1/users/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      'SELECT id, email, username, created_at FROM users WHERE id = $1',
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({
      success: true,
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error fetching user:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get all users (v1)
app.get('/api/v1/users', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, email, username, created_at FROM users ORDER BY id LIMIT 10'
    );

    res.json({
      success: true,
      count: result.rows.length,
      data: result.rows
    });
  } catch (error) {
    console.error('Error fetching users:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`API v1 running on http://localhost:${PORT}`);
});
```

Start the API:
```bash
cd api
node server.js
```

Test API v1:
```bash
# In another terminal
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

### Step 4: Rename Email Column & Create API v2

Now let's evolve the schema. We want to rename `email` to `email_address` for clarity.

**Create migration for column rename (safe pattern):**

```bash
# Go back to project root
cd ..

# Create migration
make new-migration V=007 DESC=rename_email_to_email_address
```

Edit `migrations/V007__rename_email_to_email_address.sql`:

```sql
-- Migration: V007 - Rename email to email_address
-- Risk level: MEDIUM
-- Backward compatible: YES (using multi-step pattern)
-- Rollback strategy: Reverse the rename

BEGIN;

-- Step 1: Add new column
ALTER TABLE users ADD COLUMN email_address VARCHAR(255);

-- Step 2: Copy data from old column
UPDATE users SET email_address = email;

-- Step 3: Add unique constraint to new column
ALTER TABLE users ADD CONSTRAINT users_email_address_unique UNIQUE (email_address);

-- Note: In a real scenario, you would:
-- 1. Deploy this migration
-- 2. Update application to use email_address
-- 3. Deploy application
-- 4. In next migration, drop old email column

COMMIT;
```

Apply migration:
```bash
make migrate
```

Verify:
```bash
make psql
```

```sql
\d users
-- Should see both email and email_address columns

SELECT id, email, email_address, username FROM users LIMIT 3;
-- Both columns should have the same data

\q
```

**Update API to add v2:**

Edit `api/server.js` and add v2 endpoints:

```javascript
// Add these routes BEFORE the v1 routes

// API v2: Get user profile (uses email_address)
app.get('/api/v2/users/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      'SELECT id, email_address AS email, username, created_at FROM users WHERE id = $1',
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({
      success: true,
      version: 'v2',
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error fetching user:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get all users (v2)
app.get('/api/v2/users', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, email_address AS email, username, created_at FROM users ORDER BY id LIMIT 10'
    );

    res.json({
      success: true,
      version: 'v2',
      count: result.rows.length,
      data: result.rows
    });
  } catch (error) {
    console.error('Error fetching users:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});
```

Restart the API:
```bash
# Stop the server (Ctrl+C)
node server.js
```

### Step 5: Test Both APIs (v1 and v2)

Test API v1 (still uses old `email` column):
```bash
# Get user v1
curl http://localhost:3000/api/v1/users/1

# Expected:
# {
#   "success": true,
#   "data": {
#     "id": 1,
#     "email": "john.doe@example.com",
#     "username": "johndoe",
#     "created_at": "2026-09-30T10:00:00.000Z"
#   }
# }

# Get all users v1
curl http://localhost:3000/api/v1/users
```

Test API v2 (uses new `email_address` column):
```bash
# Get user v2
curl http://localhost:3000/api/v2/users/1

# Expected:
# {
#   "success": true,
#   "version": "v2",
#   "data": {
#     "id": 1,
#     "email": "john.doe@example.com",
#     "username": "johndoe",
#     "created_at": "2026-09-30T10:00:00.000Z"
#   }
# }

# Get all users v2
curl http://localhost:3000/api/v2/users
```

Both APIs should return the same data, but v2 uses the new column internally.

### Step 6: Verify Schema Evolution

```bash
make psql
```

```sql
-- Check migration history
SELECT version, filename, applied_at
FROM _schema_migrations
ORDER BY version;

-- Verify both columns exist
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'users'
  AND column_name IN ('email', 'email_address')
ORDER BY column_name;

-- Check data integrity
SELECT
  id,
  email,
  email_address,
  (email = email_address) AS data_matches
FROM users
LIMIT 5;

\q
```

### Step 7: Clean Up

```bash
# Stop API server (Ctrl+C)

# Stop containers
make down
```

## Key Takeaways

1. **Migrations drive schema evolution** - Each migration represents a controlled change
2. **Safe column rename pattern** - Add new → Copy data → Update app → Drop old
3. **API versioning** - v1 and v2 can coexist during transition
4. **Backward compatibility** - Old clients continue working with v1
5. **Data integrity** - Both columns have the same data during transition

## Schema Evolution Timeline

```
Initial State (V001-V003):
  users table: id, email, username, password, created_at, updated_at

After V007 Migration:
  users table: id, email, email_address, username, password, created_at, updated_at

API v1: SELECT id, email, username FROM users
API v2: SELECT id, email_address AS email, username FROM users

Next Migration (future):
  - Drop old email column
  - Remove v1 API endpoints
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
