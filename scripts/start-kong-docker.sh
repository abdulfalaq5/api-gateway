#!/bin/bash

# Script untuk menjalankan Kong API Gateway menggunakan Docker
# Port Kong Proxy: 9545

set -e

echo "🐳 Menjalankan Kong API Gateway dengan Docker..."

# Cek apakah Docker sudah berjalan
if ! docker info &> /dev/null; then
    echo "❌ Docker tidak berjalan. Silakan jalankan Docker Desktop terlebih dahulu."
    echo "   Atau jalankan: open -a Docker"
    exit 1
fi

echo "✅ Docker sudah berjalan"

# Jalankan Kong dengan Docker Compose
echo "🚀 Menjalankan Kong dengan Docker Compose..."
docker-compose up -d

echo "⏳ Menunggu Kong siap..."
sleep 10

# Cek status Kong
echo "🔍 Mengecek status Kong..."
if docker-compose ps | grep -q "kong-gateway.*Up"; then
    echo "✅ Kong berhasil dijalankan!"
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
else
    echo "❌ Kong gagal dijalankan. Cek log untuk detail:"
    echo "   docker-compose logs kong"
    exit 1
fi
