# Lab 1: Basic Migration Workflow (V001-V003)

## Objective
Learn the fundamentals of database version control by applying the first three migrations that create the core schema: users, orders, and products tables.

## Prerequisites
- Docker and Docker Compose installed
- PostgreSQL client (`psql`) installed
- Basic SQL knowledge

## Step-by-Step Instructions

### Step 1: Start the Environment

```bash
make setup
```

This starts:
- PostgreSQL on `localhost:5432`
- Bytebase on `http://localhost:8080`

Wait for the message: "PostgreSQL: localhost:5432"

### Step 2: Check Initial Migration Status

```bash
make status
```

Expected output:
```
Applied migrations:
 version | filename | applied_at
---------+----------+------------
(0 rows)

Pending migrations:
  PENDING  V001__create_users_table.sql
  PENDING  V002__create_orders_table.sql
  PENDING  V003__create_products_table.sql
  PENDING  V004__add_user_profile.sql
  PENDING  V005__create_audit_log.sql
  PENDING  V006__create_employees_table.sql
```

### Step 3: Examine Migration Files

Let's look at what each migration does:

```bash
# View V001 - Users table
cat migrations/V001__create_users_table.sql
```

```sql
CREATE TABLE users (
    id          BIGSERIAL PRIMARY KEY,
    email       VARCHAR(255) NOT NULL UNIQUE,
    username    VARCHAR(100) NOT NULL,
    password    VARCHAR(255) NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
```

```bash
# View V002 - Orders table
cat migrations/V002__create_orders_table.sql
```

```sql
CREATE TABLE orders (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    total       NUMERIC(12,2) NOT NULL DEFAULT 0,
    status      VARCHAR(50)  NOT NULL DEFAULT 'pending',
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status);
```

```bash
# View V003 - Products and Order Items
cat migrations/V003__create_products_table.sql
```

```sql
CREATE TABLE products (
    id          BIGSERIAL PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    description TEXT,
    price       NUMERIC(10,2) NOT NULL,
    stock       INTEGER NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE order_items (
    id          BIGSERIAL PRIMARY KEY,
    order_id    BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id  BIGINT NOT NULL REFERENCES products(id),
    quantity    INTEGER NOT NULL DEFAULT 1,
    unit_price  NUMERIC(10,2) NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### Step 4: Apply Migrations V001-V003

```bash
make migrate
```

Expected output:
```
Applying migrations...
  APPLY V001__create_users_table.sql ...
  APPLY V002__create_orders_table.sql ...
  APPLY V003__create_products_table.sql ...
  APPLY V004__add_user_profile.sql ...
  APPLY V005__create_audit_log.sql ...
  APPLY V006__create_employees_table.sql ...
Applied 6 migration(s).
```

### Step 5: Verify Tables Created

```bash
make psql
```

In the PostgreSQL shell:
```sql
-- List all tables
\dt

-- Expected output:
--              List of relations
--  Schema |     Name      | Type  |  Owner
-- --------+---------------+-------+----------
--  public | _schema_migrations | table | tutorial
--  public | audit_log     | table | tutorial
--  public | employees     | table | tutorial
--  public | order_items   | table | tutorial
--  public | orders        | table | tutorial
--  public | products      | table | tutorial
--  public | users         | table | tutorial

-- Check users table structure
\d users

-- Check indexes
\d idx_users_email
```

### Step 6: Examine Migration Tracking

```sql
-- View migration history
SELECT version, filename, applied_at, checksum
FROM _schema_migrations
ORDER BY version;
```

Expected output:
```
 version |            filename            |          applied_at          | checksum
---------+--------------------------------+----------------------------+----------
 001     | V001__create_users_table.sql   | 2026-09-30 10:00:00+00     | abc123...
 002     | V002__create_orders_table.sql  | 2026-09-30 10:00:01+00     | def456...
 003     | V003__create_products_table.sql| 2026-09-30 10:00:02+00     | ghi789...
 ...
```

### Step 7: Seed Sample Data

```bash
# Exit psql first
\q

# Seed the database
make seed
```

Expected output:
```
Seeding database with sample data...
Seed data inserted successfully.

Summary:
 table_name | count
------------+-------
 order_items|    23
 orders     |    15
 products   |    10
 users      |    10
```

### Step 8: Explore the Data

```bash
make psql
```

```sql
-- View users
SELECT id, email, username, first_name, last_name, is_active
FROM users
LIMIT 5;

-- View products
SELECT id, name, price, stock
FROM products
LIMIT 5;

-- View orders with user info
SELECT o.id, u.email, o.total, o.status, o.created_at
FROM orders o
JOIN users u ON o.user_id = u.id
LIMIT 5;

-- View order details
SELECT
    o.id AS order_id,
    u.email,
    p.name AS product,
    oi.quantity,
    oi.unit_price,
    (oi.quantity * oi.unit_price) AS line_total
FROM order_items oi
JOIN orders o ON oi.order_id = o.id
JOIN users u ON o.user_id = u.id
JOIN products p ON oi.product_id = p.id
ORDER BY o.id
LIMIT 10;

-- Calculate total revenue by status
SELECT
    status,
    COUNT(*) AS order_count,
    SUM(total) AS total_revenue
FROM orders
GROUP BY status
ORDER BY total_revenue DESC;

-- Top selling products
SELECT
    p.name,
    SUM(oi.quantity) AS total_sold,
    SUM(oi.quantity * oi.unit_price) AS revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.id
GROUP BY p.name
ORDER BY total_sold DESC
LIMIT 5;
```

### Step 9: Verify Migration Status

```bash
make status
```

Expected output:
```
Applied migrations:
 version |            filename            |          applied_at
---------+--------------------------------+----------------------------
 001     | V001__create_users_table.sql   | 2026-09-30 10:00:00+00
 002     | V002__create_orders_table.sql  | 2026-09-30 10:00:01+00
 003     | V003__create_products_table.sql| 2026-09-30 10:00:02+00
 ...

Pending migrations:
  (none)
```

### Step 10: Clean Up

```bash
# Exit psql
\q

# Stop containers
make down
```

## Key Takeaways

1. **Migration files** are named with version numbers for ordered execution
2. **Migration tracking** table records which migrations have been applied
3. **Checksums** ensure migration files haven't been modified after application
4. **Idempotent migrations** can be run multiple times safely
5. **Seed data** helps test and demonstrate the schema

## Common Commands Reference

| Command | Description |
|---------|-------------|
| `make setup` | Start PostgreSQL and Bytebase |
| `make status` | Show migration status |
| `make migrate` | Apply all pending migrations |
| `make seed` | Insert sample data |
| `make psql` | Open PostgreSQL shell |
| `make down` | Stop containers |

## Troubleshooting

**Port already in use:**
```bash
# Check what's using port 5432
lsof -i :5432

# Stop the service or change port in docker-compose.yml
```

**Cannot connect to database:**
```bash
# Check if PostgreSQL is running
docker compose ps

# Restart services
make reset
```

**Migration fails:**
```bash
# Check error message
# Fix the SQL in the migration file
# Reset and try again
make reset
make migrate
```

## Next Steps

Proceed to **Lab 2** to learn about safe schema changes and adding new columns.
