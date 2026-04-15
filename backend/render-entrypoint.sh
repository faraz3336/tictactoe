#!/bin/sh
set -ex

echo "🚀 Starting Nakama..."

# Validate DATABASE_URL is set
if [ -z "$DATABASE_URL" ]; then
  echo "❌ ERROR: DATABASE_URL is not set!"
  exit 1
fi

# Strip postgres:// or postgresql:// prefix AND query params
# SSL is handled separately via --database.dsn flag
DB_ADDR=$(echo "$DATABASE_URL" \
  | sed -E 's|^postgres(ql)?://||' \
  | sed 's|\?.*||')

echo "📦 DB address: $DB_ADDR"

# Wait for DB + run migrations (retry loop for Render free tier cold starts)
echo "⏳ Running migrations (will retry until DB is ready)..."
MAX_RETRIES=30
RETRY=0
until /nakama/nakama migrate up \
    --database.address "$DB_ADDR" \
    --database.dsn "sslmode=require"; do
  RETRY=$((RETRY + 1))
  if [ "$RETRY" -ge "$MAX_RETRIES" ]; then
    echo "❌ DB never became ready after $MAX_RETRIES attempts. Giving up."
    exit 1
  fi
  echo "⚠️  Attempt $RETRY/$MAX_RETRIES failed, retrying in 5s..."
  sleep 5
done

echo "✅ Migrations complete"
echo "🎮 Starting server on port ${PORT:-7350}..."

exec /nakama/nakama \
  --database.address "$DB_ADDR" \
  --database.dsn "sslmode=require" \
  --logger.level INFO \
  --socket.port "${PORT:-7350}" \
  --socket.address "0.0.0.0" \
  --session.encryption_key "${NAKAMA_SESSION_KEY}" \
  --session.refresh_encryption_key "${NAKAMA_REFRESH_KEY}" \
  --runtime.http_key "${NAKAMA_HTTP_KEY}" \
  --console.username "${NAKAMA_CONSOLE_USER:-admin}" \
  --console.password "${NAKAMA_CONSOLE_PASS}"