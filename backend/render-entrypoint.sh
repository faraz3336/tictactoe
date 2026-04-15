#!/bin/sh
set -e

echo "🚀 Starting Nakama on Render..."

# Step 1: validate env
if [ -z "$DATABASE_URL" ]; then
  echo "❌ DATABASE_URL missing"
  exit 1
fi

# Step 2: fix DB URL
DB_ADDR=$(echo "$DATABASE_URL" | sed -E 's|^postgres(ql)?://||')
export NAKAMA_DATABASE_ADDRESS="$DB_ADDR"

echo "✅ DB parsed successfully"

# Step 3: run migrations
echo "🚧 Running migrations..."
/nakama/nakama migrate up --database.address "$DB_ADDR"

echo "✅ Migrations complete"

# Step 4: start server (THIS keeps container alive)
echo "🚀 Starting Nakama server..."

exec /nakama/nakama \
  --database.address "$DB_ADDR" \
  --logger.level INFO \
  --socket.server_key "$NAKAMA_SERVER_KEY" \
  --console.username "$NAKAMA_CONSOLE_USER" \
  --console.password "$NAKAMA_CONSOLE_PASS" \
  --session.encryption_key "$NAKAMA_SESSION_KEY" \
  --session.refresh_encryption_key "$NAKAMA_REFRESH_KEY" \
  --runtime.http_key "$NAKAMA_HTTP_KEY" \
  --socket.port "${PORT:-7350}"