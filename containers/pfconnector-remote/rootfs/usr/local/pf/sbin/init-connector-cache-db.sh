#!/bin/bash

set -e

DB_DIR="/var/lib/packetfence-connector-cache"
DB_FILE="$DB_DIR/pfcache.db"
SCHEMA="/usr/share/packetfence-connector-cache/db_schema.sql"

mkdir -p "$DB_DIR"

if [ ! -f "$SCHEMA" ]; then
    echo "ERROR: schema file $SCHEMA not found" >&2
    exit 1
fi

needs_init=0
if [ ! -s "$DB_FILE" ]; then
    needs_init=1
elif ! sqlite3 "$DB_FILE" "SELECT name FROM sqlite_master WHERE type='table' AND name='credential';" | grep -q credential; then
    needs_init=1
fi

if [ "$needs_init" -eq 1 ]; then
    echo "Initializing connector-cache sqlite DB at $DB_FILE from $SCHEMA"
    sqlite3 "$DB_FILE" < "$SCHEMA"
else
    echo "connector-cache sqlite DB already initialized at $DB_FILE"
fi
