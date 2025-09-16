#!/bin/bash

# Script untuk deploy Kong configuration ke server baru
# File: deploy-to-new-server.sh

set -e

echo "🚀 Deploying Kong Configuration to New Server"
echo "=============================================="

# Cek apakah Kong berjalan
if ! curl -s --connect-timeout 5 http://localhost:9546/ > /dev/null 2>&1; then
    echo "❌ Kong tidak berjalan. Silakan start Kong terlebih dahulu:"
    echo "   docker-compose up -d"
    exit 1
fi

echo "✅ Kong sedang berjalan"

# Backup konfigurasi saat ini
echo "📦 Creating backup..."
BACKUP_FILE="kong_backup_$(date +%Y%m%d_%H%M%S).json"
curl -s http://localhost:9546/config > "$BACKUP_FILE"
echo "   Backup tersimpan di: $BACKUP_FILE"

# Deploy konfigurasi baru
echo "🔄 Deploying new configuration..."
if [ -f "kong.yml" ]; then
    DEPLOY_RESPONSE=$(curl -s -w "%{http_code}" -X POST http://localhost:9546/config -F "config=@kong.yml")
    HTTP_CODE="${DEPLOY_RESPONSE: -3}"
    
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
        echo "   ✅ Deploy berhasil (HTTP $HTTP_CODE)"
    else
        echo "   ❌ Deploy gagal (HTTP $HTTP_CODE)"
        echo "   Response: ${DEPLOY_RESPONSE%???}"
        exit 1
    fi
else
    echo "   ❌ File kong.yml tidak ditemukan!"
    exit 1
fi

# Verifikasi deploy
echo "🔍 Verifying deployment..."
SERVICES_COUNT=$(curl -s http://localhost:9546/services/ | jq 'length' 2>/dev/null || echo "0")
ROUTES_COUNT=$(curl -s http://localhost:9546/routes/ | jq 'length' 2>/dev/null || echo "0")
PLUGINS_COUNT=$(curl -s http://localhost:9546/plugins/ | jq 'length' 2>/dev/null || echo "0")

echo "   Services deployed: $SERVICES_COUNT"
echo "   Routes deployed: $ROUTES_COUNT"
echo "   Plugins deployed: $PLUGINS_COUNT"

# Test endpoints
echo "🧪 Testing endpoints..."
if curl -s http://localhost:9545/ > /dev/null 2>&1; then
    echo "   ✅ Kong Proxy accessible"
else
    echo "   ❌ Kong Proxy tidak dapat diakses"
fi

echo ""
echo "✅ Deployment completed!"
echo ""
echo "📋 Next steps:"
echo "   - Test endpoints: curl http://localhost:9545/api/your-endpoint"
echo "   - Monitor logs: docker-compose logs -f kong"
echo "   - Cek services: curl http://localhost:9546/services/"
echo ""
echo "🔄 Jika ada masalah, rollback dengan:"
echo "   curl -X POST http://localhost:9546/config -F \"config=@$BACKUP_FILE\""
