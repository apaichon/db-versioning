#!/usr/bin/env bash
set -euo pipefail

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-tutorial}"
DB_NAME="${DB_NAME:-app_db}"
export PGPASSWORD="${DB_PASSWORD:-tutorial_secret}"

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SEED_DIR="$SCRIPT_DIR/migrations"

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

echo "Seeding database with sample data..."
echo "Tables: ${TABLES[*]}"
echo ""

for table in "${TABLES[@]}"; do
  seed_file="${SEED_FILES[$table]:-}"
  
  if [ -z "$seed_file" ]; then
    echo "ERROR: Unknown table '$table'"
    echo "Available tables: ${!SEED_FILES[*]}"
    exit 1
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
