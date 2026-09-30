---
theme: default
title: Database Version Control Tutorial
info: |
  A practical guide to managing database schema changes with PostgreSQL and Bytebase
class: text-center
drawings:
  persist: false
transition: slide-left
mdc: true
---

# Database Version Control

## Practical Tutorial with PostgreSQL & Bytebase

<div class="pt-12">
  <span class="px-2 py-1 rounded cursor-pointer" hover="bg-white bg-opacity-10">
    Press Space for next page <carbon:arrow-right class="inline"/>
  </span>
</div>

---

# The Problem

Database changes without version control lead to:

<div class="grid grid-cols-2 gap-4 pt-4">

<div class="bg-red-500 bg-opacity-10 p-4 rounded">

### ❌ Without Version Control

- "Who changed this table?"
- "My local DB differs from prod"
- "How do we undo this?"
- "Don't touch the DB!"
- Shared passwords
- "Just run it in prod"

</div>

<div class="bg-green-500 bg-opacity-10 p-4 rounded">

### ✅ With Version Control

- Full change tracking
- Consistent environments
- Documented rollbacks
- Collaborative workflows
- Controlled access
- Automated governance

</div>

</div>

---

# What We'll Cover

<div class="grid grid-cols-2 gap-8">

<div>

### Part 1: Foundations
1. Migration-based workflow
2. Version-controlled SQL files
3. Practical PostgreSQL examples
4. Helper scripts

</div>

<div>

### Part 2: Bytebase
5. Risk management
6. Approval workflows
7. SQL review automation
8. Hands-on demo

</div>

</div>

---

# Project Structure

```bash
db-versioning/
├── docker-compose.yml          # PostgreSQL + Bytebase
├── migrations/                 # Version-controlled SQL
│   ├── V001__create_users_table.sql
│   ├── V002__create_orders_table.sql
│   ├── V003__create_products_table.sql
│   ├── V004__add_user_profile.sql
│   ├── V005__create_audit_log.sql
│   └── V006__create_employees_table.sql
├── scripts/
│   ├── migrate.sh              # Apply migrations
│   └── new-migration.sh        # Create new migration
└── docs/
    └── bytebase-benefits.md
```

---

# Migration Naming Convention

```
V<version>__<description>.sql
```

<div class="grid grid-cols-3 gap-4 pt-4">

<div class="bg-blue-500 bg-opacity-10 p-3 rounded text-center">

**V001**

Version number
(sequential)

</div>

<div class="bg-purple-500 bg-opacity-10 p-3 rounded text-center">

**__**

Double underscore
separator

</div>

<div class="bg-green-500 bg-opacity-10 p-3 rounded text-center">

**create_users_table**

Description
(snake_case)

</div>

</div>

<div class="mt-6 bg-gray-500 bg-opacity-10 p-4 rounded">

**Why this matters:**
- Sequential execution order
- Clear intent from filename
- Easy to track in git history

</div>

---

# Migration File Template

```sql
-- Migration: V007 - add_payment_methods
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

# Example 1: Safe Column Addition

<div class="bg-green-500 bg-opacity-10 p-4 rounded">

### V004__add_user_profile.sql

**Risk: LOW** | **Backward compatible: YES**

```sql
ALTER TABLE users ADD COLUMN first_name VARCHAR(100);
ALTER TABLE users ADD COLUMN last_name  VARCHAR(100);
ALTER TABLE users ADD COLUMN phone      VARCHAR(20);
ALTER TABLE users ADD COLUMN is_active  BOOLEAN NOT NULL DEFAULT TRUE;
```

</div>

<div class="mt-4">

**Why this is safe:**
- ✅ Nullable columns don't break existing queries
- ✅ Default values prevent NULL issues
- ✅ No existing data modified
- ✅ Applications continue working

</div>

---
class: overflow-scroll
---

# Example 2: Audit Trail

<div style="max-height: 380px; overflow-y: auto; padding-right: 8px;">

<div class="bg-blue-500 bg-opacity-10 p-4 rounded">

### V005__create_audit_log.sql

**Risk: LOW** | **Backward compatible: YES**

```sql
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

</div>

<div class="mt-4">

**Benefits:**
- Full audit trail for compliance (SOC 2, GDPR)
- JSONB allows flexible schema for any table
- Foreign key to users for accountability

</div>

</div>

---

# Example 3: Risky Change ⚠️

<div class="bg-red-500 bg-opacity-10 p-4 rounded">

### Breaking Change Example

**Risk: HIGH** | **Backward compatible: NO**

```sql
-- ❌ DANGER: Breaks existing applications!
ALTER TABLE users DROP COLUMN email;

-- ✅ SAFER: Multi-step migration
-- Step 1: Add new column
ALTER TABLE users ADD COLUMN email_new VARCHAR(255);

-- Step 2: Migrate data
UPDATE users SET email_new = email;

-- Step 3: Update application code to use email_new

-- Step 4: Drop old column (next migration)
ALTER TABLE users DROP COLUMN email;
ALTER TABLE users RENAME COLUMN email_new TO email;
```

</div>

---

# Example 4: Large Table Risk

<div class="bg-orange-500 bg-opacity-10 p-4 rounded">

### Production Risk: Table with Millions of Rows

**Risk: HIGH** if `table_rows > 10,000,000`

```sql
-- ❌ BAD: Locks table during execution
ALTER TABLE orders ADD COLUMN notes TEXT;

-- ✅ GOOD: Use online migration tools
-- Option 1: pg_repack (PostgreSQL)
-- Option 2: Schedule during maintenance window
-- Option 3: Bytebase detects and requires approval
```

</div>

<div class="mt-4">

**Key insight:** Bytebase can automatically detect large table operations and enforce approval workflows.

</div>

---
layout: center
class: text-center
---

# Lab 1 Showcase

## Breaking API Compatibility with Column Rename

A real-world scenario: what happens when you rename a database column in production?

---
class: overflow-scroll
---

# Lab 1: The Setup

<div class="grid grid-cols-2 gap-6">

<div class="bg-blue-500 bg-opacity-10 p-4 rounded">

### Your Production System

- **Mobile app v1.0** — 100,000 users → calls `/api/v1/users`
- **Mobile app v2.0** — 10,000 users → calls `/api/v2/users`
- **Web dashboard** → calls `/api/v1/users`
- **Third-party integrations** → calls `/api/v1/users`

</div>

<div class="bg-green-500 bg-opacity-10 p-4 rounded">

### Database Schema (V001-V003)

```sql
CREATE TABLE users (
    id         BIGSERIAL PRIMARY KEY,
    email      VARCHAR(255) NOT NULL UNIQUE,
    username   VARCHAR(100) NOT NULL,
    password   VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

</div>

</div>

<div class="mt-4 bg-gray-500 bg-opacity-10 p-4 rounded">

### API v1 Code (Current Production)

```javascript
app.get('/api/v1/users/:id', async (req, res) => {
  const result = await pool.query(
    'SELECT id, email, username, created_at FROM users WHERE id = $1', [id]
  );
  res.json({ success: true, data: result.rows[0] });
});
```

**All clients depend on this. It works perfectly.**

</div>

---

# Lab 1: The Breaking Change

<div class="bg-red-500 bg-opacity-10 p-4 rounded">

### V007 Migration: Rename Column

```sql
-- Risk level: HIGH (BREAKING CHANGE)
ALTER TABLE users RENAME COLUMN email TO email_address;
```

</div>

<div class="grid grid-cols-2 gap-6 mt-4">

<div class="bg-red-500 bg-opacity-10 p-4 rounded">

### API v1 — BROKEN

```javascript
'SELECT id, email, username FROM users'
```

```json
{
  "error": "column \"email\" does not exist"
}
```

**100,000 users locked out**

</div>

<div class="bg-green-500 bg-opacity-10 p-4 rounded">

### API v2 — WORKS

```javascript
'SELECT id, email_address, username FROM users'
```

```json
{
  "success": true,
  "version": "v2",
  "data": { "id": 1, "email_address": "john@example.com" }
}
```

**Only 10,000 users benefit**

</div>

</div>

---

# Lab 1: The Real-World Impact

<div class="grid grid-cols-3 gap-4">

<div class="bg-red-500 bg-opacity-20 p-4 rounded text-center">

### Mobile App v1.0

**100,000 users**

Cannot log in.
Users don't update apps immediately.
Some never update.

</div>

<div class="bg-red-500 bg-opacity-20 p-4 rounded text-center">

### Web Dashboard

**Internal team**

Shows errors.
Needs emergency deploy.
Takes days to fix.

</div>

<div class="bg-red-500 bg-opacity-20 p-4 rounded text-center">

### Third-Party APIs

**External partners**

Have own release cycles.
Cannot force updates.
Some stay on v1 forever.

</div>

</div>

<div class="mt-6 bg-orange-500 bg-opacity-10 p-4 rounded">

### The Timeline Problem

```
Day 1:   Column renamed → 90% of users locked out
Day 30:  80k users still on old app → still broken
Day 90:  20k users never update → must support BOTH versions
```

**You can't break old API versions until ALL clients have migrated.**

</div>

---

# Lab 1: Commands Used

<div class="grid grid-cols-2 gap-6">

<div>

### Step-by-Step

```bash
# 1. Start PostgreSQL
make setup

# 2. Apply only V001-V003
make migrate MAX_VERSION=003

# 3. Seed data for core tables
make seed TABLES="users products orders order_items"

# 4. Install & start API
make api-install
make api-start
```

</div>

<div>

### Then the Breaking Change

```bash
# 5. Apply V007 (rename column)
make migrate

# 6. Test API v1 → FAILS
curl localhost:3000/api/v1/users/1
# {"error": "column may not exist"}

# 7. Test API v2 → WORKS
curl localhost:3000/api/v2/users/1
# {"success": true, "version": "v2"}
```

</div>

</div>

<div class="mt-4 bg-yellow-500 bg-opacity-10 p-4 rounded text-center">

### Lesson Learned

**Column renames are breaking changes.** Lab 2 teaches the safe "Expand and Contract" pattern to rename columns with zero downtime.

</div>

---

# Lab 2: Expand and Contract — DO

<div class="bg-green-500 bg-opacity-10 p-4 rounded">

### ✅ DO: Add new column alongside old one

```sql
-- Instant, no table rewrite
ALTER TABLE users ADD COLUMN email_address VARCHAR(255);
```

### ✅ DO: Copy data to new column

```sql
-- Backfill existing data
UPDATE users SET email_address = email;
```

### ✅ DO: Keep both columns during transition

```sql
-- Old column still exists → API v1 works
-- New column has data     → API v2 works
-- Both APIs return same data, zero downtime
```

### ✅ DO: Drop old column only after all clients migrated

```sql
-- Phase 3 (weeks/months later, when API v1 usage = 0)
ALTER TABLE users DROP COLUMN email;
```

</div>

---

# Lab 2: Expand and Contract — DON'T

<div class="bg-red-500 bg-opacity-10 p-4 rounded">

### ❌ DON'T: Rename column directly

```sql
-- Breaks API v1 immediately!
ALTER TABLE users RENAME COLUMN email TO email_address;
```

### ❌ DON'T: Drop old column too early

```sql
-- Clients still using API v1 will break!
ALTER TABLE users DROP COLUMN email;
```

### ❌ DON'T: Assume clients update instantly

```
Mobile app users don't update immediately.
Some never update. Third-party APIs have
their own release cycles. You must support
BOTH API versions during transition.
```

</div>

---

# Lab 2: Lab 1 vs Lab 2 Comparison

<div class="grid grid-cols-2 gap-4">

<div class="bg-red-500 bg-opacity-10 p-4 rounded">

### Lab 1: Direct Rename

```sql
RENAME COLUMN email TO email_address
```

- ✗ API v1 **BROKEN**
- ✓ API v2 works
- ✗ 100,000 users locked out
- ✗ Emergency rollback needed
- Risk: **HIGH**

</div>

<div class="bg-green-500 bg-opacity-10 p-4 rounded">

### Lab 2: Expand and Contract

```sql
ADD COLUMN email_address
UPDATE users SET email_address = email
```

- ✓ API v1 **works**
- ✓ API v2 **works**
- ✓ Zero downtime
- ✓ No rollback needed
- Risk: **LOW**

</div>

</div>

<div class="mt-4 bg-blue-500 bg-opacity-10 p-4 rounded text-center">

### The Pattern

**Expand** (add new) → **Migrate** (copy data) → **Contract** (drop old)

Both APIs work during transition. Drop old column only when all clients have migrated.

</div>

---

# Lab 3: Safe DDL on 10M+ Rows — DO

<div class="bg-green-500 bg-opacity-10 p-4 rounded">

### ✅ DO: Add nullable column (no default)

```sql
-- Instant — metadata only, no table rewrite
ALTER TABLE transactions ADD COLUMN category VARCHAR(50);
```

### ✅ DO: Backfill in batches

```sql
-- Only locks 10K rows, table stays readable
UPDATE transactions SET category = 'premium'
WHERE id IN (SELECT id FROM transactions
  WHERE category IS NULL LIMIT 10000);
```

### ✅ DO: Create index concurrently

```sql
-- No write locks during index build
CREATE INDEX CONCURRENTLY idx_cat ON transactions(category);
```

### ✅ DO: Set default AFTER backfill

```sql
-- Only affects new INSERTs, not existing rows
ALTER TABLE transactions ALTER COLUMN reference_id
  SET DEFAULT gen_random_uuid();
```

</div>

---

# Lab 3: Safe DDL on 10M+ Rows — DON'T

<div class="bg-red-500 bg-opacity-10 p-4 rounded">

### ❌ DON'T: Add column with volatile default

```sql
-- Rewrites ALL 10M rows! Table locked for minutes.
ALTER TABLE transactions
  ADD COLUMN reference_id UUID DEFAULT gen_random_uuid();
```

### ❌ DON'T: Backfill in one UPDATE

```sql
-- Locks entire table for minutes
UPDATE transactions SET category = 'premium' WHERE amount > 500;
```

### ❌ DON'T: Add CHECK/UNIQUE in same ALTER

```sql
-- Full table scan under lock
ALTER TABLE transactions ADD COLUMN score INT DEFAULT 0,
  ADD CONSTRAINT score_check CHECK (score >= 0);
```

### ❌ DON'T: Create index without CONCURRENTLY

```sql
-- Blocks all writes during index build
CREATE INDEX idx_cat ON transactions(category);
```

</div>

---

# Lab 3: Summary — Safe vs Unsafe

<div class="grid grid-cols-2 gap-4">

<div class="bg-red-500 bg-opacity-10 p-4 rounded">

### ❌ Unsafe (locks 10M rows)

| Operation | Lock Time |
|-----------|-----------|
| `DEFAULT gen_random_uuid()` | 3-10 min |
| `DEFAULT random()` | 3-10 min |
| `ADD CHECK` in ALTER | 1-5 min |
| `ADD FOREIGN KEY` | 1-5 min |
| `ADD UNIQUE` | 2-10 min |
| `CREATE INDEX` | 2-10 min |
| `UPDATE ... all rows` | 2-10 min |

</div>

<div class="bg-green-500 bg-opacity-10 p-4 rounded">

### ✅ Safe (no long locks)

| Operation | Lock Time |
|-----------|-----------|
| `ADD COLUMN` nullable | Instant |
| Batch UPDATE 10K | 10K rows |
| `SET DEFAULT` after backfill | Instant |
| `CREATE INDEX CONCURRENTLY` | None |
| `SET NOT NULL` after backfill | Seconds |
| Add constraint separately | Seconds |

</div>

</div>

<div class="mt-4 bg-blue-500 bg-opacity-10 p-4 rounded text-center">

### Key Rule

**Add column nullable → Backfill in batches → Add constraints/indexes separately**

Each step is independently deployable with zero downtime.

</div>

---

# Running Migrations

<div class="grid grid-cols-2 gap-6">

<div>

### Apply All Pending

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

</div>

<div>

### Check Status

```bash
./scripts/migrate.sh status
```

### Create New Migration

```bash
./scripts/new-migration.sh 7 "add_payment_methods"
# Creates: migrations/V007__add_payment_methods.sql
```

</div>

</div>

---
layout: center
class: text-center
---

# Part 2: Bytebase

## Bringing Governance to Database Changes

[Learn more](https://docs.bytebase.com)

---

# Why Bytebase?

<div class="grid grid-cols-2 gap-4">

<div>

### Manual Approach
- ❌ Manual code review
- ❌ "Looks fine to me" risk assessment
- ❌ Email/Slack approvals
- ❌ Manual reverse SQL
- ❌ Git commits only
- ❌ No PII protection
- ❌ Shared DB passwords

</div>

<div>

### With Bytebase
- ✅ Automated SQL linting (50+ rules)
- ✅ Automatic risk scoring
- ✅ Configurable multi-level approvals
- ✅ 1-click data rollback
- ✅ Full audit trail
- ✅ Automatic data masking
- ✅ Just-in-time access

</div>

</div>

---

# Bytebase Risk Management

Bytebase automatically assesses risk based on conditions:

<div class="grid grid-cols-2 gap-4 pt-4">

<div class="bg-blue-500 bg-opacity-10 p-3 rounded">

**environment_id**
Target environment
- Prod = HIGH risk
- Test = MEDIUM risk
- Dev = LOW risk

</div>

<div class="bg-purple-500 bg-opacity-10 p-3 rounded">

**sql_type**
Type of SQL operation
- DROP, ALTER, TRUNCATE = HIGH
- CREATE = MEDIUM
- INSERT = LOW

</div>

<div class="bg-green-500 bg-opacity-10 p-3 rounded">

**table_rows**
Size of affected table
- > 10M rows = HIGH
- > 1M rows = MEDIUM
- < 1M rows = LOW

</div>

<div class="bg-orange-500 bg-opacity-10 p-3 rounded">

**affected_rows**
Rows impacted by DML
- > 1,000 rows = HIGH
- > 100 rows = MEDIUM
- < 100 rows = LOW

</div>

</div>

---

# Risk Rule Examples

<div class="space-y-4">

<div class="bg-red-500 bg-opacity-10 p-4 rounded">

### Rule 1: Production DDL Changes

```
environment_id == Prod
AND sql_type NOT IN (CREATE_TABLE, CREATE_VIEW, CREATE_INDEX)
```

**Risk Level: HIGH**

</div>

<div class="bg-orange-500 bg-opacity-10 p-4 rounded">

### Rule 2: Large Table Operations

```
environment_id == Prod
AND table_rows > 10000000
```

**Risk Level: HIGH**

</div>

<div class="bg-yellow-500 bg-opacity-10 p-4 rounded">

### Rule 3: All DELETE/UPDATE in Production

```
environment_id == Prod
AND sql_type IN (DELETE, UPDATE)
```

**Risk Level: HIGH**

</div>

</div>

---

# Risk-Based Approval Flow

<div class="grid grid-cols-4 gap-4 pt-6">

<div class="bg-green-500 bg-opacity-20 p-4 rounded text-center">

### LOW

**Auto-approve**

Dev/test environments
Safe DDL operations

</div>

<div class="bg-yellow-500 bg-opacity-20 p-4 rounded text-center">

### MEDIUM

**DBA review**

Non-critical prod changes
Standard migrations

</div>

<div class="bg-orange-500 bg-opacity-20 p-4 rounded text-center">

### HIGH

**Owner → DBA**

Critical prod changes
Large table operations

</div>

<div class="bg-red-500 bg-opacity-20 p-4 rounded text-center">

### CRITICAL

**CTO → DBA → Security**

Major schema changes
Data migrations

</div>

</div>

<div class="mt-8 bg-gray-500 bg-opacity-10 p-4 rounded">

**Note:** When multiple rules match, Bytebase uses the **highest applicable risk level**.

</div>

---

# Custom Approval Configuration

```yaml
# Rule 1: ALTER TABLE in Production
Title: DDL ALTER in Prod
Condition: >
  statement.sql_type == "ALTER_TABLE"
  && resource.environment_id == "prod"
Approval Flow: Project Owner -> DBA
Risk Level: HIGH

# Rule 2: CREATE TABLE in Production
Title: DDL CREATE in Prod
Condition: >
  statement.sql_type == "CREATE_TABLE"
  && resource.environment_id == "prod"
Approval Flow: DBA
Risk Level: MEDIUM

# Rule 3: DELETE in Production
Title: DML DELETE in Prod
Condition: >
  statement.sql_type == "DELETE"
  && resource.environment_id == "prod"
Approval Flow: DBA -> Security Team
Risk Level: HIGH
```

---

# SQL Review Automation

Bytebase includes 50+ automated SQL checks:

<div class="grid grid-cols-2 gap-6 pt-4">

<div>

### Schema Design
- Require primary keys
- Require NOT NULL constraints
- Prevent DROP TABLE
- Require foreign keys

### Naming Conventions
- Table naming patterns
- Column naming patterns
- Index naming patterns

</div>

<div>

### Performance
- Require indexes for large tables
- Prevent SELECT *
- Detect missing WHERE clauses

### Security
- Prevent GRANT ALL
- Require functions for DML
- Detect sensitive data access

</div>

</div>

---

# Data Protection Features

<div class="grid grid-cols-2 gap-6">

<div class="bg-blue-500 bg-opacity-10 p-4 rounded">

### Data Masking

Automatically mask sensitive data in query results:

**Semantic Types:**
- Email addresses
- Phone numbers
- Credit card numbers
- SSN / National IDs

**Example:**
```
john.doe@example.com
→ j*******@example.com
```

</div>

<div class="bg-green-500 bg-opacity-10 p-4 rounded">

### Just-in-Time Access

Instead of permanent database accounts:

1. Developer requests access
2. Specify: database, duration, reason
3. Approval (auto or manual)
4. Temporary access granted
5. Access expires automatically
6. Full audit trail recorded

</div>

</div>

---

# Multi-Environment Rollout

```
┌─────────┐     ┌─────────┐     ┌──────────┐     ┌────────────┐
│   Dev   │────>│  Test   │────>│ Staging  │────>│ Production │
└─────────┘     └─────────┘     └──────────┘     └────────────┘
   Auto           Manual          Manual         Scheduled
  rollout         review         approval       multi-level
                                required          approval
```

<div class="mt-6 grid grid-cols-4 gap-4">

<div class="text-center">

**Dev**
Auto-rollout
No approval

</div>

<div class="text-center">

**Test**
Manual rollout
Developer

</div>

<div class="text-center">

**Staging**
Manual rollout
DBA

</div>

<div class="text-center">

**Production**
Scheduled rollout
Owner + DBA + Security

</div>

</div>

---

# GitOps Workflow

<div class="grid grid-cols-5 gap-2 items-center pt-6">

<div class="bg-blue-500 bg-opacity-20 p-3 rounded text-center">

**1. Developer**
Creates migration
in git branch

</div>

<div class="text-2xl">→</div>

<div class="bg-purple-500 bg-opacity-20 p-3 rounded text-center">

**2. PR Review**
Bytebase checks
SQL + risk

</div>

<div class="text-2xl">→</div>

<div class="bg-green-500 bg-opacity-20 p-3 rounded text-center">

**3. Merge**
Triggers CI/CD
pipeline

</div>

</div>

<div class="grid grid-cols-5 gap-2 items-center mt-4">

<div class="text-2xl">↓</div>

<div></div>

<div class="bg-orange-500 bg-opacity-20 p-3 rounded text-center">

**4. Approval**
Based on risk
level

</div>

<div class="text-2xl">→</div>

<div class="bg-red-500 bg-opacity-20 p-3 rounded text-center">

**5. Rollout**
Deploy to
production

</div>

</div>

---

# Hands-On: Getting Started

<div class="space-y-4">

<div class="bg-gray-500 bg-opacity-10 p-4 rounded">

### Step 1: Start Services

```bash
docker compose up -d
```

</div>

<div class="bg-gray-500 bg-opacity-10 p-4 rounded">

### Step 2: Access Bytebase

Open `http://localhost:8080` and register admin account

</div>

<div class="bg-gray-500 bg-opacity-10 p-4 rounded">

### Step 3: Add PostgreSQL Instance

- Host: `postgres`
- Port: `5432`
- Username: `tutorial`
- Password: `tutorial_secret`

</div>

<div class="bg-gray-500 bg-opacity-10 p-4 rounded">

### Step 4: Submit Schema Change

Go to project → Databases → Edit Schema → Paste SQL → Create

</div>

</div>

---

# Best Practices

<div class="grid grid-cols-2 gap-6">

<div>

### Migration Design

✅ Small, focused migrations
✅ Always backward compatible
✅ Include rollback strategy
✅ Use transactions (`BEGIN`/`COMMIT`)
✅ Test locally first

### Risk Management

✅ Classify environments
✅ Automate SQL review
✅ Require approvals for Prod
✅ Monitor affected rows
✅ Schedule large DDL

</div>

<div>

### Team Workflow

✅ Developer writes migration
✅ Automated SQL review
✅ Risk assessment
✅ Approval based on risk
✅ Audit trail maintained

### GitOps Integration

✅ Version control all changes
✅ CI/CD pipeline integration
✅ Automated testing
✅ Environment promotion
✅ Rollback capability

</div>

</div>

---

# Summary

<div class="grid grid-cols-2 gap-4">

<div class="bg-red-500 bg-opacity-10 p-4 rounded">

### Manual Approach

- Git commits only
- Manual review
- Gut feeling risk
- Email approvals
- Manual rollback
- Shared passwords
- Manual audit

</div>

<div class="bg-green-500 bg-opacity-10 p-4 rounded">

### With Bytebase

- Git + full audit trail
- 50+ automated checks
- Rule-based scoring
- Configurable workflows
- 1-click rollback
- Just-in-time access
- Automated compliance

</div>

</div>

<div class="mt-6 bg-blue-500 bg-opacity-10 p-4 rounded text-center">

### Key Takeaways

1. **Version-control** your database schema like application code
2. **Automate** SQL review and risk assessment
3. **Require approvals** for production changes
4. **Use tools** like Bytebase for team governance

</div>

---
layout: center
class: text-center
---

# Thank You!

## Ready to take control of your database changes?

<div class="pt-8 space-y-4">

<div>

**Start the tutorial:**
```bash
docker compose up -d
./scripts/migrate.sh migrate
```

</div>

<div class="pt-4">

[Documentation](https://docs.bytebase.com) · [GitHub](https://github.com/bytebase/bytebase) · [Bytebase Cloud](https://bytebase.com)

</div>

</div>

---

# Additional Resources

<div class="grid grid-cols-2 gap-6">

<div>

### Documentation
- [Bytebase Docs](https://docs.bytebase.com)
- [Risk Best Practices](https://docs.bytebase.com/tutorials/risks-best-practice)
- [Custom Approval Tutorial](https://docs.bytebase.com/tutorials/database-change-management-with-risk-adjusted-approval-flow)
- [SQL Review Rules](https://docs.bytebase.com/sql-review/review-rules)

</div>

<div>

### Project Files
- `README.md` - Main tutorial guide
- `docs/bytebase-benefits.md` - Deep-dive on risk management
- `migrations/` - Example SQL migrations
- `scripts/` - Helper scripts

</div>

</div>
