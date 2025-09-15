#!/bin/bash

# Script untuk start Kong di environment lokal
# File: scripts/start-kong-local.sh

set -e

echo "🏠 Starting Kong API Gateway (LOCAL Environment)..."

# Switch ke konfigurasi lokal
./scripts/switch-kong-config.sh local

# Cek apakah Docker berjalan
if ! docker info &> /dev/null; then
    echo "❌ Docker tidak berjalan. Silakan jalankan Docker Desktop terlebih dahulu."
    echo "   Atau jalankan: open -a Docker"
    exit 1
fi

echo "✅ Docker sudah berjalan"

# Stop Kong yang mungkin sedang berjalan
echo "🛑 Stopping existing Kong containers..."
docker-compose down 2>/dev/null || true

# Jalankan Kong dengan konfigurasi lokal
echo "🚀 Starting Kong with LOCAL configuration..."
docker-compose up -d

echo "⏳ Waiting for Kong to start..."
sleep 10

# Cek status Kong
echo "🔍 Checking Kong status..."
if docker-compose ps | grep -q "kong-gateway.*Up"; then
    echo "✅ Kong berhasil dijalankan di LOCAL environment!"
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
    exit 1
fi
