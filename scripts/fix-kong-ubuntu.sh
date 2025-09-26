#!/bin/bash

# Script untuk memperbaiki masalah Kong di server Ubuntu
# File: scripts/fix-kong-ubuntu.sh

set -e

echo "🔧 Fixing Kong Issues on Ubuntu Server..."

# 1. Cek PostgreSQL container
echo "📊 Checking PostgreSQL container..."
if ! docker ps | grep -q "shared-postgres"; then
    echo "❌ PostgreSQL container tidak berjalan!"
    echo "   Jalankan: docker start shared-postgres"
    exit 1
fi

echo "✅ PostgreSQL container berjalan"

# 2. Test koneksi ke PostgreSQL
echo "🔍 Testing PostgreSQL connection..."
if docker exec shared-postgres psql -U postgres -c "SELECT version();" > /dev/null 2>&1; then
    echo "✅ PostgreSQL connection OK"
else
    echo "❌ PostgreSQL connection failed!"
    exit 1
fi

# 3. Buat database kong
echo "📝 Creating Kong database..."
docker exec shared-postgres psql -U postgres -c "
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'kong') THEN
        CREATE DATABASE kong;
    END IF;
END
\$\$;

DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'kong') THEN
        CREATE USER kong WITH PASSWORD 'kong_password';
    END IF;
END
\$\$;

GRANT ALL PRIVILEGES ON DATABASE kong TO kong;
" || echo "Database setup completed"

# 4. Update docker-compose.yml untuk menggunakan container PostgreSQL
echo "🔄 Updating docker-compose.yml..."

# Backup file asli
cp docker-compose.yml docker-compose.yml.backup

# Buat konfigurasi baru
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  kong-migrations:
    image: kong:3.4
    container_name: kong-migrations
    environment:
      KONG_DATABASE: postgres
      KONG_PG_HOST: shared-postgres
      KONG_PG_USER: kong
      KONG_PG_PASSWORD: kong_password
      KONG_PG_DATABASE: kong
    command: kong migrations bootstrap
    restart: "no"
    networks:
      - default
      - shared-postgres_default

  kong:
    image: kong:3.4
    container_name: kong-gateway
    environment:
      KONG_DATABASE: postgres
      KONG_PG_HOST: shared-postgres
      KONG_PG_USER: kong
      KONG_PG_PASSWORD: kong_password
      KONG_PG_DATABASE: kong
      KONG_PROXY_LISTEN: 0.0.0.0:9545
      KONG_ADMIN_LISTEN: 0.0.0.0:9546
      KONG_ADMIN_GUI_LISTEN: 0.0.0.0:9547
      KONG_PROXY_ACCESS_LOG: /dev/stdout
      KONG_ADMIN_ACCESS_LOG: /dev/stdout
      KONG_PROXY_ERROR_LOG: /dev/stderr
      KONG_ADMIN_ERROR_LOG: /dev/stderr
      KONG_ADMIN_GUI_ERROR_LOG: /dev/stderr
    depends_on:
      kong-migrations:
        condition: service_completed_successfully
    ports:
      - "9545:9545"
      - "9546:9546"
      - "9547:9547"
    healthcheck:
      test: ["CMD", "kong", "health"]
      interval: 10s
      timeout: 10s
      retries: 10
    restart: unless-stopped
    networks:
      - default
      - shared-postgres_default

networks:
  shared-postgres_default:
    external: true
EOF

echo "✅ docker-compose.yml updated"

# 5. Clean up dan restart
echo "🧹 Cleaning up and restarting..."
docker-compose down 2>/dev/null || true
docker-compose up -d

# 6. Cek status
echo "⏳ Waiting for Kong to start..."
sleep 10

if docker-compose ps | grep -q "kong-gateway.*Up"; then
    echo "✅ Kong berhasil dijalankan!"
    echo ""
    echo "📋 Endpoints yang tersedia:"
    echo "   - Kong Proxy: http://localhost:9545"
    echo "   - Kong Admin API: http://localhost:9546"
    echo "   - Kong Admin GUI: http://localhost:9547"
    echo ""
    echo "🧪 Test Kong:"
    echo "   curl http://localhost:9545/"
    echo "   curl http://localhost:9546/"
else
    echo "❌ Kong masih gagal. Cek log:"
    echo "   docker-compose logs kong"
fi
