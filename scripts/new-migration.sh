#!/usr/bin/env bash
set -euo pipefail

MIGRATIONS_DIR="$(cd "$(dirname "$0")/.." && pwd)/migrations"

if [ $# -lt 2 ]; then
  echo "Usage: $0 <version> <description>"
  echo "Example: $0 007 add_payment_methods_table"
  exit 1
fi

VERSION="$1"
DESC="$2"

if ! echo "$VERSION" | grep -qE '^[0-9]+$'; then
  echo "Error: version must be numeric (e.g. 007)"
  exit 1
fi

VERSION_PADDED="$(printf '%03d' "$VERSION")"
FILENAME="V${VERSION_PADDED}__${DESC}.sql"
FILEPATH="$MIGRATIONS_DIR/$FILENAME"

if [ -f "$FILEPATH" ]; then
  echo "Error: $FILENAME already exists"
  exit 1
fi

cat > "$FILEPATH" <<EOF
-- Migration: V${VERSION_PADDED} - ${DESC}
-- Created: $(date +%Y-%m-%d)
-- Author: $(whoami)
--
-- Description:
--   TODO: describe what this migration does
--
-- Risk level: LOW | MEDIUM | HIGH
-- Affected tables: TODO
-- Estimated affected rows: TODO
-- Backward compatible: YES | NO
-- Rollback strategy: TODO

-- BEGIN MIGRATION

-- TODO: add your SQL here

-- END MIGRATION
EOF

echo "Created: $FILEPATH"
echo "Edit the file to add your migration SQL."
