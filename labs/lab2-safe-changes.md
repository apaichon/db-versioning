# Lab 2: Safe Schema Changes (Expand and Contract)

## Objective
Learn the **Expand and Contract** pattern to safely evolve your database schema without breaking existing API versions. This lab directly contrasts with Lab 1, where a column rename broke API v1.

## The Problem from Lab 1

In Lab 1, we renamed `email` to `email_address` directly:

```sql
ALTER TABLE users RENAME COLUMN email TO email_address;
```

**Result:** API v1 broke immediately. 100,000 users locked out.

## The Solution: Expand and Contract

```
Phase 1 (Expand):  Add new column → Both APIs work
Phase 2 (Migrate): Copy data     → Both APIs work
Phase 3 (Contract): Drop old column → Only API v2 works (after all clients migrated)
```

This lab covers **Phase 1 and 2** — where both API v1 and v2 work simultaneously.

## Prerequisites
- Completed Lab 1
- Docker and Docker Compose installed
- Node.js 18+ installed

## Step-by-Step Instructions

### Step 1: Start Fresh from Lab 1 State

```bash
# Start PostgreSQL
make setup

# Apply only V001-V003 (core tables, before the breaking V007)
make migrate MAX_VERSION=003

# Seed data for core tables
make seed TABLES="users products orders order_items"
```

Verify the initial state:
```bash
make psql
```

```sql
-- Check users table has 'email' column (from V001)
\d users

-- Should see:
--  Column  |          Type
-- ---------+--------------------------
--  id      | bigint
--  email   | character varying(255)   ← original column
--  username| character varying(100)
--  password| character varying(255)
--  created_at | timestamp with time zone
--  updated_at | timestamp with time zone

SELECT id, email, username FROM users LIMIT 3;
\q
```

### Step 2: Start API v1 (Current Production)

```bash
make api-install
make api-start
```

Test API v1 (in another terminal):
```bash
curl http://localhost:3000/api/v1/users/1

# Expected:
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

**API v1 is working.** This is what 100,000 users depend on.

### Step 3: The Safe Migration — Add New Column (Expand Phase)

Instead of renaming the column, we **add a new column** alongside the old one.

```bash
make new-migration V=008 DESC=add_email_address_column
```

Edit `migrations/V008__add_email_address_column.sql`:

```sql
-- Migration: V008 - Add email_address column (Expand Phase)
-- Risk level: LOW
-- Backward compatible: YES
-- Pattern: Expand and Contract (Phase 1 of 3)
-- Impact: API v1 still works, API v2 can start using new column
-- Rollback strategy: ALTER TABLE users DROP COLUMN email_address

BEGIN;

-- Step 1: Add new column (nullable - doesn't affect existing rows)
ALTER TABLE users ADD COLUMN email_address VARCHAR(255);

-- Step 2: Copy data from old column to new column
UPDATE users SET email_address = email;

-- Step 3: Add unique constraint to new column
ALTER TABLE users ADD CONSTRAINT users_email_address_unique UNIQUE (email_address);

-- Note: The old 'email' column STILL EXISTS
-- API v1 can still query 'email' → WORKS
-- API v2 can query 'email_address' → WORKS
-- Both APIs work simultaneously!

COMMIT;
```

Apply the migration:
```bash
make migrate
```

### Step 4: Verify Both Columns Exist

```bash
make psql
```

```sql
-- Check that BOTH columns exist
\d users

-- Should see:
--  Column        |          Type
-- ---------------+--------------------------
--  id            | bigint
--  email         | character varying(255)   ← old column (still exists!)
--  email_address | character varying(255)   ← new column
--  username      | character varying(100)
--  password      | character varying(255)
--  created_at    | timestamp with time zone
--  updated_at    | timestamp with time zone

-- Both columns have the same data
SELECT id, email, email_address, (email = email_address) AS matches FROM users LIMIT 5;

-- Expected:
--  id |         email          |     email_address     | matches
-- ----+------------------------+------------------------+--------
--   1 | john.doe@example.com   | john.doe@example.com   | t
--   2 | jane.smith@example.com | jane.smith@example.com | t
--   3 | bob.wilson@example.com | bob.wilson@example.com | t
--   ...

\q
```

**Key point:** Both `email` and `email_address` columns exist and contain the same data.

### Step 5: Test API v1 — Still Works!

API v1 queries the old `email` column. Since we didn't remove it, v1 still works.

```bash
curl http://localhost:3000/api/v1/users/1

# Expected:
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

**API v1 works!** No breaking change. 100,000 users unaffected.

### Step 6: Test API v2 — Also Works!

API v2 queries the new `email_address` column. Since we added it and copied data, v2 works too.

```bash
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
```

**API v2 works!** New clients can start using it immediately.

### Step 7: Compare Lab 1 vs Lab 2

<div class="grid grid-cols-2 gap-4">

<div class="bg-red-500 bg-opacity-10 p-4 rounded">

### Lab 1: Direct Rename (BROKE)

```sql
ALTER TABLE users
  RENAME COLUMN email TO email_address;
```

- ✗ API v1 BROKE (column `email` gone)
- ✓ API v2 works
- ✗ 100,000 users locked out
- ✗ Emergency rollback needed

</div>

<div class="bg-green-500 bg-opacity-10 p-4 rounded">

### Lab 2: Expand and Contract (SAFE)

```sql
ALTER TABLE users
  ADD COLUMN email_address VARCHAR(255);
UPDATE users SET email_address = email;
```

- ✓ API v1 still works (column `email` exists)
- ✓ API v2 works (column `email_address` exists)
- ✓ Zero downtime
- ✓ No emergency rollback

</div>

</div>

### Step 8: Test All Users via Both APIs

```bash
# Get all users via v1
curl http://localhost:3000/api/v1/users

# Get all users via v2
curl http://localhost:3000/api/v2/users
```

Both return the same users with the same email data — just using different column names internally.

### Step 9: Verify Data Integrity

```bash
make psql
```

```sql
-- Verify all rows have matching data
SELECT
  COUNT(*) AS total_users,
  COUNT(email) AS with_email,
  COUNT(email_address) AS with_email_address,
  COUNT(*) FILTER (WHERE email = email_address) AS matching
FROM users;

-- Expected:
--  total_users | with_email | with_email_address | matching
-- -------------+------------+-------------------+----------
--           10 |         10 |                10 |       10

-- Check migration history
SELECT version, filename FROM _schema_migrations ORDER BY version;

\q
```

### Step 10: The Full Expand and Contract Timeline

```
┌─────────────────────────────────────────────────────────────────┐
│  EXPAND AND CONTRACT TIMELINE                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Phase 1: EXPAND (this lab)                                     │
│  ┌─────────────────────────────────────────────┐                │
│  │ Add email_address column                     │                │
│  │ Copy data from email → email_address         │                │
│  │ Both columns exist with same data            │                │
│  │ API v1 works ✓  API v2 works ✓              │                │
│  └─────────────────────────────────────────────┘                │
│                         ↓                                       │
│  Phase 2: MIGRATE CLIENTS (weeks/months)                        │
│  ┌─────────────────────────────────────────────┐                │
│  │ Deploy API v2 to app stores                  │                │
│  │ Update third-party integrations              │                │
│  │ Monitor API v1 usage declining               │                │
│  │ API v1 works ✓  API v2 works ✓              │                │
│  └─────────────────────────────────────────────┘                │
│                         ↓                                       │
│  Phase 3: CONTRACT (future lab)                                 │
│  ┌─────────────────────────────────────────────┐                │
│  │ Wait until API v1 usage = 0                  │                │
│  │ Remove API v1 endpoints                      │                │
│  │ Drop old email column                        │                │
│  │ Only API v2 works ✓                          │                │
│  └─────────────────────────────────────────────┘                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 11: Clean Up

```bash
# Stop API server (Ctrl+C)

# Stop containers
make down
```

## Key Takeaways

1. **Never rename or drop columns directly** — Always use Expand and Contract
2. **Adding nullable columns is safe** — Existing queries continue working
3. **Both APIs work simultaneously** — v1 uses old column, v2 uses new column
4. **Zero downtime** — No users are affected during the migration
5. **Contract phase waits** — Only drop old columns after ALL clients have migrated

## Comparison: Lab 1 vs Lab 2

| Aspect | Lab 1 (Direct Rename) | Lab 2 (Expand and Contract) |
|--------|----------------------|----------------------------|
| Migration | `RENAME COLUMN` | `ADD COLUMN` + `UPDATE` |
| API v1 | ✗ BROKEN | ✓ Works |
| API v2 | ✓ Works | ✓ Works |
| Downtime | 90% of users | Zero |
| Rollback | Emergency needed | Just drop new column |
| Risk level | HIGH | LOW |
| Backward compatible | NO | YES |

## Safe Migration Checklist

- [ ] New column is nullable or has a default
- [ ] Old column is NOT removed
- [ ] Data copied from old to new column
- [ ] API v1 still queries old column
- [ ] API v2 queries new column
- [ ] Both APIs tested and working
- [ ] Data integrity verified
- [ ] Rollback strategy documented (drop new column)

## Next Steps

- **Phase 2**: Deploy API v2 and monitor API v1 usage decline
- **Phase 3**: When API v1 usage reaches 0, drop the old `email` column
- **Lab 3**: Learn about risky changes and rollback strategies
- **Lab 4**: Use Bytebase to enforce approval workflows for schema changes
