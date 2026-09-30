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

TOTAL=$($PSQL -tAc "SELECT COUNT(*) FROM transactions WHERE reference_id IS NULL" 2>/dev/null || echo "0")

if [ "$TOTAL" = "0" ]; then
  echo "No rows to backfill (or column doesn't exist yet)."
  exit 0
fi

echo "Rows to backfill: $TOTAL"

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

echo ""
echo "Sample results:"
$PSQL -c "SELECT id, reference_id FROM transactions LIMIT 5;"
