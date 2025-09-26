#!/bin/bash

# Script sederhana untuk fix Kong di Ubuntu
# File: scripts/quick-fix-kong.sh

set -e

echo "🔧 Quick Fix for Kong on Ubuntu Server..."

# 1. Cek PostgreSQL
echo "📊 Checking PostgreSQL..."
docker exec shared-postgres psql -U postgres -c "SELECT version();" || {
    echo "❌ PostgreSQL tidak accessible"
    exit 1
}

# 2. Buat database kong
echo "📝 Creating Kong database..."
docker exec shared-postgres psql -U postgres -c "
CREATE DATABASE kong;
CREATE USER kong WITH PASSWORD 'kong_password';
GRANT ALL PRIVILEGES ON DATABASE kong TO kong;
" 2>/dev/null || echo "Database mungkin sudah ada"

# 3. Update docker-compose.yml
echo "🔄 Updating docker-compose.yml..."

# Backup
cp docker-compose.yml docker-compose.yml.backup

# Update untuk menggunakan shared-postgres
sed -i 's/host.docker.internal/shared-postgres/g' docker-compose.yml
sed -i 's/falaqmsi/kong/g' docker-compose.yml
sed -i 's/Rubysa179596/kong_password/g' docker-compose.yml

# 4. Restart Kong
echo "🚀 Restarting Kong..."
docker-compose down
docker-compose up -d

# 5. Cek status
echo "⏳ Waiting for Kong..."
sleep 15

if docker-compose ps | grep -q "kong-gateway.*Up"; then
    echo "✅ Kong berhasil dijalankan!"
    echo ""
    echo "📋 Test endpoints:"
    echo "   curl http://localhost:9545/"
    echo "   curl http://localhost:9546/"
else
    echo "❌ Kong masih gagal. Cek log:"
    echo "   docker-compose logs kong"
fi
