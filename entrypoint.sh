#!/bin/sh
set -e

echo "🚀 Starting Nakama..."

# Validate required env vars
: "${DATABASE_URL:?❌ ERROR: DATABASE_URL not set}"
: "${NAKAMA_SESSION_KEY:?❌ ERROR: NAKAMA_SESSION_KEY not set}"
: "${NAKAMA_REFRESH_KEY:?❌ ERROR: NAKAMA_REFRESH_KEY not set}"
: "${NAKAMA_HTTP_KEY:?❌ ERROR: NAKAMA_HTTP_KEY not set}"

echo "🗄️  Connecting to database..."

# Wait for DB with simple retry (check exit code directly)
MAX=30
N=0
while [ $N -lt $MAX ]; do
  echo "⏳ Attempt $((N+1))/$MAX: Running migrations..."
  
  if /nakama/nakama migrate up --database.address "$DATABASE_URL" 2>&1; then
    echo "✅ Migrations successful!"
    break
  fi
  
  N=$((N+1))
  [ $N -ge $MAX ] && { echo "❌ Failed after $MAX attempts"; exit 1; }
  
  echo "⚠️  Migration failed, retrying in 5s..."
  sleep 5
done

echo "🔌 Starting Nakama server on port ${PORT:-7350}..."

# Start Nakama server
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