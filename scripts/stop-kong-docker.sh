#!/bin/bash

# Script untuk menghentikan Kong API Gateway yang berjalan dengan Docker

set -e

echo "🛑 Menghentikan Kong API Gateway..."

# Cek apakah Docker Compose file ada
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ File docker-compose.yml tidak ditemukan"
    exit 1
fi

# Hentikan semua container Kong
echo "🛑 Menghentikan container Kong..."
docker-compose down

echo "✅ Kong berhasil dihentikan!"
echo ""
echo "📋 Untuk menghapus data database (HATI-HATI!):"
echo "   docker-compose down -v"
echo ""
echo "📋 Untuk melihat log Kong:"
echo "   docker-compose logs kong"
