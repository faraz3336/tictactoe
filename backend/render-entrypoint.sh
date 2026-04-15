#!/bin/sh
set -e

# --- Database Connection String Processing ---

# Use NAKAMA_DATABASE_ADDRESS if set, otherwise fallback to DATABASE_URL
DB_ADDR=${NAKAMA_DATABASE_ADDRESS:-$DATABASE_URL}

# Remove the "DATABASE_ADDRESS=" prefix if it exists
DB_ADDR=$(echo "$DB_ADDR" | sed 's/^DATABASE_ADDRESS=//')

# Ensure it starts with postgres:// or postgresql://
case "$DB_ADDR" in
    postgres://*|postgresql://*) ;;
    *) DB_ADDR="postgres://$DB_ADDR" ;;
esac

# Add sslmode=require if not already present
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

echo "Using Database Address: $NAKAMA_DATABASE_ADDRESS"

# --- Run Migrations ---
echo "Running Nakama database migrations..."
/nakama/nakama migrate up --database.address "$NAKAMA_DATABASE_ADDRESS"

# --- Start Nakama ---
echo "Starting Nakama server..."
exec /nakama/nakama \
  --name nakama \
  --database.address "$NAKAMA_DATABASE_ADDRESS" \
  --logger.level INFO \
  --session.token_expiry_sec 7200 \
  --socket.server_key "${NAKAMA_SERVER_KEY}" \
  --console.username "${NAKAMA_CONSOLE_USER}" \
  --console.password "${NAKAMA_CONSOLE_PASS}" \
  --session.encryption_key "${NAKAMA_SESSION_KEY}" \
  --session.refresh_encryption_key "${NAKAMA_REFRESH_KEY}" \
  --runtime.http_key "${NAKAMA_HTTP_KEY}" \
  --socket.port 7350