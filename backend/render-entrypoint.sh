#!/bin/sh
set -e

# The DATABASE_URL environment variable is already correctly formatted.
# We just need to export it for Nakama and use it.
export NAKAMA_DATABASE_ADDRESS="$DATABASE_URL"

echo "Using Database Address: $NAKAMA_DATABASE_ADDRESS"

# --- Run Nakama Database Migrations ---
echo "Running Nakama database migrations..."
/nakama/nakama migrate up --database.address "$NAKAMA_DATABASE_ADDRESS"

# --- Start Nakama Server ---
echo "Starting Nakama server..."
exec /nakama/nakama 
  --name nakama 
  --database.address "$NAKAMA_DATABASE_ADDRESS" 
  --logger.level INFO 
  --session.token_expiry_sec 7200 
  --socket.server_key "${NAKAMA_SERVER_KEY}" 
  --console.username "${NAKAMA_CONSOLE_USER}" 
  --console.password "${NAKAMA_CONSOLE_PASS}" 
  --session.encryption_key "${NAKAMA_SESSION_KEY}" 
  --session.refresh_encryption_key "${NAKAMA_REFRESH_KEY}" 
  --runtime.http_key "${NAKAMA_HTTP_KEY}" 
  --socket.port 7350
