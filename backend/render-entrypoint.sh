#!/bin/sh
set -ex

echo "🚀 Starting Nakama..."

# Validate DATABASE_URL is set
if [ -z "$DATABASE_URL" ]; then
  echo "❌ ERROR: DATABASE_URL is not set!"
  exit 1
fi

# Strip postgres:// or postgresql:// prefix and query params
DB_ADDR=$(echo "$DATABASE_URL" \
  | sed -E 's|^postgres(ql)?://||' \
  | sed 's|\?.*||')

export NAKAMA_DATABASE_ADDRESS="$DB_ADDR"
echo "📦 DB address: $DB_ADDR"

# Wait for DB to accept connections (critical on Render free tier)
echo "⏳ Waiting for database to be ready..."
MAX_RETRIES=20
RETRY=0
until /nakama/nakama migrate up --database.address "$DB_ADDR"; do
  RETRY=$((RETRY + 1))
  if [ "$RETRY" -ge "$MAX_RETRIES" ]; then
    echo "❌ Database never became ready after $MAX_RETRIES attempts. Exiting."
    exit 1
  fi
  echo "⚠️  DB not ready (attempt $RETRY/$MAX_RETRIES), retrying in 5s..."
  sleep 5
done

echo "✅ Migrations complete"

echo "🎮 Starting Nakama server on port ${PORT:-7350}..."

exec /nakama/nakama \
  --database.address "$DB_ADDR" \
  --logger.level INFO \
  --socket.port "${PORT:-7350}" \
  --socket.address "0.0.0.0"