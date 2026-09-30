#!/usr/bin/env bash
set -euo pipefail

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-tutorial}"
DB_NAME="${DB_NAME:-app_db}"
export PGPASSWORD="${DB_PASSWORD:-tutorial_secret}"

COUNT="${1:-1000000}"
BATCH_SIZE="${2:-50000}"

PSQL="psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -v ON_ERROR_STOP=1"

echo "Generating large dataset: $COUNT rows (batch size: $BATCH_SIZE)"
echo ""

# Create the large table if it doesn't exist
$PSQL -q <<'SQL'
CREATE TABLE IF NOT EXISTS transactions (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL,
    amount      NUMERIC(12,2) NOT NULL,
    status      VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
SQL

echo "Table 'transactions' ready."

# Check current count
CURRENT=$($PSQL -tAc "SELECT COUNT(*) FROM transactions")
echo "Current rows: $CURRENT"

REMAINING=$((COUNT - CURRENT))
if [ "$REMAINING" -le 0 ]; then
  echo "Already have $CURRENT rows. Nothing to do."
  exit 0
fi

echo "Inserting $REMAINING more rows in batches of $BATCH_SIZE..."

BATCHES=$(( (REMAINING + BATCH_SIZE - 1) / BATCH_SIZE ))
START_ID=$CURRENT

for i in $(seq 1 $BATCHES); do
  ROWS_THIS_BATCH=$BATCH_SIZE
  if [ $i -eq $BATCHES ]; then
    ROWS_THIS_BATCH=$((REMAINING - (BATCHES - 1) * BATCH_SIZE))
  fi

  $PSQL -q -c "
    INSERT INTO transactions (user_id, amount, status, created_at)
    SELECT
      (random() * 9 + 1)::int,
      (random() * 1000)::numeric(12,2),
      CASE WHEN random() > 0.5 THEN 'completed' ELSE 'pending' END,
      NOW() - (random() * 365)::int * interval '1 day'
    FROM generate_series(1, $ROWS_THIS_BATCH);
  "

  TOTAL_DONE=$((START_ID + i * BATCH_SIZE))
  if [ $TOTAL_DONE -gt $COUNT ]; then
    TOTAL_DONE=$COUNT
  fi
  echo "  Batch $i/$BATCHES done — $TOTAL_DONE/$COUNT rows"
done

echo ""
echo "Done! Final count:"
$PSQL -c "SELECT COUNT(*) AS total_rows FROM transactions;"
$PSQL -c "SELECT pg_size_pretty(pg_total_relation_size('transactions')) AS table_size;"
