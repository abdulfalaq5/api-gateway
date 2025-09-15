#!/bin/bash

# Script untuk testing Kong API Gateway dengan Docker
# Port Kong Proxy: 9545

set -e

echo "🧪 Testing Kong API Gateway dengan Docker..."

# Cek apakah Kong sedang berjalan
if ! docker-compose ps | grep -q "kong-gateway.*Up"; then
    echo "❌ Kong tidak sedang berjalan. Silakan jalankan Kong terlebih dahulu:"
    echo "   ./scripts/start-kong-docker.sh"
    exit 1
fi

echo "✅ Kong sedang berjalan"

# Test Admin API
echo ""
echo "🔍 Testing Admin API..."
curl -s http://localhost:9546/ | jq . 2>/dev/null || echo "   Admin API tidak dapat diakses"

# Test Kong Proxy
echo ""
echo "🌐 Testing Kong Proxy (Port 9545)..."
curl -s http://localhost:9545/ | head -n 5 || echo "   Kong Proxy tidak dapat diakses"

# Test Services (jika ada)
echo ""
echo "📋 Testing Services..."

# Test example service
echo "   Testing example service..."
curl -s http://localhost:9545/api/v1/example 2>/dev/null || echo "   Example service tidak dapat diakses"

# Test dengan API key (jika ada)
echo ""
echo "🔐 Testing dengan API Key..."
curl -s http://localhost:9545/api/v1/example \
  -H "apikey: your-api-key-here" 2>/dev/null || echo "   API Key test gagal"

echo ""
echo "✅ Testing selesai!"
echo ""
echo "📊 Untuk melihat semua services:"
echo "   curl http://localhost:9546/services/"
echo ""
echo "📊 Untuk melihat semua routes:"
echo "   curl http://localhost:9546/routes/"
echo ""
echo "📊 Untuk melihat semua consumers:"
echo "   curl http://localhost:9546/consumers/"
echo ""
echo "📊 Untuk melihat log Kong:"
echo "   docker-compose logs kong"
