#!/bin/bash

# Script untuk Kong di Server Internal dengan PostgreSQL yang sudah ada
# File: scripts/setup-kong-internal.sh

set -e

echo "🚀 Setting up Kong API Gateway on Internal Server..."

# Konfigurasi database
DB_HOST="162.11.0.232"
DB_PORT="5432"
DB_USER="sharedpg"
DB_PASSWORD="pgpass"
DB_NAME="kong"

echo "📊 Database Configuration:"
echo "   Host: $DB_HOST"
echo "   Port: $DB_PORT"
echo "   User: $DB_USER"
echo "   Database: $DB_NAME"

# 1. Test koneksi ke database
echo "🔍 Testing database connection..."
if command -v psql >/dev/null 2>&1; then
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT version();" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✅ Database connection successful"
    else
        echo "❌ Database connection failed!"
        echo "   Please check database credentials and network connectivity"
        exit 1
    fi
else
    echo "⚠️  psql not available, skipping connection test"
fi

# 2. Cek apakah Kong sudah berjalan
echo "🔍 Checking existing Kong containers..."
if docker-compose ps | grep -q "kong-gateway.*Up"; then
    echo "⚠️  Kong is already running. Stopping first..."
    docker-compose down
fi

# 3. Jalankan Kong
echo "🚀 Starting Kong API Gateway..."
docker-compose up -d

# 4. Tunggu Kong start
echo "⏳ Waiting for Kong to start..."
sleep 15

# 5. Cek status
echo "🔍 Checking Kong status..."
if docker-compose ps | grep -q "kong-gateway.*Up"; then
    echo "✅ Kong API Gateway berhasil dijalankan!"
    echo ""
    echo "📋 Endpoints yang tersedia:"
    echo "   - Kong Proxy: http://localhost:9545"
    echo "   - Kong Admin API: http://localhost:9546"
    echo "   - Kong Admin GUI: http://localhost:9547"
    echo ""
    echo "🧪 Test Kong:"
    echo "   curl http://localhost:9545/"
    echo "   curl http://localhost:9546/"
    echo ""
    echo "📝 Deploy konfigurasi:"
    echo "   ./scripts/deploy-kong-config-db.sh"
else
    echo "❌ Kong gagal dijalankan. Cek log:"
    echo "   docker-compose logs kong"
    echo ""
    echo "🔧 Troubleshooting:"
    echo "   1. Cek koneksi database: telnet $DB_HOST $DB_PORT"
    echo "   2. Cek credentials database"
    echo "   3. Cek firewall rules"
fi
