#!/usr/bin/env bash
set -euo pipefail

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-tutorial}"
DB_NAME="${DB_NAME:-app_db}"
export PGPASSWORD="${DB_PASSWORD:-tutorial_secret}"

PSQL="psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -v ON_ERROR_STOP=1"

echo "Dropping all tables in database: $DB_NAME"
echo ""

$PSQL -q <<'SQL'
DO $$
DECLARE
    r RECORD;
BEGIN
    -- Drop all tables (cascade drops dependent objects)
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = current_schema())
    LOOP
        EXECUTE 'DROP TABLE IF EXISTS ' || quote_ident(r.tablename) || ' CASCADE';
        RAISE NOTICE 'Dropped table: %', r.tablename;
    END LOOP;
END $$;
SQL

echo ""
echo "All tables dropped successfully."
