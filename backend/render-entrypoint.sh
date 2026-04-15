#!/bin/sh
set -ex

echo "Starting Nakama..."

if [ -z "$DATABASE_URL" ]; then
  echo "ERROR: DATABASE_URL is not set!"
  exit 1
fi

# Strip scheme, keep user:pass@host:port/db, re-append sslmode
# Input:  postgres://user:pass@host:5432/db?sslmode=require
# Output: user:pass@host:5432/db?sslmode=require
DB_ADDR=$(echo "$DATABASE_URL" | sed -E 's|^postgres(ql)?://||')

echo "DB_ADDR: $DB_ADDR"

echo "Running migrations..."
MAX_RETRIES=30
RETRY=0
until /nakama/nakama migrate up --database.address "$DB_ADDR"; do
  RETRY=$((RETRY + 1))
  if [ "$RETRY" -ge "$MAX_RETRIES" ]; then
    echo "ERROR: DB never became ready after $MAX_RETRIES attempts."
    exit 1
  fi
  echo "Attempt $RETRY/$MAX_RETRIES failed, retrying in 5s..."
  sleep 5
done

echo "Migrations complete. Starting server on port ${PORT:-7350}..."

exec /nakama/nakama \
  --database.address "$DB_ADDR" \
  --logger.level INFO \
  --socket.port "${PORT:-7350}" \
  --socket.address "0.0.0.0" \
  --session.encryption_key "${NAKAMA_SESSION_KEY}" \
  --session.refresh_encryption_key "${NAKAMA_REFRESH_KEY}" \
  --runtime.http_key "${NAKAMA_HTTP_KEY}" \
  --console.username "${NAKAMA_CONSOLE_USER:-admin}" \
  --console.password "${NAKAMA_CONSOLE_PASS}"
