    #!/bin/sh

    set -ex

    echo "🚀 STARTING NAKAMA"

    if [ -z "$DATABASE_URL" ]; then
    echo "❌ DATABASE_URL is missing"
    exit 1
    fi

    echo "📦 DATABASE_URL received"

    DB_ADDR=$(echo "$DATABASE_URL" | sed -E 's|^postgres(ql)?://||')

    echo "🛠 Parsed DB_ADDR: $DB_ADDR"

    export NAKAMA_DATABASE_ADDRESS="$DB_ADDR"

    echo "🚧 Running migrations..."
    /nakama/nakama migrate up --database.address "$NAKAMA_DATABASE_ADDRESS"

    echo "🚀 Starting server..."

    exec /nakama/nakama \
    --name nakama \
    --database.address "$NAKAMA_DATABASE_ADDRESS" \
    --logger.level DEBUG \
    --session.token_expiry_sec 7200 \
    --socket.server_key "$NAKAMA_SERVER_KEY" \
    --console.username "$NAKAMA_CONSOLE_USER" \
    --console.password "$NAKAMA_CONSOLE_PASS" \
    --session.encryption_key "$NAKAMA_SESSION_KEY" \
    --session.refresh_encryption_key "$NAKAMA_REFRESH_KEY" \
    --runtime.http_key "$NAKAMA_HTTP_KEY" \
    --socket.port "${PORT:-7350}"