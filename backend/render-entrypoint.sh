#!/bin/sh
set -e

echo "DATABASE_URL is: $DATABASE_URL"

DB_ADDR="$DATABASE_URL"
export NAKAMA_DATABASE_ADDRESS="$DB_ADDR"

echo "Using Database Address: $NAKAMA_DATABASE_ADDRESS"

echo "Running Nakama database migrations..."
/nakama/nakama migrate up --database.address "$NAKAMA_DATABASE_ADDRESS" || echo "Migration failed"

echo "Starting Nakama server..."
exec /nakama/nakama \
  --name nakama \
  --database.address "$NAKAMA_DATABASE_ADDRESS" \
  --logger.level DEBUG \
  --session.token_expiry_sec 7200 \
  --socket.server_key "${NAKAMA_SERVER_KEY}" \
  --console.username "${NAKAMA_CONSOLE_USER}" \
  --console.password "${NAKAMA_CONSOLE_PASS}" \
  --session.encryption_key "${NAKAMA_SESSION_KEY}" \
  --session.refresh_encryption_key "${NAKAMA_REFRESH_KEY}" \
  --runtime.http_key "${NAKAMA_HTTP_KEY}" \
  --socket.port 7350