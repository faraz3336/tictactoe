#!/bin/sh
set -eux

echo "=== ENTRYPOINT STARTED ==="
echo "DATABASE_URL=$DATABASE_URL"

if [ -z "$DATABASE_URL" ]; then
  echo "ERROR: DATABASE_URL is EMPTY"
  exit 1
fi

export NAKAMA_DATABASE_ADDRESS="$DATABASE_URL"

echo "DB SET OK: $NAKAMA_DATABASE_ADDRESS"

echo "RUNNING MIGRATIONS"
/nakama/nakama migrate up --database.address "$NAKAMA_DATABASE_ADDRESS"

echo "STARTING NAKAMA"
exec /nakama/nakama \
  --database.address "$NAKAMA_DATABASE_ADDRESS" \
  --logger.level DEBUG \
  --socket.port 7350