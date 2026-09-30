# Lab 3: Risky Changes & Rollback Strategies

## Objective
Learn how to handle breaking changes safely using multi-step migrations, understand rollback strategies, and practice safe schema evolution patterns.

## Prerequisites
- Completed Labs 1 and 2
- Understanding of backward compatibility

## Step-by-Step Instructions

### Step 1: Start Environment

```bash
make setup
make migrate
make seed
```

### Step 2: Understanding Risky Operations

<div class="bg-red-500 bg-opacity-10 p-4 rounded">

**Risky Operations:**
- Dropping columns (breaks queries)
- Renaming columns (breaks applications)
- Changing column types (may lose data)
- Adding NOT NULL without default (fails on existing rows)
- Dropping tables (loses all data)

</div>

### Step 3: Safe Column Rename Pattern (Multi-Step)

Instead of directly renaming, use a 4-step process:

```bash
make new-migration V=010 DESC=rename_username_step1_add_new
```

Edit `migrations/V010__rename_username_step1_add_new.sql`:

```sql
-- Migration: V010 - Step 1 of 4: Add new column
-- Risk level: LOW
-- Backward compatible: YES
-- This is step 1 of a safe column rename

BEGIN;

-- Step 1: Add new column (nullable)
ALTER TABLE users ADD COLUMN display_name VARCHAR(100);

-- Step 2 will: Copy data from username to display_name
-- Step 3 will: Update application to use display_name
-- Step 4 will: Drop old username column

COMMIT;
```

```bash
make migrate
make psql
```

```sql
-- Step 2: Copy data
UPDATE users SET display_name = username;

-- Verify
SELECT id, username, display_name FROM users LIMIT 5;
```

### Step 4: Safe Column Type Change Pattern

```bash
\q
make new-migration V=011 DESC=safe_price_precision
```

Edit `migrations/V011__safe_price_precision.sql`:

```sql
-- Migration: V011 - Increase price precision safely
-- Risk level: MEDIUM
-- Backward compatible: YES (during transition)
-- Rollback strategy: DROP COLUMN new_price; RENAME COLUMN price TO price

BEGIN;

-- Step 1: Add new column with desired type
ALTER TABLE products ADD COLUMN new_price NUMERIC(15,4);

-- Step 2: Copy data
UPDATE products SET new_price = price;

-- Step 3: Verify data integrity
-- Run: SELECT COUNT(*) FROM products WHERE price != new_price;

-- Step 4: (In next migration) Drop old, rename new

COMMIT;
```

```bash
make migrate
make psql
```

```sql
-- Verify data was copied correctly
SELECT id, name, price, new_price
FROM products
WHERE price != new_price;

-- Should return 0 rows
```

### Step 5: Rollback Tracking Demo

```bash
\q
```

Let's practice rollback tracking:

```bash
# Check current status
make status

# Rollback tracking to version 008
make rollback V=008

# Check status after rollback
make status
```

Expected output:
```
Pending migrations:
  PENDING  V009__add_order_tracking.sql
  PENDING  V010__rename_username_step1_add_new.sql
  PENDING  V011__safe_price_precision.sql
```

```bash
# Re-apply migrations
make migrate

# Verify everything is back
make status
```

### Step 6: Create Rollback Scripts

Create actual rollback SQL for demonstration:

```bash
mkdir -p rollbacks
```

Create `rollbacks/V011__rollback.sql`:

```sql
-- Rollback for V011: safe_price_precision
-- This reverses the migration

BEGIN;

-- Drop the new column
ALTER TABLE products DROP COLUMN IF EXISTS new_price;

COMMIT;
```

Create `rollbacks/V010__rollback.sql`:

```sql
-- Rollback for V010: rename_username_step1_add_new

BEGIN;

-- Drop the new column
ALTER TABLE users DROP COLUMN IF EXISTS display_name;

COMMIT;
```

### Step 7: Practice with Large Table Simulation

```bash
make new-migration V=012 DESC=add_products_image_url
```

Edit `migrations/V012__add_products_image_url.sql`:

```sql
-- Migration: V012 - Add image URL to products
-- Risk level: LOW (small table) / HIGH (if millions of rows)
-- Backward compatible: YES
-- Note: For large tables, consider:
--   1. Using pg_repack for online DDL
--   2. Scheduling during maintenance windows
--   3. Using Bytebase approval workflow

BEGIN;

-- Add image URL column (nullable)
ALTER TABLE products ADD COLUMN image_url VARCHAR(500);
ALTER TABLE products ADD COLUMN thumbnail_url VARCHAR(500);

-- Add sample URLs
UPDATE products SET
  image_url = 'https://example.com/images/' || LOWER(REPLACE(name, ' ', '-')) || '.jpg',
  thumbnail_url = 'https://example.com/images/' || LOWER(REPLACE(name, ' ', '-')) || '-thumb.jpg'
WHERE image_url IS NULL;

COMMIT;
```

```bash
make migrate
make psql
```

```sql
-- View products with images
SELECT id, name, price, image_url
FROM products
LIMIT 5;
```

### Step 8: Safe NOT NULL Addition Pattern

```bash
\q
make new-migration V=013 DESC=add_product_sku
```

Edit `migrations/V013__add_product_sku.sql`:

```sql
-- Migration: V013 - Add SKU with safe NOT NULL pattern
-- Risk level: MEDIUM
-- Backward compatible: YES
-- Pattern: Add nullable -> Set default -> Add constraint

BEGIN;

-- Step 1: Add as nullable
ALTER TABLE products ADD COLUMN sku VARCHAR(50);

-- Step 2: Set values for existing rows
UPDATE products SET sku = 'SKU-' || LPAD(id::text, 5, '0');

-- Step 3: Add NOT NULL constraint (now safe because all rows have values)
ALTER TABLE products ALTER COLUMN sku SET NOT NULL;

-- Step 4: Add unique constraint
ALTER TABLE products ADD CONSTRAINT products_sku_unique UNIQUE (sku);

COMMIT;
```

```bash
make migrate
make psql
```

```sql
-- Verify SKU values
SELECT id, name, sku FROM products ORDER BY id;
```

### Step 9: Create a Breaking Change Example (DO NOT RUN IN PROD)

```bash
\q
make new-migration V=014 DESC=breaking_change_example
```

Edit `migrations/V014__breaking_change_example.sql`:

```sql
-- Migration: V014 - BREAKING CHANGE EXAMPLE
-- Risk level: HIGH
-- Backward compatible: NO
-- WARNING: This migration breaks existing queries!
--
-- This is for EDUCATIONAL PURPOSES ONLY.
-- In production, use the multi-step pattern instead.
--
-- Breaking changes:
-- 1. Drops a column (breaks SELECT *)
-- 2. Renames a column (breaks existing queries)
--
-- SAFE ALTERNATIVE:
-- Instead of dropping, mark as deprecated:
--   ALTER TABLE orders ADD COLUMN deprecated_at TIMESTAMPTZ DEFAULT NOW();

-- DO NOT UNCOMMENT IN PRODUCTION
-- ALTER TABLE orders DROP COLUMN status;
-- ALTER TABLE orders RENAME COLUMN total TO amount;

-- SAFE VERSION: Just add a comment
SELECT 'This migration is intentionally empty to demonstrate breaking change risks' AS message;

COMMIT;
```

### Step 10: Verify All Migrations

```bash
make status
```

```bash
make psql
```

```sql
-- Check all tables
\dt

-- Check migration history
SELECT version, filename, applied_at
FROM _schema_migrations
ORDER BY version;

-- Verify data integrity
SELECT 'users' AS table_name, COUNT(*) AS count FROM users
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'categories', COUNT(*) FROM categories
UNION ALL
SELECT 'user_preferences', COUNT(*) FROM user_preferences
ORDER BY table_name;
```

## Key Takeaways

1. **Never drop columns directly** - use multi-step rename pattern
2. **For type changes** - add new column, copy data, then swap
3. **For NOT NULL** - add nullable, populate, then add constraint
4. **Track rollbacks** - maintain rollback scripts
5. **Large tables** - require special handling (pg_repack, maintenance windows)

## Safe Migration Patterns

| Operation | Unsafe | Safe Pattern |
|-----------|--------|--------------|
| Rename column | `RENAME COLUMN` | Add new → Copy → Update app → Drop old |
| Change type | `ALTER TYPE` | Add new → Copy → Update app → Drop old |
| Add NOT NULL | `ADD NOT NULL` | Add nullable → Populate → Add constraint |
| Drop column | `DROP COLUMN` | Mark deprecated → Update app → Drop later |

## Rollback Checklist

- [ ] Create rollback script for each migration
- [ ] Test rollback in staging environment
- [ ] Document data loss implications
- [ ] Plan for application compatibility
- [ ] Schedule during maintenance windows

## Next Steps

Proceed to **Lab 4** to learn about Bytebase risk management and approval workflows.
