# Lab 3: Safe DDL on Large Tables (10M+ Records)

## Objective
Learn how to safely add columns to tables with millions of rows without locking the database or causing downtime. This lab includes a script to generate 10M+ records and demonstrates batch backfilling, concurrent index creation, and safe constraint addition.

## The Challenge

When a table has **COLUMNS, adding a column with a default value or backfilling data can:
- Lock the table for minutes or hours
- Block all reads and writes
- Cause application timeouts
- Result in production outages

## Prerequisites
- Completed Labs 1 and 2
- Docker and Docker Compose installed
- At least 2GB free disk space (for 10M rows)

## Step-by-Step Instructions

### Step 1: Start Environment

```bash
make setup
make migrate MAX_VERSION=003
make seed TABLES="users products orders order_items"
```

### Step 2: Generate 10 Million Records

Use the provided script to generate a large `transactions` table:

```bash
# Generate 10 million rows (batch size: 50,000)
./scripts/generate-large-data.sh 10000000 50000
```

Or use the make command:

```bash
make large-data COUNT=10000000
```

For quick testing, generate 1 million instead:

```bash
./scripts/generate-large-data.sh 1000000 50000
```

Expected output:
```
Generating large dataset: 10000000 rows (batch size: 50000)

Table 'transactions' ready.
Current rows: 0
Inserting 10000000 more rows in batches of 50000...
  Batch 1/200 done — 50000/10000000 rows
  Batch 2/200 done — 100000/10000000 rows
  ...
  Batch 200/200 done — 10000000/10000000 rows

Done! Final count:
 total_rows
------------
   10000000

 table_size
------------
 680 MB
```

### Step 3: Verify the Large Table

```bash
make psql
```

```sql
-- Check table size
SELECT
  COUNT(*) AS total_rows,
  pg_size_pretty(pg_total_relation_size('transactions')) AS total_size
FROM transactions;

-- Check table structure (no 'category' column yet)
\d transactions

-- Sample data
SELECT * FROM transactions LIMIT 5;

\q
```

### Step 4: When ADD COLUMN is NOT Safe

Adding a nullable column is instant. But **adding a column with a volatile DEFAULT** forces PostgreSQL to **rewrite every row**.

<div class="bg-red-500 bg-opacity-10 p-4 rounded">

### ❌ Dangerous: ADD COLUMN with Volatile Default

```sql
-- Case 1: DEFAULT with volatile function → REWRITES ENTIRE TABLE
ALTER TABLE transactions
  ADD COLUMN reference_id UUID DEFAULT gen_random_uuid();
-- This evaluates gen_random_uuid() for ALL 10M rows!
-- Table is LOCKED for minutes. All reads/writes blocked.

-- Case 2: DEFAULT with random() → REWRITES ENTIRE TABLE
ALTER TABLE transactions
  ADD COLUMN priority INTEGER DEFAULT (random() * 10)::int;
-- Same problem — random() is volatile, must evaluate per row.

-- Case 3: ADD COLUMN + CHECK constraint → FULL TABLE SCAN
ALTER TABLE transactions
  ADD COLUMN score INTEGER DEFAULT 0,
  ADD CONSTRAINT score_check CHECK (score >= 0 AND score <= 100);
-- CHECK constraint scans all 10M rows while holding lock.

-- Case 4: ADD COLUMN + NOT NULL without default → FAILS
ALTER TABLE transactions
  ADD COLUMN label VARCHAR(50) NOT NULL;
-- ERROR: column "label" contains null values
-- Cannot add NOT NULL to existing rows without a default.
```

**Why these are slow on 10M rows:**

| Operation | Why Slow | Lock Duration |
|-----------|----------|---------------|
| `DEFAULT gen_random_uuid()` | Volatile function → rewrite all rows | 3-10 min |
| `DEFAULT random()` | Volatile function → rewrite all rows | 3-10 min |
| `ADD CHECK constraint` | Full table scan to validate | 1-5 min |
| `ADD FOREIGN KEY` | Full table scan + lock referenced table | 1-5 min |
| `ADD UNIQUE constraint` | Full table scan + build index | 2-10 min |
| `ALTER COLUMN TYPE` | Rewrite all rows + cast each value | 5-20 min |

</div>

### Step 5: The Safe Way — Step 1: Add Nullable Column (No Default)

Adding a **nullable column with NO default** is metadata-only in PostgreSQL. It doesn't rewrite any rows.

```bash
make new-migration V=010 DESC=add_category_to_transactions_safe
```

Edit `migrations/V010__add_category_to_transactions_safe.sql`:

```sql
-- Migration: V010 - Add category column to transactions (SAFE)
-- Risk level: LOW (metadata-only change)
-- Table size: 10M+ rows
-- Backward compatible: YES
-- Pattern: Add nullable column (instant, no table rewrite)
-- Rollback strategy: ALTER TABLE transactions DROP COLUMN category

BEGIN;

-- Step 1: Add column as nullable (NO default!)
-- This is instant — PostgreSQL only updates metadata
-- No table rewrite, no locking
ALTER TABLE transactions ADD COLUMN category VARCHAR(50);

COMMIT;
```

Apply the migration:
```bash
make migrate
```

Verify it was instant:
```bash
make psql
```

```sql
-- Column exists but is NULL for all rows
SELECT category, COUNT(*) FROM transactions GROUP BY category;
-- Expected:
--  category |  count
-- ----------+----------
--  (null)   | 10000000

\q
```

**Key point:** Adding a nullable column is instant even on 10M+ rows. PostgreSQL only updates the table metadata.

### Step 5b: Safe Alternative for Volatile Defaults (UUID Example)

If you need a column with `gen_random_uuid()` (or any volatile default), **never** add it with `DEFAULT` directly. Use this 3-step pattern instead:

```bash
make new-migration V=010b DESC=add_reference_id_safe
```

Edit `migrations/V010b__add_reference_id_safe.sql`:

```sql
-- Migration: V010b - Add reference_id UUID safely (NO volatile default)
-- Risk level: LOW (metadata only)
-- Pattern: Add nullable → Backfill in batches → Add default for NEW rows only

BEGIN;

-- Step 1: Add column as nullable, NO default
-- Instant — no table rewrite, no locking
ALTER TABLE transactions ADD COLUMN reference_id UUID;

COMMIT;
```

**Step 2: Batch backfill UUIDs** (separate script, not in migration):

```bash
# Backfill UUID in batches — no long locks
./scripts/backfill-uuid.sh 10000
```

Create `scripts/backfill-uuid.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-tutorial}"
DB_NAME="${DB_NAME:-app_db}"
export PGPASSWORD="${DB_PASSWORD:-tutorial_secret}"

PSQL="psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -v ON_ERROR_STOP=1"

BATCH_SIZE="${1:-10000}"
echo "Backfilling reference_id UUID in batches of $BATCH_SIZE..."

while true; do
  UPDATED=$($PSQL -tAc "
    UPDATE transactions
    SET reference_id = gen_random_uuid()
    WHERE id IN (
      SELECT id FROM transactions
      WHERE reference_id IS NULL
      LIMIT $BATCH_SIZE
    )
    RETURNING 1
  " | wc -l | tr -d ' ')

  if [ "$UPDATED" -eq 0 ]; then
    echo "Backfill complete!"
    break
  fi

  REMAINING=$($PSQL -tAc "SELECT COUNT(*) FROM transactions WHERE reference_id IS NULL")
  echo "  Updated $UPDATED rows — $REMAINING remaining"
done
```

**Step 3: Add DEFAULT for new rows only** (after backfill):

```sql
-- Migration: Add default for NEW rows only (existing rows already have UUIDs)
-- This is safe because the default only applies to future INSERTs
ALTER TABLE transactions ALTER COLUMN reference_id SET DEFAULT gen_random_uuid();

-- Add NOT NULL (safe — all existing rows already have values)
ALTER TABLE transactions ALTER COLUMN reference_id SET NOT NULL;
```

**Why this is safe:**
- Step 1: `ADD COLUMN` nullable = instant (metadata only)
- Step 2: Batch UPDATE = only locks 10K rows at a time
- Step 3: `SET DEFAULT` = metadata only (doesn't touch existing rows)

### Step 6: The SAFE Way — Step 2: Batch Backfill Category

Instead of one massive UPDATE, backfill in **small batches** to avoid long locks.

Create `scripts/backfill-category.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-tutorial}"
DB_NAME="${DB_NAME:-app_db}"
export PGPASSWORD="${DB_PASSWORD:-tutorial_secret}"

PSQL="psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -v ON_ERROR_STOP=1"

BATCH_SIZE="${1:-10000}"
echo "Backfilling category column in batches of $BATCH_SIZE..."

TOTAL=$($PSQL -tAc "SELECT COUNT(*) FROM transactions WHERE category IS NULL")
echo "Rows to backfill: $TOTAL"

while true; do
  UPDATED=$($PSQL -tAc "
    UPDATE transactions
    SET category = CASE
      WHEN amount > 500 THEN 'premium'
      WHEN amount > 100 THEN 'standard'
      ELSE 'basic'
    END
    WHERE id IN (
      SELECT id FROM transactions
      WHERE category IS NULL
      LIMIT $BATCH_SIZE
    )
    RETURNING 1
  " | wc -l | tr -d ' ')

  if [ "$UPDATED" -eq 0 ]; then
    echo "Backfill complete!"
    break
  fi

  REMAINING=$($PSQL -tAc "SELECT COUNT(*) FROM transactions WHERE category IS NULL")
  echo "  Updated $UPDATED rows — $REMAINING remaining"
done

echo ""
$PSQL -c "SELECT category, COUNT(*) FROM transactions GROUP BY category ORDER BY count+count;"
```

Run the backfill:
```bash
chmod +x scripts/backfill-category.sh
./scripts/backfill-category.sh 10000
```

Expected output:
```
Backfilling category column in batches of 10000...
Rows to backfill: 10000000
  Updated 10000 rows — 9990000 remaining
  Updated 10000 rows — 9980000 remaining
  ...
  Updated 10000 rows — 0 remaining
Backfill complete!

 category |  count
----------+---------
 basic    | 3328765
 premium  | 3337421
 standard | 3333814
```

**Why this is safe:**
- Each batch only locks 10,000 rows (not the whole table)
- Other queries can read/write during backfill
- If interrupted, just re-run the script (idempotent)
- No long-running transaction

### Step 7: The SAFE Way — Step 3: Add NOT NULL Constraint

After backfilling, add the NOT NULL constraint safely.

```bash
make new-migration V=011 DESC=add_category_not_null_safe
```

Edit `migrations/V011__add_category_not_null_safe.sql`:

```sql
-- Migration: V011 - Add NOT NULL to category (SAFE)
-- Risk level: MEDIUM (validates all rows)
-- Prerequisite: V010 applied + backfill complete
-- Rollback strategy: ALTER TABLE transactions ALTER COLUMN category DROP NOT NULL

BEGIN;

-- Verify no NULL values remain before adding constraint
DO $$
DECLARE
  null_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO null_count FROM transactions WHERE category IS NULL;
  IF null_count > 0 THEN
    RAISE EXCEPTION 'Cannot add NOT NULL: % rows still have NULL category', null_count;
  END IF;
END $$;

-- Safe to add NOT NULL (all rows have values)
ALTER TABLE transactions ALTER COLUMN category SET NOT NULL;

COMMIT;
```

Apply the migration:
```bash
make migrate
```

### Step 8: The SAFE Way — Step 4: Create Index Concurrently

Creating an index normally locks the table for writes. Use `CONCURRENTLY` to avoid locking.

```bash
make new-migration V=012 DESC=add_category_index_concurrently
```

Edit `migrations/V012__add_category_index_concurrently.sql`:

```sql
-- Migration: V012 - Create index on category (SAFE)
-- Risk level: LOW (concurrent, no locking)
-- Note: CREATE INDEX CONCURRENTLY cannot run inside a transaction block

-- Don't use BEGIN/COMMIT with CONCURRENTLY!
CREATE INDEX CONCURRENTLY idx_transactions_category ON transactions(category);

-- Create partial index for premium transactions (common query)
CREATE INDEX CONCURRENTLY idx_transactions_premium
  ON transactions(created_at)
  WHERE category = 'premium';
```

Apply the migration:
```bash
make migrate
```

Verify the indexes:
```bash
make psql
```

```sql
-- Check indexes
\d transactions

-- Test query performance
EXPLAIN ANALYZE
SELECT * FROM transactions WHERE category = 'premium' LIMIT 10;

\q
```

### Step 9: Test API with Large Table

Add a transactions endpoint to the API. Edit `api/server.js` and add:

```javascript
// Get transactions by category
app.get('/api/v1/transactions/category/:category', async (req, res) => {
  try {
    const { category } = req.params;
    const result = await pool.query(
      'SELECT id, user_id, amount, status, category, created_at FROM transactions WHERE category = $1 ORDER BY id LIMIT 20',
      [category]
    );

    res.json({
      success: true,
      version: 'v1',
      count: result.rows.length,
      data: result.rows
    });
  } catch (error) {
    console.error('Error fetching transactions:', error.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});
```

Restart the API and test:
```bash
make api-start

# In another terminal
curl http://localhost:3000/api/v1/transactions/category/premium
```

### Step 10: Verify the Complete Safe Migration

```bash
make psql
```

```sql
-- Final table structure
\d transactions

-- Data distribution
SELECT category, COUNT(*) AS count
FROM transactions
GROUP BY category
ORDER BY count DESC;

-- Table and index sizes
SELECT
  relname AS object,
  pg_size_pretty(pg_total_relation_size(relid)) AS size
FROM pg_catalog.pg_statio_user_tables
WHERE relname = 'transactions';

-- Migration history
SELECT version, filename FROM _schema_migrations ORDER BY version;

\q
```

### Step 11: Clean Up

```bash
# Stop API (Ctrl+C)
make down
```

## Summary: Safe DDL on Large Tables

```
┌────────────────────────────────────────────────────────────────────┐
│  SAFE DDL ON 10M+ ROW TABLE                                        │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Step 1: ADD nullable column (instant)                             │
│  ┌──────────────────────────────────────────────┐                  │
│  │ ALTER TABLE transactions                     │                  │
│  │   ADD COLUMN category VARCHAR(50);           │                  │
│  │ ✓ Metadata only — no table rewrite           │                  │
│  │ ✓ Instant even on 10M rows                   │                  │
│  └──────────────────────────────────────────────┘                  │
│                      ↓                                             │
│  Step 2: BATCH BACKFILL (no long locks)                           │
│  ┌──────────────────────────────────────────────┐                  │
│  │ UPDATE ... WHERE id IN (                     │                  │
│  │   SELECT id ... LIMIT 10000                  │                  │
│  │ )                                            │                  │
│  │ ✓ Only locks 10K rows per batch              │                  │
│  │ ✓ Table remains readable/writable            │                  │
│  │ ✓ Idempotent — can resume if interrupted     │                  │
│  └──────────────────────────────────────────────┘                  │
│                      ↓                                             │
│  Step 3: ADD NOT NULL constraint (after backfill)                  │
│  ┌──────────────────────────────────────────────┐                  │
│  │ ALTER TABLE transactions                     │                  │
│  │   ALTER COLUMN category SET NOT NULL;        │                  │
│  │ ✓ Validates all rows have values             │                  │
│  │ ✓ Quick scan, no rewrite                     │                  │
│  └──────────────────────────────────────────────┘                  │
│                      ↓                                             │
│  Step 4: CREATE INDEX CONCURRENTLY (no write locks)               │
│  ┌──────────────────────────────────────────────┐                  │
│  │ CREATE INDEX CONCURRENTLY                    │                  │
│  │   idx_cat ON transactions(category);         │                  │
│  │ ✓ No blocking — table stays writable         │                  │
│  │ ✓ Takes longer but zero downtime             │                  │
│  └──────────────────────────────────────────────┘                  │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
```

## Key Takeaways

1. **Adding nullable columns is instant** — PostgreSQL only updates metadata
2. **Never backfill in one UPDATE** — Use batches of 10K-50K rows
3. **Use CREATE INDEX CONCURRENTLY** — Avoids write locks during index creation
4. **Validate before NOT NULL** — Check for NULLs before adding constraint
5. **Each step is separately deployable** — No single massive migration

## Unsafe vs Safe Comparison

| Operation | Unsafe | Safe | Lock Duration |
|-----------|--------|------|---------------|
| Add nullable column | N/A | `ADD COLUMN` (nullable) | Instant |
| Add column with constant default | `ADD COLUMN DEFAULT 'x'` | Same (PG 11+ fast default) | Instant |
| Add column with volatile default | `ADD COLUMN DEFAULT gen_random_uuid()` | Add nullable → batch backfill → set default | 10K rows/batch vs 10M locked |
| Backfill data | `UPDATE ... WHERE all` | Batch UPDATE (10K rows) | 10K rows vs 10M rows |
| Add NOT NULL | `ADD NOT NULL` directly | Validate first, then add | Seconds vs minutes |
| Add CHECK constraint | `ADD CHECK` in same ALTER | Add column → backfill → add constraint separately | Seconds vs minutes |
| Create index | `CREATE INDEX` | `CREATE INDEX CONCURRENTLY` | None vs minutes |

## When ADD COLUMN is NOT Safe

| Pattern | Why It's Slow | Safe Alternative |
|---------|---------------|------------------|
| `DEFAULT gen_random_uuid()` | Volatile → rewrites all rows | Add nullable → batch backfill → set default |
| `DEFAULT random()` | Volatile → rewrites all rows | Add nullable → batch backfill |
| `ADD CHECK (expr)` | Scans all rows under lock | Add column → backfill → add constraint separately |
| `ADD FOREIGN KEY` | Scans + locks both tables | Add column → backfill → add FK separately |
| `ADD UNIQUE` | Scans + builds index under lock | Add column → backfill → `CREATE UNIQUE INDEX CONCURRENTLY` |
| `ALTER COLUMN TYPE` | Rewrites + casts all rows | Add new column → backfill → swap in app → drop old |

## Commands Reference

| Command | Description |
|---------|-------------|
| `./scripts/generate-large-data.sh 10000000 50000` | Generate 10M rows |
| `./scripts/backfill-category.sh 10000` | Backfill in batches |
| `make migrate` | Apply migrations |
| `make psql` | Open database shell |

## Next Steps

Proceed to **Lab 4** to learn about Bytebase risk management and approval workflows for large table changes.
