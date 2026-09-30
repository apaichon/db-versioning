# Lab 2: Safe Schema Changes

## Objective
Learn how to make backward-compatible schema changes that don't break existing applications. This lab covers adding columns, creating indexes, and understanding safe vs unsafe operations.

## Prerequisites
- Completed Lab 1
- Docker and Docker Compose installed

## Step-by-Step Instructions

### Step 1: Start Environment and Apply Base Migrations

```bash
make setup
make migrate
make seed
```

### Step 2: Understand Backward Compatibility

<div class="bg-green-500 bg-opacity-10 p-4 rounded">

**Safe Operations (Backward Compatible):**
- ✅ Adding nullable columns
- ✅ Adding columns with defaults
- ✅ Creating indexes
- ✅ Creating new tables
- ✅ Adding constraints (with care)

</div>

<div class="bg-red-500 bg-opacity-10 p-4 rounded">

**Unsafe Operations (Breaking Changes):**
- ❌ Dropping columns
- ❌ Renaming columns
- ❌ Changing column types
- ❌ Adding NOT NULL without default
- ❌ Dropping tables

</div>

### Step 3: Create a Safe Migration - Add User Preferences

```bash
make new-migration V=007 DESC=add_user_preferences
```

Edit `migrations/V007__add_user_preferences.sql`:

```sql
-- Migration: V007 - add_user_preferences
-- Created: 2026-09-30
-- Risk level: LOW
-- Affected tables: user_preferences (new), users
-- Backward compatible: YES
-- Rollback strategy: DROP TABLE user_preferences

BEGIN;

CREATE TABLE user_preferences (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    theme       VARCHAR(50) NOT NULL DEFAULT 'light',
    language    VARCHAR(10) NOT NULL DEFAULT 'en',
    notifications BOOLEAN NOT NULL DEFAULT true,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id)
);

CREATE INDEX idx_user_preferences_user_id ON user_preferences(user_id);

COMMENT ON TABLE user_preferences IS 'User-specific preferences and settings';
COMMENT ON COLUMN user_preferences.theme IS 'UI theme: light, dark, or system';
COMMENT ON COLUMN user_preferences.language IS 'Preferred language code (ISO 639-1)';

COMMIT;
```

### Step 4: Apply the Migration

```bash
make migrate
```

Expected output:
```
  SKIP  V001__create_users_table.sql (already applied)
  SKIP  V002__create_orders_table.sql (already applied)
  SKIP  V003__create_products_table.sql (already applied)
  SKIP  V004__add_user_profile.sql (already applied)
  SKIP  V005__create_audit_log.sql (already applied)
  SKIP  V006__create_employees_table.sql (already applied)
  APPLY V007__add_user_preferences.sql ...
Applied 1 migration(s).
```

### Step 5: Verify the New Table

```bash
make psql
```

```sql
-- Check table structure
\d user_preferences

-- Add preferences for existing users
INSERT INTO user_preferences (user_id, theme, language, notifications)
SELECT id, 'light', 'en', true
FROM users
WHERE id <= 5
ON CONFLICT (user_id) DO NOTHING;

-- View preferences with user info
SELECT
    u.email,
    up.theme,
    up.language,
    up.notifications
FROM user_preferences up
JOIN users u ON up.user_id = u.id;
```

### Step 6: Create Another Safe Migration - Add Product Categories

```bash
# Exit psql
\q

# Create new migration
make new-migration V=008 DESC=add_product_categories
```

Edit `migrations/V008__add_product_categories.sql`:

```sql
-- Migration: V008 - add_product_categories
-- Risk level: LOW
-- Backward compatible: YES
-- Rollback strategy: DROP TABLE categories; ALTER TABLE products DROP COLUMN category_id

BEGIN;

-- Create categories table
CREATE TABLE categories (
    id          BIGSERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Insert default categories
INSERT INTO categories (name, description) VALUES
  ('Electronics', 'Electronic devices and accessories'),
  ('Computers', 'Laptops, desktops, and components'),
  ('Audio', 'Headphones, speakers, and audio equipment'),
  ('Storage', 'External drives and storage devices'),
  ('Accessories', 'Cables, adapters, and other accessories')
ON CONFLICT DO NOTHING;

-- Add category_id to products (nullable for backward compatibility)
ALTER TABLE products ADD COLUMN category_id BIGINT REFERENCES categories(id);

-- Create index for faster lookups
CREATE INDEX idx_products_category_id ON products(category_id);

-- Assign categories to existing products
UPDATE products SET category_id = (
  SELECT id FROM categories WHERE name = 'Computers'
) WHERE name LIKE '%Laptop%' OR name LIKE '%Monitor%';

UPDATE products SET category_id = (
  SELECT id FROM categories WHERE name = 'Accessories'
) WHERE name LIKE '%Mouse%' OR name LIKE '%Keyboard%' OR name LIKE '%Hub%' OR name LIKE '%Pad%';

UPDATE products SET category_id = (
  SELECT id FROM categories WHERE name = 'Audio'
) WHERE name LIKE '%Headphones%' OR name LIKE '%Webcam%';

UPDATE products SET category_id = (
  SELECT id FROM categories WHERE name = 'Storage'
) WHERE name LIKE '%SSD%';

UPDATE products SET category_id = (
  SELECT id FROM categories WHERE name = 'Accessories'
) WHERE name LIKE '%Lamp%';

COMMIT;
```

### Step 7: Apply and Verify

```bash
make migrate
make psql
```

```sql
-- View products with categories
SELECT
    p.name AS product,
    p.price,
    c.name AS category
FROM products p
LEFT JOIN categories c ON p.category_id = c.id
ORDER BY c.name, p.name;

-- Count products by category
SELECT
    c.name AS category,
    COUNT(p.id) AS product_count,
    AVG(p.price) AS avg_price
FROM categories c
LEFT JOIN products p ON p.category_id = c.id
GROUP BY c.name
ORDER BY product_count DESC;
```

### Step 8: Safe Column Addition Pattern

Create a migration demonstrating safe column addition:

```bash
\q
make new-migration V=009 DESC=add_order_tracking
```

Edit `migrations/V009__add_order_tracking.sql`:

```sql
-- Migration: V009 - add_order_tracking
-- Risk level: LOW
-- Backward compatible: YES
-- Rollback strategy: ALTER TABLE orders DROP COLUMN tracking_number; DROP TABLE order_events

BEGIN;

-- Add tracking number (nullable)
ALTER TABLE orders ADD COLUMN tracking_number VARCHAR(100);
ALTER TABLE orders ADD COLUMN shipped_at TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN delivered_at TIMESTAMPTZ;

-- Create order events table for tracking status changes
CREATE TABLE order_events (
    id          BIGSERIAL PRIMARY KEY,
    order_id    BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    status      VARCHAR(50) NOT NULL,
    notes       TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_order_events_order_id ON order_events(order_id);
CREATE INDEX idx_order_events_created_at ON order_events(created_at);

-- Add some sample tracking data
UPDATE orders SET
  tracking_number = 'TRK' || LPAD(id::text, 6, '0'),
  shipped_at = created_at + INTERVAL '1 day'
WHERE status = 'shipped';

UPDATE orders SET
  tracking_number = 'TRK' || LPAD(id::text, 6, '0'),
  shipped_at = created_at + INTERVAL '1 day',
  delivered_at = created_at + INTERVAL '3 days'
WHERE status = 'completed';

COMMIT;
```

### Step 9: Verify Order Tracking

```bash
make migrate
make psql
```

```sql
-- View orders with tracking
SELECT
    o.id,
    u.email,
    o.status,
    o.tracking_number,
    o.shipped_at,
    o.delivered_at
FROM orders o
JOIN users u ON o.user_id = u.id
WHERE o.tracking_number IS NOT NULL
ORDER BY o.id;

-- View order events
SELECT * FROM order_events ORDER BY created_at DESC LIMIT 10;
```

### Step 10: Check Final Status

```bash
\q
make status
```

## Key Takeaways

1. **Always add nullable columns** or columns with defaults
2. **Use LEFT JOIN** when querying new foreign keys
3. **Create indexes** for new foreign key columns
4. **Document migrations** with risk level and rollback strategy
5. **Test migrations** against a copy of production data

## Safe Migration Checklist

- [ ] New columns are nullable or have defaults
- [ ] Foreign keys reference existing tables
- [ ] Indexes created for new foreign keys
- [ ] Migration wrapped in BEGIN/COMMIT
- [ ] Rollback strategy documented
- [ ] Tested locally before production

## Next Steps

Proceed to **Lab 3** to learn about risky changes and rollback strategies.
