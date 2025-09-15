#!/bin/bash

# Script untuk deploy konfigurasi Kong setelah mengubah file kong.yml
# File: scripts/deploy-kong-config.sh

set -e

echo "🚀 Deploying Kong Configuration..."

# Cek apakah Kong sedang berjalan
if ! docker-compose ps | grep -q "kong-gateway.*Up"; then
    echo "❌ Kong tidak sedang berjalan. Silakan jalankan Kong terlebih dahulu:"
    echo "   ./scripts/start-kong-docker.sh"
    exit 1
fi

echo "✅ Kong sedang berjalan"

# Backup konfigurasi saat ini
echo "📦 Creating backup..."
BACKUP_FILE="kong_backup_$(date +%Y%m%d_%H%M%S).json"
curl -s http://localhost:9546/config > "$BACKUP_FILE"
echo "   Backup tersimpan di: $BACKUP_FILE"

# Validasi file YML
echo "✅ Validating YML..."
if [ -f "config/kong.yml" ]; then
    echo "   ✅ File kong.yml ditemukan"
    # Cek basic YAML structure
    if grep -q "_format_version" config/kong.yml && grep -q "services:" config/kong.yml; then
        echo "   ✅ YAML structure valid"
    else
        echo "   ❌ YAML structure tidak valid!"
        exit 1
    fi
else
    echo "   ❌ File kong.yml tidak ditemukan!"
    exit 1
fi

# Deploy konfigurasi
echo "🔄 Deploying configuration..."
DEPLOY_RESPONSE=$(curl -s -w "%{http_code}" -X POST http://localhost:9546/config -F "config=@config/kong.yml")
HTTP_CODE="${DEPLOY_RESPONSE: -3}"

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo "   ✅ Deploy berhasil (HTTP $HTTP_CODE)"
else
    echo "   ❌ Deploy gagal (HTTP $HTTP_CODE)"
    echo "   Response: ${DEPLOY_RESPONSE%???}"
    exit 1
fi

# Verifikasi deploy
echo "🔍 Verifying deployment..."

# Cek services
SERVICES_COUNT=$(curl -s http://localhost:9546/services/ | jq 'length' 2>/dev/null || echo "0")
echo "   Services deployed: $SERVICES_COUNT"

# Cek routes
ROUTES_COUNT=$(curl -s http://localhost:9546/routes/ | jq 'length' 2>/dev/null || echo "0")
echo "   Routes deployed: $ROUTES_COUNT"

# Cek plugins
PLUGINS_COUNT=$(curl -s http://localhost:9546/plugins/ | jq 'length' 2>/dev/null || echo "0")
echo "   Plugins deployed: $PLUGINS_COUNT"

# Test endpoint (opsional)
echo "🧪 Testing endpoints..."

# Test Kong Proxy
if curl -s http://localhost:9545/ > /dev/null 2>&1; then
    echo "   ✅ Kong Proxy accessible"
else
    echo "   ❌ Kong Proxy tidak dapat diakses"
fi

# Test Admin API
if curl -s http://localhost:9546/ > /dev/null 2>&1; then
    echo "   ✅ Kong Admin API accessible"
else
    echo "   ❌ Kong Admin API tidak dapat diakses"
fi

echo ""
echo "✅ Deployment completed!"
echo ""
echo "📋 Next steps:"
echo "   - Test endpoint baru: curl http://localhost:9545/api/v1/example"
echo "   - Monitor logs: docker-compose logs -f kong"
echo "   - Cek services: curl http://localhost:9546/services/"
echo "   - Cek routes: curl http://localhost:9546/routes/"
echo ""
echo "🔄 Jika ada masalah, rollback dengan:"
echo "   curl -X POST http://localhost:9546/config -F \"config=@$BACKUP_FILE\""
