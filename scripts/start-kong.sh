#!/bin/bash

# Script untuk menjalankan Kong API Gateway

set -e

echo "🚀 Menjalankan Kong API Gateway..."

# Cek apakah Kong sudah terinstall
if ! command -v kong &> /dev/null; then
    echo "❌ Kong tidak ditemukan. Silakan jalankan script instalasi terlebih dahulu:"
    echo "   ./scripts/install-kong.sh"
    exit 1
fi

# Cek apakah PostgreSQL sedang berjalan
if ! pg_isready -h localhost -p 5432 -U falaqmsi &> /dev/null; then
    echo "❌ PostgreSQL tidak berjalan. Menjalankan PostgreSQL..."
    brew services start postgresql@15
    sleep 3
fi

# Jalankan Kong
echo "🦍 Menjalankan Kong..."
kong start --conf /Users/falaqmsi/Documents/GitHub/kong-api-gateway/config/kong.conf

echo "✅ Kong berhasil dijalankan!"
echo ""
echo "📋 Endpoints yang tersedia:"
echo "   - Kong Admin API: http://localhost:8001"
echo "   - Kong Admin GUI: http://localhost:8002"
echo "   - Kong Proxy: http://localhost:8000"
echo ""
echo "🔍 Untuk melihat status Kong:"
echo "   kong health --conf /Users/falaqmsi/Documents/GitHub/kong-api-gateway/config/kong.conf"
echo ""
echo "🛑 Untuk menghentikan Kong:"
echo "   ./scripts/stop-kong.sh"
