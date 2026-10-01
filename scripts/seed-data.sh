#!/usr/bin/env bash
set -euo pipefail

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-tutorial}"
DB_NAME="${DB_NAME:-app_db}"
export PGPASSWORD="${DB_PASSWORD:-tutorial_secret}"

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SEED_DIR="$SCRIPT_DIR/seed"

PSQL="psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -v ON_ERROR_STOP=1"

# Available seed files
declare -A SEED_FILES=(
  ["users"]="seed_users.sql"
  ["products"]="seed_products.sql"
  ["orders"]="seed_orders.sql"
  ["order_items"]="seed_order_items.sql"
)

# If no arguments, seed all tables
if [ $# -eq 0 ]; then
  TABLES=("users" "products" "orders" "order_items")
else
  TABLES=("$@")
fi

echo "Seeding database: $DB_NAME"
echo "Tables: ${TABLES[*]}"
echo ""

# Detect if email_address column exists (V007 applied)
HAS_EMAIL_ADDRESS=$($PSQL -tAc "
  SELECT 1 FROM information_schema.columns
  WHERE table_name = 'users' AND column_name = 'email_address'
" 2>/dev/null || echo "0")

for table in "${TABLES[@]}"; do
  seed_file="${SEED_FILES[$table]:-}"

  if [ -z "$seed_file" ]; then
    echo "ERROR: Unknown table '$table'"
    echo "Available tables: ${!SEED_FILES[*]}"
    exit 1
  fi

  # Use v2 seed for users if email_address column exists
  if [ "$table" = "users" ] && [ "$HAS_EMAIL_ADDRESS" = "1" ]; then
    seed_file="seed_users_v2.sql"
    echo "  (detected email_address column, using v2 seed)"
  fi

  seed_path="$SEED_DIR/$seed_file"

  if [ ! -f "$seed_path" ]; then
    echo "ERROR: Seed file not found: $seed_path"
    exit 1
  fi

  echo "  Seeding $table..."
  $PSQL -q -f "$seed_path"
done

echo ""
echo "Seed data inserted successfully."
echo ""
echo "Summary:"
$PSQL -c "
SELECT 'users' AS table_name, COUNT(*) AS count FROM users
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
ORDER BY table_name;"
