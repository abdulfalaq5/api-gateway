#!/bin/bash

# Script untuk start Kong di server internal
# File: scripts/start-kong-server.sh

set -e

echo "🖥️  Starting Kong API Gateway (SERVER Environment)..."

# Switch ke konfigurasi server
./scripts/switch-kong-config.sh server

# Cek apakah Docker berjalan
if ! docker info &> /dev/null; then
    echo "❌ Docker tidak berjalan. Silakan jalankan Docker terlebih dahulu."
    echo "   sudo systemctl start docker"
    exit 1
fi

echo "✅ Docker sudah berjalan"

# Test koneksi ke database server
echo "🔍 Testing database connection..."
DB_HOST="162.11.0.232"
DB_PORT="5432"
DB_USER="sharedpg"
DB_PASSWORD="pgpass"
DB_NAME="kong"

if command -v telnet >/dev/null 2>&1; then
    if timeout 5 telnet $DB_HOST $DB_PORT </dev/null 2>/dev/null; then
        echo "✅ Database server accessible"
    else
        echo "❌ Database server tidak accessible!"
        echo "   Host: $DB_HOST:$DB_PORT"
        echo "   Cek koneksi network dan firewall"
        exit 1
    fi
else
    echo "⚠️  telnet not available, skipping connection test"
fi

# Stop Kong yang mungkin sedang berjalan
echo "🛑 Stopping existing Kong containers..."
docker-compose down 2>/dev/null || true

# Jalankan Kong dengan konfigurasi server
echo "🚀 Starting Kong with SERVER configuration..."
docker-compose up -d

echo "⏳ Waiting for Kong to start..."
sleep 15

# Cek status Kong
echo "🔍 Checking Kong status..."
if docker-compose ps | grep -q "kong-gateway.*Up"; then
    echo "✅ Kong berhasil dijalankan di SERVER environment!"
    echo ""
    echo "📋 Endpoints yang tersedia:"
    echo "   - Kong Proxy: http://localhost:9545"
    echo "   - Kong Admin API: http://localhost:9546"
    echo "   - Kong Admin GUI: http://localhost:9547"
    echo ""
    echo "🔍 Untuk melihat log Kong:"
    echo "   docker-compose logs -f kong"
    echo ""
    echo "🛑 Untuk menghentikan Kong:"
    echo "   docker-compose down"
    echo ""
    echo "🧪 Untuk test Kong:"
    echo "   curl http://localhost:9545/"
    echo ""
    echo "📝 Deploy konfigurasi:"
    echo "   ./scripts/deploy-kong-config-db.sh"
else
    echo "❌ Kong gagal dijalankan. Cek log untuk detail:"
    echo "   docker-compose logs kong"
    echo ""
    echo "🔧 Troubleshooting:"
    echo "   1. Cek koneksi database: telnet $DB_HOST $DB_PORT"
    echo "   2. Cek credentials database"
    echo "   3. Cek firewall rules"
    exit 1
fi
