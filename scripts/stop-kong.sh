#!/bin/bash

# Script untuk menghentikan Kong API Gateway

set -e

echo "🛑 Menghentikan Kong API Gateway..."

# Cek apakah Kong sedang berjalan
if ! kong health --conf /Users/falaqmsi/Documents/GitHub/kong-api-gateway/config/kong.conf &> /dev/null; then
    echo "❌ Kong tidak sedang berjalan"
    exit 1
fi

# Hentikan Kong
echo "🦍 Menghentikan Kong..."
kong stop --conf /Users/falaqmsi/Documents/GitHub/kong-api-gateway/config/kong.conf

echo "✅ Kong berhasil dihentikan!"
echo ""
echo "🚀 Untuk menjalankan kembali Kong:"
echo "   ./scripts/start-kong.sh"
