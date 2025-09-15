#!/bin/bash

# Script untuk melihat status Kong API Gateway

set -e

echo "🔍 Status Kong API Gateway..."

# Cek apakah Kong sedang berjalan
if kong health --conf /Users/falaqmsi/Documents/GitHub/kong-api-gateway/config/kong.conf; then
    echo "✅ Kong sedang berjalan"
    echo ""
    echo "📋 Informasi Kong:"
    kong version
    echo ""
    echo "🌐 Endpoints yang tersedia:"
    echo "   - Kong Admin API: http://localhost:8001"
    echo "   - Kong Admin GUI: http://localhost:8002"
    echo "   - Kong Proxy: http://localhost:8000"
    echo ""
    echo "🔗 Test Admin API:"
    curl -s http://localhost:8001/ | jq . 2>/dev/null || echo "   Admin API tidak dapat diakses"
else
    echo "❌ Kong tidak sedang berjalan"
    echo ""
    echo "🚀 Untuk menjalankan Kong:"
    echo "   ./scripts/start-kong.sh"
fi
