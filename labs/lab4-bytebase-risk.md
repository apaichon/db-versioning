# Lab 4: Bytebase Hands-On with Multi-Environment

## Objective
Use Bytebase to manage database changes across **test**, **uat**, and **prod** environments. Configure risk rules, approval workflows, SQL review, and see how Bytebase prevents dangerous changes in production.

## Prerequisites
- Completed Labs 1-3
- Docker running with PostgreSQL + Bytebase

## Step-by-Step Instructions

### Step 1: Prepare Multi-Environment Databases

```bash
# Start PostgreSQL + Bytebase
make setup

# Create test, uat, prod databases
make create-envs

# Test env: V001-V003 only (basic schema, has 'email' column)
make migrate ENV=test MAX_VERSION=003
make seed ENV=test TABLES="users products orders order_items"

# UAT env: all migrations (full schema, has 'email_address' column)
make migrate ENV=uat
make seed ENV=uat TABLES="users products orders order_items"

# Prod env: all migrations (full schema, has 'email_address' column)
make migrate ENV=prod
make seed ENV=prod TABLES="users products orders order_items"

# Verify schema differences
make compare-envs
```

Expected output from `make compare-envs`:
```
--- app_test ---
  Tables: _schema_migrations, order_items, orders, products, users
  Migrations applied: 001, 002, 003
  users columns: id, email, username, password, created_at, updated_at

--- app_uat ---
  Tables: _schema_migrations, audit_log, employees, order_items, orders, products, users
  Migrations applied: 001, 002, 003, 004, 005, 006, 007
  users columns: id, email_address, username, password, created_at, updated_at, ...

--- app_prod ---
  Tables: _schema_migrations, audit_log, employees, order_items, orders, products, users
  Migrations applied: 001, 002, 003, 004, 005, 006, 007
  users columns: id, email_address, username, password, created_at, updated_at, ...
```

### Step 2: Open Bytebase

```bash
make bytebase
```

Opens `http://localhost:8088` in your browser.

### Step 3: Register Admin Account

1. Click **Sign Up** (first time only)
2. Fill in:
   - Email: `admin@example.com`
   - Password: `admin123`
3. Click **Sign Up**

You are now **Workspace Admin**.

### Step 4: Create Environments

Bytebase uses environments to apply different policies.

1. Click **Settings** > **Environments** in the left sidebar
2. You should see default environments. Create or rename:
   - **Test** — for development testing
   - **UAT** — for pre-production staging
  * **Prod** — for production

### Step 5: Add PostgreSQL Instance

1. Click **Instances** in the left sidebar
2. Click **Create Instance**
3. Select **PostgreSQL**
4. Fill in:
   - **Instance Name**: `tutorial-postgres`
   - **Host**: `postgres`
   - **Port**: `5432`
   - **Username**: `tutorial`
   - **Password**: `tutorial_secret`
5. Click **Create**

You should see databases: `app_db`, `app_test`, `app_uat`, `app_prod`

### Step 6: Create a Project

1. Click **Projects** > **Create Project**
2. Fill in:
   - **Name**: `db-versioning-tutorial`
   - **Key**: `DBVER`
3. Click **Create**

### Step 7: Add Databases to Project

Add each environment's database to the project:

1. Click project `db-versioning-tutorial`
2. Click **Databases** > **Add Database**
3. Select instance `tutorial-postgres`
4. Select `app_test` → assign to **Test** environment
5. Click **Add**
6. Repeat for `app_uat` → **UAT** environment
7. Repeat for `app_prod` → **Prod** environment

### Step 8: Add Team Members

1. Click **IAM** > **Users** in the left sidebar

**Add DBA:**
- Click **Create User**
- Email: `dba@example.com`
- Password: `dba123`
- Role: **Workspace DBA**
- Click **Create**

**Add Developer:**
- Click **Create User**
- Email: `dev@example.com`
- Password: `dev123`
- Role: **Project Developer**
- Click **Create**

### Step 9: Configure Risk Rules

1. Click **Settings** > **Risk Center**

**Rule 1: All DDL in Prod is HIGH risk**
- Click **Create Risk Rule**
- Name: `Prod DDL`
- Condition: `environment_id == "prod" AND sql_type IN (DDL)`
- Risk Level: **HIGH**
- Click **Create**

**Rule 2: Large table DDL is HIGH risk**
- Click **Create Risk Rule**
- Name: `Large Table DDL`
- Condition: `table_rows > 1000000`
- Risk Level: **HIGH**
- Click **Create**

**Rule 3: All DELETE/UPDATE in Prod**
- Click **Create Risk Rule**
- Name: `Prod DML`
- Condition: `environment_id == "prod" AND sql_type IN (DELETE, UPDATE)`
- Risk Level: **HIGH**
- Click **Create**

**Rule 4: Test environment is LOW risk**
- Click **Create Risk Rule**
- Name: `Test Environment`
- Condition: `environment_id == "test"`
- Risk Level: **LOW**
- Click **Create**

### Step 10: Configure Approval Flows

1. Click **CI/CD** > **Custom Approval**
2. Under **Change Database**, click **Add Rule**

**Flow 1: Test — Auto-approve**
- Name: `Test Auto`
- Condition: `resource.environment_id == "test"`
- Approval Flow: (empty = auto-approve)
- Click **Create**

**Flow 2: UAT — DBA review**
- Click **Add Rule**
- Name: `UAT DBA Review`
- Condition: `resource.environment_id == "uat"`
- Approval Flow: **DBA**
- Click **Create**

**Flow 3: Prod ALTER — Owner → DBA**
- Click **Add Rule**
- Name: `Prod ALTER`
- Condition: `statement.sql_type == "ALTER_TABLE" && resource.environment_id == "prod"`
- Approval Flow: **Project Owner** → **DBA**
- Click **Create**

**Flow 4: Prod DELETE — Owner → DBA → Security**
- Click **Add Rule**
- Name: `Prod DELETE`
- Condition: `statement.sql_type == "DELETE" && resource.environment_id == "prod"`
- Approval Flow: **Project Owner** → **DBA** → **Security**
- Click **Create**

### Step 11: Test — Submit Change to Test (Auto-approve)

1. Log out, log in as `dev@example.com` / `dev123`
2. Go to project > **Databases** > `app_test` > **Edit Schema**
3. Paste:

```sql
CREATE TABLE feedback (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT REFERENCES users(id),
    rating      INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment     TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

4. Click **Create**

**Result:**
- Risk Level: **LOW** (test environment)
- Approval: **Auto-approved**
- Status: **Completed**
- No waiting — change applied immediately

### Step 12: Test — Submit Change to UAT (Needs DBA)

1. Go to project > **Databases** > `app_uat` > **Edit Schema**
2. Paste:

```sql
ALTER TABLE users ADD COLUMN last_login_at TIMESTAMPTZ;
```

3. Click **Create**

**Result:**
- Risk Level: **MEDIUM** (UAT environment)
- Approval: **Waiting for DBA**
- Status: **Pending**

**Approve as DBA:**
1. Log out, log in as `dba@example.com` / `dba123`
2. Go to **Issues** > click the pending issue
3. Review the SQL
4. Click **Approve**
5. Status changes to **Completed**

### Step 13: Test — Submit Dangerous Change to Prod

1. Log out, log in as `dev@example.com` / `dev123`
2. Go to project > **Databases** > `app_prod` > **Edit Schema**
3. Paste a dangerous change:

```sql
-- This should be blocked or require multi-level approval!
ALTER TABLE users DROP COLUMN email_address;
```

4. Click **Create**

**Result:**
- Risk Level: **HIGH** (DDL in prod)
- Approval: **Project Owner → DBA**
- Status: **Waiting for approval**

**Try approving:**
1. Log in as admin (Project Owner)
2. Go to **Issues** > click the issue
3. Review the SQL — notice the warning
4. Click **Approve** (first level)
5. Log in as `dba@example.com`
6. Go to **Issues** > click the issue
7. Click **Approve** (second level)
8. Status: **Completed**

**Key lesson:** The dangerous change required TWO approvals. In real production, you'd add Security review too.

### Step 14: Enable SQL Review Policy

1. Log in as admin
2. Click **Settings** > **SQL Review**
3. Click **Create Policy**

**Enable rules:**

| Rule | Level | Why |
|------|-------|-----|
| Require primary keys | ERROR | Every table needs a PK |
| Require NOT NULL | WARNING | Avoid nullable columns |
| Table naming convention | ERROR | Enforce `^[a-z_]+$` |
| Prevent SELECT * | WARNING | Performance |
| No DROP TABLE | ERROR | Prevent data loss |

4. Click **Create**

### Step 15: Test SQL Review — Bad SQL Gets Caught

1. Go to project > **Databases** > `app_test` > **Edit Schema**
2. Paste SQL that violates rules:

```sql
-- Violates: no primary key, nullable columns
CREATE TABLE bad_table (
    name VARCHAR(100),
    value TEXT
);
```

3. Click **Create**

**Result:**
- ⚠️ ERROR: Table must have a primary key
- ⚠️ WARNING: Column should have NOT NULL constraint
- Issue shows SQL review findings
- You can fix the SQL and resubmit

### Step 16: View Schema Differences in Bytebase

1. Go to project > **Databases**
2. Compare `app_test` vs `app_prod`:
   - `app_test` has `email` column
   - `app_prod` has `email_address` column
   - `app_prod` has extra tables: `audit_log`, `employees`
3. This shows the migration drift between environments

### Step 17: View Audit Log

1. Click **Audit Log** in the left sidebar
2. Review all changes:
   - Who submitted the change
   - When it was submitted
   - What SQL was executed
   - Which environment
   - Approval chain
   - Risk level

**Example audit entries:**
```
Timestamp  | Actor              | Action    | Database   | SQL                              | Risk | Status
-----------+--------------------+-----------+------------+----------------------------------+------+---------
10:01      | dev@example.com    | Change DB | app_test   | CREATE TABLE feedback...         | LOW  | Done
10:05      | dev@example.com    | Change DB | app_uat    | ALTER TABLE users ADD COLUMN...  | MED  | Done
10:10      | dev@example.com    | Change DB | app_prod   | ALTER TABLE users DROP COLUMN... | HIGH | Done
```

### Step 18: View Change History

1. Go to project > **Databases** > `app_prod`
2. Click **Change History** (or **Changelog**)
3. See all schema changes applied to production:
   - V001-V007 migrations
   - Any changes submitted through Bytebase
   - Who approved each change
   - Rollback options

### Step 19: Test Rollback in Bytebase

1. Go to **Issues** > find the DROP COLUMN issue
2. Click on the completed issue
3. Look for **Rollback** option
4. Bytebase can generate rollback SQL for some changes

**Note:** Not all changes can be rolled back automatically. This is why safe migration patterns (from Lab 2) are important!

### Step 20: Clean Up

```bash
make down
```

## Environment Comparison Summary

| Feature | Test | UAT | Prod |
|---------|------|-----|------|
| Database | `app_test` | `app_uat` | `app_prod` |
| Migrations | V001-V003 | V001-V007 | V001-V007 |
| Risk Level | LOW | MEDIUM | HIGH |
| Approval | Auto | DBA | Owner → DBA |
| SQL Review | Enabled | Enabled | Enabled |
| Rollback | N/A | Manual | Manual |

## Key Takeaways

1. **Environments matter** — Same SQL has different risk levels in test vs prod
2. **Risk rules automate assessment** — No more "looks fine to me"
3. **Approval flows prevent mistakes** — Dangerous changes need multiple approvals
4. **SQL review catches bad SQL** — Before it reaches production
5. **Audit log provides compliance** — Who, what, when, why for every change
6. **Schema drift is visible** — Bytebase shows differences between environments

## Bytebase Features Used

| Feature | What We Did |
|---------|-------------|
| Environments | Created Test, UAT, Prod |
| Instances | Added PostgreSQL with 4 databases |
| Projects | Organized databases into a project |
| Risk Center | Configured 4 risk rules |
| Custom Approval | Configured 4 approval flows |
| SQL Review | Enabled 5 review rules |
| Audit Log | Viewed all changes |
| Change History | Tracked schema evolution |
| Users & Roles | Added DBA and Developer |

## Commands Reference

| Command | Description |
|---------|-------------|
| `make create-envs` | Create test, uat, prod databases |
| `make migrate ENV=test MAX_VERSION=003` | Migrate test env |
| `make migrate ENV=prod` | Migrate prod env |
| `make seed ENV=uat TABLES="users"` | Seed UAT |
| `make compare-envs` | Compare schemas across envs |
| `make status ENV=prod` | Check prod migration status |
| `make bytebase` | Open Bytebase UI |

## Next Steps

- [Data Masking](https://docs.bytebase.com/security/data-masking/overview) — Mask PII data
- [GitOps](https://docs.bytebase.com/gitops/overview) — Database changes via Git PRs
- [Just-in-Time Access](https://docs.bytebase.com/security/database-permission/just-in-time) — Temporary DB access
- [Batch Change](https://docs.bytebase.com/change-database/batch-change) — Change multiple databases at once
