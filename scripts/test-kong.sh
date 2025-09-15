#!/bin/bash

# Script untuk testing Kong API Gateway
# Script ini akan test semua endpoint yang dikonfigurasi

set -e

echo "🧪 Testing Kong API Gateway..."

# Cek apakah Kong sedang berjalan
if ! kong health --conf /Users/falaqmsi/Documents/GitHub/kong-api-gateway/config/kong.conf &> /dev/null; then
    echo "❌ Kong tidak sedang berjalan. Silakan jalankan Kong terlebih dahulu:"
    echo "   ./scripts/start-kong.sh"
    exit 1
fi

echo "✅ Kong sedang berjalan"

# Test Admin API
echo ""
echo "🔍 Testing Admin API..."
curl -s http://localhost:8001/ | jq . 2>/dev/null || echo "   Admin API tidak dapat diakses"

# Test Kong Proxy
echo ""
echo "🌐 Testing Kong Proxy..."
curl -s http://localhost:8000/ | head -n 5 || echo "   Kong Proxy tidak dapat diakses"

# Test Services (jika ada)
echo ""
echo "📋 Testing Services..."

# Test example service
echo "   Testing example service..."
curl -s http://localhost:8000/api/v1/example 2>/dev/null || echo "   Example service tidak dapat diakses"

# Test dengan API key (jika ada)
echo ""
echo "🔐 Testing dengan API Key..."
curl -s http://localhost:8000/api/v1/example \
  -H "apikey: your-api-key-here" 2>/dev/null || echo "   API Key test gagal"

echo ""
echo "✅ Testing selesai!"
echo ""
echo "📊 Untuk melihat semua services:"
echo "   curl http://localhost:8001/services/"
echo ""
echo "📊 Untuk melihat semua routes:"
echo "   curl http://localhost:8001/routes/"
echo ""
echo "📊 Untuk melihat semua consumers:"
echo "   curl http://localhost:8001/consumers/"
