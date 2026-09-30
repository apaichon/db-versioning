#!/usr/bin/env bash
set -euo pipefail

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-tutorial}"
DB_NAME="${DB_NAME:-app_db}"
export PGPASSWORD="${DB_PASSWORD:-tutorial_secret}"

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SEED_FILE="$SCRIPT_DIR/migrations/seed_data.sql"

PSQL="psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -v ON_ERROR_STOP=1"

echo "Seeding database with sample data..."
$PSQL -q -f "$SEED_FILE"
echo "Seed data inserted successfully."

echo ""
echo "Summary:"
$PSQL -c "SELECT 'users' AS table_name, COUNT(*) AS count FROM users
          UNION ALL
          SELECT 'products', COUNT(*) FROM products
          UNION ALL
          SELECT 'orders', COUNT(*) FROM orders
          UNION ALL
          SELECT 'order_items', COUNT(*) FROM order_items
          ORDER BY table_name;"
