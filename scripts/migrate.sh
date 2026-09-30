#!/usr/bin/env bash
set -euo pipefail

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-tutorial}"
DB_NAME="${DB_NAME:-app_db}"
export PGPASSWORD="${DB_PASSWORD:-tutorial_secret}"

MIGRATIONS_DIR="$(cd "$(dirname "$0")/.." && pwd)/migrations"

PSQL="psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -v ON_ERROR_STOP=1"

ensure_tracking_table() {
  $PSQL -q <<'SQL'
CREATE TABLE IF NOT EXISTS _schema_migrations (
  version     TEXT PRIMARY KEY,
  filename    TEXT NOT NULL,
  applied_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  checksum    TEXT
);
SQL
}

compute_checksum() {
  shasum -a 256 "$1" | awk '{print $1}'
}

migrate() {
  ensure_tracking_table
  local applied=0

  for f in "$MIGRATIONS_DIR"/V*.sql; do
    [ -f "$f" ] || continue
    local filename
    filename="$(basename "$f")"
    local version
    version="$(echo "$filename" | sed -E 's/^V([0-9]+)__.*/\1/')"
    local checksum
    checksum="$(compute_checksum "$f")"

    local already
    already=$($PSQL -tAc "SELECT 1 FROM _schema_migrations WHERE version = '$version'")
    if [ "$already" = "1" ]; then
      echo "  SKIP  $filename (already applied)"
      continue
    fi

    echo "  APPLY $filename ..."
    $PSQL -q -f "$f"
    $PSQL -q -c "INSERT INTO _schema_migrations(version, filename, checksum) VALUES('$version', '$filename', '$checksum')"
    applied=$((applied + 1))
  done

  echo "Applied $applied migration(s)."
}

status() {
  ensure_tracking_table
  echo "Applied migrations:"
  $PSQL -c "SELECT version, filename, applied_at FROM _schema_migrations ORDER BY version"
  echo ""
  echo "Pending migrations:"
  local found=0
  for f in "$MIGRATIONS_DIR"/V*.sql; do
    [ -f "$f" ] || continue
    local filename
    filename="$(basename "$f")"
    local version
    version="$(echo "$filename" | sed -E 's/^V([0-9]+)__.*/\1/')"
    local already
    already=$($PSQL -tAc "SELECT 1 FROM _schema_migrations WHERE version = '$version'")
    if [ "$already" != "1" ]; then
      echo "  PENDING  $filename"
      found=1
    fi
  done
  [ "$found" = "0" ] && echo "  (none)"
}

rollback() {
  local target="${1:-}"
  if [ -z "$target" ]; then
    echo "Usage: $0 rollback <version>"
    echo "Example: $0 rollback 004"
    exit 1
  fi

  ensure_tracking_table
  local current
  current=$($PSQL -tAc "SELECT MAX(version) FROM _schema_migrations")
  if [ -z "$current" ]; then
    echo "No migrations applied."
    exit 1
  fi

  echo "Current version: $current"
  echo "Rolling back to version: $target"
  echo "WARNING: This requires manual rollback SQL files."
  echo "For now, removing tracking entries only."

  $PSQL -c "DELETE FROM _schema_migrations WHERE version > '$target'"
  echo "Rollback tracking updated. Manually reverse schema changes if needed."
}

case "${1:-migrate}" in
  migrate)  migrate ;;
  status)   status ;;
  rollback) rollback "${2:-}" ;;
  *)
    echo "Usage: $0 {migrate|status|rollback <version>}"
    exit 1
    ;;
esac
