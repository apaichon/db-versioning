#!/usr/bin/env bash
set -euo pipefail

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-tutorial}"
export PGPASSWORD="${DB_PASSWORD:-tutorial_secret}"

PSQL_ADMIN="psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d postgres -v ON_ERROR_STOP=1"

echo "Creating environment databases..."
echo ""

for ENV in test uat prod; do
  DB="app_${ENV}"

  # Create database if not exists
  EXISTS=$($PSQL_ADMIN -tAc "SELECT 1 FROM pg_database WHERE datname = '$DB'" 2>/dev/null || echo "0")
  if [ "$EXISTS" = "1" ]; then
    echo "  SKIP  $DB (already exists)"
    continue
  fi

  $PSQL_ADMIN -c "CREATE DATABASE $DB;"
  echo "  CREATE $DB"
done

echo ""
echo "Databases created:"
$PSQL_ADMIN -c "SELECT datname FROM pg_database WHERE datname LIKE 'app_%' ORDER BY datname;"

echo ""
echo "Next steps:"
echo "  make migrate ENV=test  MAX_VERSION=003"
echo "  make migrate ENV=uat   MAX_VERSION=003"
echo "  make migrate ENV=prod  MAX_VERSION=003"
echo "  make seed   ENV=test   TABLES='users products orders order_items'"
echo "  make seed   ENV=uat    TABLES='users products orders order_items'"
echo "  make seed   ENV=prod   TABLES='users products orders order_items'"
