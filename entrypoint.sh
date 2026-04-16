#!/bin/sh
set -ex

echo "🚀 Starting Nakama..."

# Validate required env vars
if [ -z "$DATABASE_URL" ]; then
  echo "❌ ERROR: DATABASE_URL not set"
  exit 1
fi

if [ -z "$NAKAMA_SESSION_KEY" ] || [ -z "$NAKAMA_REFRESH_KEY" ] || [ -z "$NAKAMA_HTTP_KEY" ]; then
  echo "❌ ERROR: Required encryption keys not set"
  exit 1
fi

echo "🗄️  Connecting to database..."

# Wait for DB to be ready using FULL DATABASE_URL (no parsing!)
MAX=30
N=0
until /nakama/nakama migrate up --database.address "$DATABASE_URL" 2>&1 | grep -q "Migration complete\|error"; do
  N=$((N+1))
  [ $N -ge $MAX ] && echo "❌ Database never became ready" && exit 1
  echo "⏳ Retry $N/$MAX... waiting for DB"
  sleep 5
done

echo "✅ Migrations complete. Starting Nakama server..."

# Start Nakama with full DATABASE_URL
exec /nakama/nakama \
  --database.address "$DATABASE_URL" \
  --logger.level INFO \
  --socket.port "${PORT:-7350}" \
  --socket.address "0.0.0.0" \
  --session.encryption_key "$NAKAMA_SESSION_KEY" \
  --session.refresh_encryption_key "$NAKAMA_REFRESH_KEY" \
  --runtime.http_key "$NAKAMA_HTTP_KEY" \
  --console.username "${NAKAMA_CONSOLE_USER:-admin}" \
  --console.password "$NAKAMA_CONSOLE_PASS"