# Lab 4: Bytebase Multi-Environment Deployment (Free Version)

## Objective
Use Bytebase **free version** to manage schema changes across **test**, **uat**, and **prod** environments. No Enterprise license needed.

## Prerequisites
- Completed Labs 1-3
- Docker running

## Step-by-Step Instructions

### Step 1: Prepare Databases

```bash
# Start PostgreSQL + Bytebase
make setup

# Create test, uat, prod databases
make create-envs

# Test: basic schema (V001-V003)
make migrate ENV=test MAX_VERSION=003
make seed ENV=test TABLES="users products orders order_items"

# UAT: full schema (V001-V007)
make migrate ENV=uat
make seed ENV=uat TABLES="users products orders order_items"

# Prod: full schema (V001-V007)
make migrate ENV=prod
make seed ENV=prod TABLES="users products orders order_items"

# Verify differences
make compare-envs
```

### Step 2: Open Bytebase

```bash
make bytebase
```

Opens `http://localhost:8088`.

### Step 3: Register Admin

1. Click **Sign Up**
2. Email: `admin@example.com`
3. Password: `admin123`
4. Click **Sign Up**

### Step 4: Add PostgreSQL Instance

1. Click **Instances** > **Create Instance**
2. Select **PostgreSQL**
3. Fill in:
   - **Name**: `tutorial-postgres`
   - **Host**: `postgres`
   - **Port**: `5432`
   - **Username**: `tutorial`
   - **Password**: `tutorial_secret`
4. Click **Create**

You should see databases: `app_test`, `app_uat`, `app_prod`

### Step 5: Create Project

1. Click **Projects** > **Create Project**
2. **Name**: `db-versioning-tutorial`
3. **Key**: `DBVER`
4. Click **Create**

### Step 6: Add Databases to Project

1. Click project `db-versioning-tutorial`
2. Click **Databases** > **Add Database**
3. Select `app_test` → assign to **Test** environment
4. Click **Add**
5. Repeat for `app_uat` → **UAT**
6. Repeat for `app_prod` → **Prod**

### Step 7: Submit Schema Change to Test

1. Click **Databases** > `app_test` > **Change Database**
2. Paste:

```sql
CREATE TABLE feedback (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT REFERENCES users(id),
    rating      INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment     TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

3. Click **Create**

**Result:**
- Test environment → auto-rolled out
- No manual approval needed
- Status: **Completed**

### Step 8: Submit Same Change to UAT

1. Click **Databases** > `app_uat` > **Change Database**
2. Paste the same SQL
3. Click **Create**

**Result:**
- UAT environment → requires manual rollout
- Status: **Waiting for rollout**
- Click **Rollout** to apply

### Step 9: Submit Same Change to Prod

1. Click **Databases** > `app_prod` > **Change Database**
2. Paste the same SQL
3. Click **Create**

**Result:**
- Prod environment → requires manual rollout
- Status: **Waiting for rollout**
- Click **Rollout** to apply

**Key point:** In the free version, Test auto-deploys but UAT/Prod require manual rollout. This prevents accidental production changes.

### Step 10: View Change History

1. Go to project > **Databases** > `app_prod`
2. Click **Change History**
3. See all changes:
   - V001-V007 (from migrations)
   - `CREATE TABLE feedback` (from Bytebase)
   - Who made the change
   - When it was applied

### Step 11: View Schema Differences

1. Go to **Databases** > `app_test`
2. Compare with `app_prod`:
   - `app_test` has `email` column
   - `app_prod` has `email_address` column
   - `app_prod` has `audit_log`, `employees` tables
   - Both now have `feedback` table

### Step 12: Submit a Data Change (DML)

1. Click **Databases** > `app_test` > **Edit Data** (or **SQL Editor**)
2. Paste:

```sql
INSERT INTO feedback (user_id, rating, comment)
VALUES (1, 5, 'Great product!');
```

3. Click **Run**

### Step 13: View SQL Editor

1. Click **SQL Editor** in the left sidebar
2. Select database `app_prod`
3. Run a query:

```sql
SELECT id, email_address, username FROM users LIMIT 5;
```

4. View results in the editor

### Step 14: Clean Up

```bash
make down
```

## Free Version Features Used

| Feature | Available | What We Did |
|---------|-----------|-------------|
| Instances | ✓ | Added PostgreSQL |
| Projects | ✓ | Created project |
| Environments | ✓ | Test, UAT, Prod |
| Edit Schema | ✓ | Submitted CREATE TABLE |
| Change History | ✓ | Viewed all changes |
| SQL Editor | ✓ | Queried data |
| Rollout Policy | ✓ | Test=auto, Prod=manual |
| SQL Review | ✓ | Basic checks |

## Environment Rollout Behavior (Free Version)

| Environment | Rollout | Approval |
|-------------|---------|----------|
| Test | Auto | None |
| UAT | Manual | Click "Rollout" |
| Prod | Manual | Click "Rollout" |

## Commands Reference

| Command | Description |
|---------|-------------|
| `make create-envs` | Create test, uat, prod databases |
| `make migrate ENV=test MAX_VERSION=003` | Migrate test |
| `make migrate ENV=prod` | Migrate prod |
| `make seed ENV=uat TABLES="users"` | Seed UAT |
| `make compare-envs` | Compare schemas |
| `make bytebase` | Open Bytebase |

## Next Steps

- **Lab 1**: Breaking change (column rename breaks API)
- **Lab 2**: Safe change (expand and contract pattern)
- **Lab 3**: Safe DDL on large tables (10M+ rows)
- [Bytebase Docs](https://docs.bytebase.com)
