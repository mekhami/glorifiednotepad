#!/bin/bash
# Migration script: SQLite -> PostgreSQL using CLI tools
# Run on production server after PostgreSQL is set up
# Usage: bash priv/scripts/migrate_sqlite_to_pg.sh

set -e

# Configuration from environment variables
SQLITE_PATH="${SQLITE_PATH:-/var/lib/indie/indie_prod.db}"
PG_HOST="${DATABASE_HOST:-localhost}"
PG_PORT="${DATABASE_PORT:-5432}"
PG_NAME="${DATABASE_NAME:-indie_prod}"
PG_USER="${DATABASE_USER:-indie}"
PG_PASSWORD="${DATABASE_PASSWORD:-}"

export PGPASSWORD="$PG_PASSWORD"

echo "🚀 Starting SQLite to PostgreSQL migration"
echo "SQLite source: $SQLITE_PATH"
echo "PostgreSQL target: $PG_USER@$PG_HOST:$PG_PORT/$PG_NAME"

# Verify SQLite file exists
if [ ! -f "$SQLITE_PATH" ]; then
  echo "❌ SQLite database not found at $SQLITE_PATH"
  exit 1
fi

# Verify PostgreSQL connection
if ! pg_isready -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_NAME" > /dev/null 2>&1; then
  echo "❌ Cannot connect to PostgreSQL"
  exit 1
fi

# Get list of tables to migrate (excluding system tables and schema_migrations)
# Also excluding characters and relationships due to schema differences (empty in prod anyway)
TABLES=$(sqlite3 "$SQLITE_PATH" ".tables" | tr ' ' '\n' | grep -v '^sqlite_' | grep -v '^schema_migrations$' | grep -v '^characters$' | grep -v '^relationships$' | grep -v '^relationships_new$' | sort)

echo ""
echo "📋 Tables to migrate:"
echo "$TABLES" | sed 's/^/  /'

# First, migrate schema_migrations (critical for Ecto)
echo ""
echo "📦 Migrating schema_migrations..."
sqlite3 "$SQLITE_PATH" "SELECT version, inserted_at FROM schema_migrations ORDER BY version;" | while IFS='|' read -r version inserted_at; do
  if [ -n "$version" ]; then
    psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_NAME" -c \
      "INSERT INTO schema_migrations (version, inserted_at) VALUES ($version, '$inserted_at') ON CONFLICT (version) DO NOTHING;" > /dev/null
    echo "  ✓ Migration version $version"
  fi
done

# Migrate each table
for table in $TABLES; do
  echo ""
  echo "📦 Migrating $table..."

  # Get column names
  COLUMNS=$(sqlite3 "$SQLITE_PATH" "PRAGMA table_info($table);" | cut -d'|' -f2 | paste -sd ',' -)

  # Count rows
  ROW_COUNT=$(sqlite3 "$SQLITE_PATH" "SELECT COUNT(*) FROM $table;")
  echo "  Rows to migrate: $ROW_COUNT"

  if [ "$ROW_COUNT" -eq 0 ]; then
    echo "  (empty table)"
    continue
  fi

  # Export data from SQLite as CSV and import to PostgreSQL using COPY
  sqlite3 "$SQLITE_PATH" -csv -header "SELECT * FROM $table;" > "/tmp/${table}.csv"
  
  # Use PostgreSQL COPY for fast import
  psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_NAME" -c \
    "\COPY $table ($COLUMNS) FROM '/tmp/${table}.csv' WITH (FORMAT csv, HEADER true);" > /dev/null
  
  echo "  ✓ Migrated $ROW_COUNT rows"
  
  # Cleanup
  rm -f "/tmp/${table}.csv"
done

# Reset PostgreSQL sequences for tables with auto-increment IDs
echo ""
echo "🔧 Resetting PostgreSQL sequences..."
for table in comments animations doodle_pixels; do
  # Check if table exists and has id column
  COL_EXISTS=$(psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_NAME" -t -c \
    "SELECT 1 FROM information_schema.columns WHERE table_name = '$table' AND column_name = 'id';" | xargs)
  
  if [ "$COL_EXISTS" = "1" ]; then
    MAX_ID=$(psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_NAME" -t -c "SELECT COALESCE(MAX(id), 0) FROM $table;" | xargs)
    NEXT_ID=$((MAX_ID + 1))
    
    psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_NAME" -c "SELECT setval('${table}_id_seq', $NEXT_ID, false);" > /dev/null
    echo "  ✓ ${table}_id_seq set to $NEXT_ID"
  fi
done

# Verify migration
echo ""
echo "✅ Verification:"
for table in schema_migrations comments animations doodle_pixels; do
  COUNT=$(psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_NAME" -t -c "SELECT COUNT(*) FROM $table;" | xargs)
  echo "  $table: $COUNT rows"
done

echo ""
echo "🎉 Migration complete!"