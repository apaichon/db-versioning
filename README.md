# Database Version Control Tutorial with PostgreSQL

A hands-on tutorial for managing database schema changes using version-controlled migrations with PostgreSQL, and how tools like **Bytebase** bring governance, risk management, and team collaboration to database changes.

---

## Table of Contents

1. [Why Database Version Control?](#why-database-version-control)
2. [Prerequisites](#prerequisites)
3. [Project Setup](#project-setup)
4. [Migration-Based Workflow](#migration-based-workflow)
5. [Running Migrations](#running-migrations)
6. [Practical Examples](#practical-examples)
7. [Why Use Bytebase?](#why-use-bytebase)
8. [Bytebase Risk Management](#bytebase-risk-management)
9. [Bytebase Hands-On](#bytebase-hands-on)
10. [Best Practices](#best-practices)

---

## Why Database Version Control?

Application code is version-controlled with Git. Database schemas should be too. Without version control, database changes are:

| Problem | Without Version Control | With Version Control |
|---------|------------------------|---------------------|
| **Traceability** | "Who changed this table?" | Every change is tracked with author, date, and reason |
| **Consistency** | "My local DB is different from prod" | All environments follow the same migration path |
| **Rollback** | "How do we undo this?" | Each migration has a rollback strategy |
| **Collaboration** | "Don't touch the DB, I'm working on it" | Multiple developers work via merge requests |
| **Audit** | "When was this column added?" | Full history in git log |
| **Risk** | "Just run the SQL in prod" | Automated checks, reviews, and approvals |

---

## Prerequisites

- [Docker](https://www.docker.com/) and Docker Compose
- [PostgreSQL 16 client](https://www.postgresql.org/download/) (`psql`)
- [Git](https://git-scm.com/)
- Basic SQL knowledge

---

## Project Setup

### 1. Clone and Start Services

```bash
# Start PostgreSQL + Bytebase
docker compose up -d

# Wait for PostgreSQL to be ready
docker compose exec postgres pg_isready -U tutorial -d app_db
```

### 2. Verify Connection

```bash
# Application database (your tables)
psql -h localhost -U tutorial -d app_db
# Password: tutorial_secret

# Bytebase database (internal tables, separate from app)
psql -h localhost -U tutorial -d bytebase_db
```

### 3. Database Separation

```
PostgreSQL Instance
├── app_db          ← Application tables (users, orders, products, etc.)
└── bytebase_db     ← Bytebase internal tables (metadata, audit, etc.)
```

This keeps your application tables clean and separate from Bytebase internals.

### 3. Project Structure

```
db-versioning/
├── docker-compose.yml          # PostgreSQL + Bytebase setup
├── migrations/                 # Version-controlled SQL files
│   ├── V001__create_users_table.sql
│   ├── V002__create_orders_table.sql
│   ├── V003__create_products_table.sql
│   ├── V004__add_user_profile.sql
│   ├── V005__create_audit_log.sql
│   └── V006__create_employees_table.sql
├── scripts/
│   ├── migrate.sh              # Apply migrations
│   └── new-migration.sh        # Create new migration
├── docs/
│   └── bytebase-benefits.md    # Bytebase deep-dive
└── README.md                   # This file
```

---

## Migration-Based Workflow

### Naming Convention

```
V<version>__<description>.sql
```

- `V001__create_users_table.sql` - Version 1: Create users table
- `V002__create_orders_table.sql` - Version 2: Create orders table
- Sequential numbering ensures ordered execution

### Migration File Template

Each migration file should include metadata for risk assessment:

```sql
-- Migration: V007 - add_payment_methods_table
-- Created: 2026-09-30
-- Author: developer
--
-- Risk level: MEDIUM
-- Affected tables: payment_methods, users
-- Estimated affected rows: N/A (DDL)
-- Backward compatible: YES
-- Rollback strategy: DROP TABLE payment_methods

BEGIN;

CREATE TABLE payment_methods (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(id),
    type        VARCHAR(50) NOT NULL,
    token       VARCHAR(255) NOT NULL,
    is_default  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMIT;
```

---

## Running Migrations

### Apply All Pending Migrations

```bash
./scripts/migrate.sh migrate
```

Output:
```
  APPLY V001__create_users_table.sql ...
  APPLY V002__create_orders_table.sql ...
  APPLY V003__create_products_table.sql ...
  APPLY V004__add_user_profile.sql ...
  APPLY V005__create_audit_log.sql ...
  APPLY V006__create_employees_table.sql ...
Applied 6 migration(s).
```

### Check Migration Status

```bash
./scripts/migrate.sh status
```

### Create a New Migration

```bash
./scripts/new-migration.sh 7 "add_payment_methods"
# Creates: migrations/V007__add_payment_methods.sql
```

---

## Practical Examples

### Example 1: Safe Column Addition (Backward Compatible)

```sql
-- V004__add_user_profile.sql
-- Risk: LOW | Backward compatible: YES

ALTER TABLE users ADD COLUMN first_name VARCHAR(100);
ALTER TABLE users ADD COLUMN last_name  VARCHAR(100);
ALTER TABLE users ADD COLUMN phone      VARCHAR(20);
ALTER TABLE users ADD COLUMN is_active  BOOLEAN NOT NULL DEFAULT TRUE;
```

**Why this is safe:**
- Adding nullable columns doesn't break existing queries
- Default values ensure no NULL issues
- No existing data is modified

### Example 2: Creating an Audit Trail

```sql
-- V005__create_audit_log.sql
-- Risk: LOW | Backward compatible: YES

CREATE TABLE audit_log (
    id          BIGSERIAL PRIMARY KEY,
    table_name  VARCHAR(100) NOT NULL,
    record_id   BIGINT       NOT NULL,
    action      VARCHAR(20)  NOT NULL CHECK (action IN ('INSERT','UPDATE','DELETE')),
    old_data    JSONB,
    new_data    JSONB,
    changed_by  BIGINT       REFERENCES users(id),
    changed_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
```

**Benefits:**
- Full audit trail for compliance
- JSONB allows flexible schema for any table
- Foreign key to users for accountability

### Example 3: Risky Change (Breaking Change)

```sql
-- Example of a HIGH RISK migration
-- Risk: HIGH | Backward compatible: NO
-- Requires: Bytebase approval workflow

-- DANGER: This will break existing applications!
ALTER TABLE users DROP COLUMN email;  -- BREAKING!

-- SAFER alternative:
-- 1. Add new column
ALTER TABLE users ADD COLUMN email_new VARCHAR(255);
-- 2. Migrate data
UPDATE users SET email_new = email;
-- 3. Update application to use email_new
-- 4. Drop old column in next migration
ALTER TABLE users DROP COLUMN email;
ALTER TABLE users RENAME COLUMN email_new TO email;
```

### Example 4: Large Table DDL (Production Risk)

```sql
-- When a table has millions of rows, DDL operations can lock the table
-- Risk: HIGH if table_rows > 10,000,000

-- BAD: This locks the table during execution
ALTER TABLE orders ADD COLUMN notes TEXT;

-- GOOD: Use pg_repack or online migration tools
-- Or schedule during maintenance windows
-- Bytebase can detect this and require approval
```

---

## Why Use Bytebase?

The manual migration approach works for small teams. But as teams scale, you need:

| Challenge | Manual Approach | Bytebase Solution |
|-----------|----------------|-------------------|
| **SQL Review** | Manual code review | Automated SQL linting with 50+ rules |
| **Risk Assessment** | "Looks fine to me" | Automatic risk scoring (HIGH/MEDIUM/LOW) |
| **Approval Flow** | Email/Slack threads | Configurable multi-level approvals |
| **Rollback** | Manual reverse SQL | 1-click data rollback |
| **Audit Trail** | Git commits only | Full change history with who/when/what |
| **Multi-Environment** | Manual promotion | Pipeline rollout: Dev -> Test -> Prod |
| **Data Masking** | None | Automatic PII masking in query results |
| **Access Control** | Shared DB passwords | Just-in-time access with expiration |

---

## Bytebase Risk Management

Bytebase provides automated risk assessment based on conditions:

### Risk Conditions

| Condition | Description | Example |
|-----------|-------------|---------|
| `environment_id` | Target environment | Prod = HIGH risk |
| `sql_type` | Type of SQL operation | DROP, ALTER, TRUNCATE = HIGH |
| `table_rows` | Size of affected table | > 10M rows = HIGH |
| `affected_rows` | Rows impacted by DML | > 1,000 rows = HIGH |
| `database_name` | Critical databases | prod_db1, prod_db2 = HIGH |
| `table_name` | Critical tables | users, payments = HIGH |

### Example Risk Rules

**Rule 1: All DDL in Production is HIGH risk**
```
environment_id == Prod
AND sql_type NOT IN (CREATE_TABLE, CREATE_VIEW, CREATE_INDEX)
```

**Rule 2: Large table changes are HIGH risk**
```
environment_id == Prod
AND table_rows > 10000000
```

**Rule 3: All DELETE/UPDATE in Production**
```
environment_id == Prod
AND sql_type IN (DELETE, UPDATE)
```

### Risk-Based Approval Flow

```
Risk Level    Approval Required
-----------   -----------------
LOW           Auto-approve
MEDIUM        DBA review
HIGH          Project Owner -> DBA
CRITICAL      CTO -> DBA -> Security
```

---

## Bytebase Hands-On

### 1. Access Bytebase

```bash
# Bytebase is already running via docker-compose
open http://localhost:8088
```

### 2. Register Admin Account

- Open `http://localhost:8088`
- Register as admin (first login)

### 3. Add PostgreSQL Instance

1. Go to **Settings > Instances**
2. Click **Create Instance**
3. Select **PostgreSQL**
4. Connection:
   - Host: `postgres`
   - Port: `5432`
   - Username: `tutorial`
   - Password: `tutorial_secret`

### 4. Create a Project

1. Go to **Projects**
2. Click **Create Project**
3. Name: `db-versioning-tutorial`
4. Add the PostgreSQL database

### 5. Submit a Schema Change

1. Go to the project > **Databases**
2. Select a database > **Edit Schema**
3. Paste SQL:

```sql
CREATE TABLE payment_methods (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(id),
    type        VARCHAR(50) NOT NULL,
    token       VARCHAR(255) NOT NULL,
    is_default  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

4. Click **Create** to submit the change

### 6. Configure Risk Rules

1. Go to **Settings > Risk Center**
2. Create rules:

| Rule Name | Condition | Risk Level |
|-----------|-----------|------------|
| Prod DDL | `environment_id == Prod AND sql_type == ALTER_TABLE` | HIGH |
| Large Table | `table_rows > 1000000` | HIGH |
| Prod DML | `environment_id == Prod AND sql_type IN (DELETE, UPDATE)` | HIGH |

### 7. Configure Approval Flow

1. Go to **CI/CD > Custom Approval**
2. Add rules:

| Title | Condition | Approval Flow |
|-------|-----------|---------------|
| DDL ALTER in Prod | `sql_type == "ALTER_TABLE" && environment_id == "prod"` | Owner -> DBA |
| DDL CREATE in Prod | `sql_type == "CREATE_TABLE" && environment_id == "prod"` | DBA |
| DML in Prod | `sql_type IN ("DELETE", "UPDATE") && environment_id == "prod"` | DBA -> Security |

---

## Best Practices

### Migration Design

1. **Small, focused migrations** - One logical change per file
2. **Always backward compatible** - Never break existing queries
3. **Include rollback strategy** - Document how to undo
4. **Use transactions** - Wrap in `BEGIN; ... COMMIT;`
5. **Test locally first** - Run against a copy of production data

### Risk Management

1. **Classify environments** - Dev/Test/Staging/Prod with different policies
2. **Automate SQL review** - Catch issues before they reach review
3. **Require approvals for Prod** - No direct production access
4. **Monitor affected rows** - Large batch changes need special handling
5. **Schedule large DDL** - Use maintenance windows for big tables

### Team Workflow

```
Developer                  Bytebase                   DBA
    |                          |                       |
    |-- Write migration ------>|                       |
    |-- Submit PR ------------>|                       |
    |                          |-- SQL Review -------->|
    |                          |-- Risk Assessment --->|
    |                          |                       |-- Approve/Reject
    |                          |<-- Approval ----------|
    |                          |-- Rollout to Prod --->|
    |<-- Notification ---------|                       |
```

### GitOps Integration

```yaml
# .github/workflows/db-migration.yml
name: Database Migration
on:
  push:
    branches: [main]
    paths: ['migrations/**']

jobs:
  migrate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run migrations via Bytebase API
        run: |
          curl -X POST $BYTEBASE_URL/api/v1/issues \
            -H "Authorization: Bearer $BYTEBASE_TOKEN" \
            -d '{"project": "projects/db-versioning", "type": "DATABASE_CHANGE"}'
```

---

## Summary

| Aspect | Manual | With Bytebase |
|--------|--------|---------------|
| Change tracking | Git commits | Git + full audit trail |
| SQL quality | Manual review | Automated linting |
| Risk assessment | Gut feeling | Rule-based scoring |
| Approvals | Email/Slack | Configurable workflows |
| Rollback | Manual reverse | 1-click rollback |
| Access control | Shared passwords | Just-in-time access |
| Compliance | Manual audit | Automated audit log |

**Key Takeaways:**
1. Version-control your database schema like application code
2. Use migration files with clear naming and metadata
3. Automate SQL review and risk assessment
4. Require approvals for production changes
5. Use Bytebase (or similar tools) for team governance

---

## Further Reading

- [Bytebase Documentation](https://docs.bytebase.com)
- [Bytebase Risk Best Practices](https://docs.bytebase.com/tutorials/risks-best-practice)
- [Bytebase Custom Approval Flow](https://docs.bytebase.com/tutorials/database-change-management-with-risk-adjusted-approval-flow)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Database Versioning Best Practices](https://docs.bytebase.com/gitops/best-practices/overview)
