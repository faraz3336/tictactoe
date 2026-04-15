#!/bin/sh
set -e

# ---- DEBUG START ----
echo "==== ENTRYPOINT STARTED ===="

echo "DATABASE_URL=$DATABASE_URL"

# Fail fast if DB is missing
if [ -z "$DATABASE_URL" ]; then
  echo "ERROR: DATABASE_URL is EMPTY"
  exit 1
fi

# Use Render DB directly
DB_ADDR="$DATABASE_URL"

# Ensure sslmode (safe append)
case "$DB_ADDR" in
  *sslmode=*) ;;
  *)
    if echo "$DB_ADDR" | grep -q "?"; then
      DB_ADDR="${DB_ADDR}&sslmode=require"
    else
      DB_ADDR="${DB_ADDR}?sslmode=require"
    fi
    ;;
esac

export NAKAMA_DATABASE_ADDRESS="$DB_ADDR"

echo "FINAL DB: $NAKAMA_DATABASE_ADDRESS"

# ---- MIGRATIONS ----
echo "Running migrations..."
/nakama/nakama migrate up --database.address "$NAKAMA_DATABASE_ADDRESS"

# ---- START SERVER ----
echo "Starting Nakama..."
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