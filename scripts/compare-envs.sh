#!/usr/bin/env bash
set -euo pipefail

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-tutorial}"
export PGPASSWORD="${DB_PASSWORD:-tutorial_secret}"

echo "=========================================="
echo "Schema Comparison Across Environments"
echo "=========================================="
echo ""

for ENV in test uat prod; do
  DB="app_${ENV}"
  echo "--- $DB ---"

  TABLES=$(psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB -tAc "
    SELECT string_agg(tablename, ', ' ORDER BY tablename)
    FROM pg_tables WHERE schemaname = 'public'
  " 2>/dev/null || echo "(database not accessible)")

  echo "  Tables: $TABLES"

  MIGRATIONS=$(psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB -tAc "
    SELECT string_agg(version, ', ' ORDER BY version)
    FROM _schema_migrations
  " 2>/dev/null || echo "(no migration tracking)")

  echo "  Migrations applied: $MIGRATIONS"

  USER_COLS=$(psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB -tAc "
    SELECT string_agg(column_name, ', ' ORDER BY ordinal_position)
    FROM information_schema.columns
    WHERE table_name = 'users' AND table_schema = 'public'
  " 2>/dev/null || echo "(users table not found)")

  echo "  users columns: $USER_COLS"
  echo ""
done

echo "=========================================="
echo "Differences"
echo "=========================================="
echo ""
echo "test:  V001-V003 only (basic schema, 'email' column)"
echo "uat:   V001-V007 (full schema, 'email_address' column)"
echo "prod:  V001-V007 (full schema, 'email_address' column)"
echo ""
echo "In Bytebase:"
echo "  1. Add all 3 databases as instances"
echo "  2. Create environments: Test, UAT, Prod"
echo "  3. Assign app_test → Test, app_uat → UAT, app_prod → Prod"
echo "  4. Configure risk rules per environment"
echo "  5. Set approval flows: Test=auto, UAT=DBA, Prod=Owner+DBA"
