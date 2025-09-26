#!/bin/bash

# Script untuk update kong.yml dan reload Kong
# File: scripts/update-kong-yml.sh

set -e

echo "🔄 Updating Kong Configuration from kong.yml"
echo "============================================="

# Cek apakah kong.yml ada
if [ ! -f "config/kong.yml" ]; then
    echo "❌ File config/kong.yml tidak ditemukan!"
    exit 1
fi

echo "✅ Found config/kong.yml"

# Cek apakah Kong berjalan
if ! curl -s --connect-timeout 5 http://localhost:9546/ > /dev/null 2>&1; then
    echo "❌ Kong tidak berjalan. Starting Kong..."
    docker-compose up -d
    sleep 15
fi

echo "✅ Kong is running"

# Backup konfigurasi saat ini
echo "📦 Creating backup..."
BACKUP_FILE="kong_backup_$(date +%Y%m%d_%H%M%S).json"
curl -s http://localhost:9546/config > "$BACKUP_FILE"
echo "   Backup tersimpan di: $BACKUP_FILE"

# Deploy konfigurasi dari kong.yml
echo "🔄 Deploying configuration from kong.yml..."
DEPLOY_RESPONSE=$(curl -s -w "%{http_code}" -X POST http://localhost:9546/config -F "config=@config/kong.yml")
HTTP_CODE="${DEPLOY_RESPONSE: -3}"

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo "   ✅ Deploy berhasil (HTTP $HTTP_CODE)"
else
    echo "   ❌ Deploy gagal (HTTP $HTTP_CODE)"
    echo "   Response: ${DEPLOY_RESPONSE%???}"
    echo ""
    echo "🔄 Rolling back to backup..."
    curl -X POST http://localhost:9546/config -F "config=@$BACKUP_FILE" > /dev/null 2>&1
    echo "   ✅ Rollback completed"
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
if curl -s --connect-timeout 10 -X POST http://localhost:9545/api/auth/sso/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@sso-testing.com","password":"admin123","client_id":"string","redirect_uri":"string"}' > /dev/null 2>&1; then
    echo "   ✅ SSO endpoint working"
else
    echo "   ⚠️  SSO endpoint timeout (check if SSO service is accessible)"
fi

# Show configuration
echo "📋 Configuration summary:"
echo "   Services:"
curl -s http://localhost:9546/services/ | jq '.data[] | {name: .name, host: .host, port: .port, protocol: .protocol}' 2>/dev/null || echo "   ❌ Cannot get services"

echo "   Routes:"
curl -s http://localhost:9546/routes/ | jq '.data[] | {name: .name, paths: .paths, service: .service.name}' 2>/dev/null || echo "   ❌ Cannot get routes"

echo ""
echo "✅ Kong configuration updated from kong.yml!"
echo ""
echo "📋 Next steps:"
echo "   - Test endpoints: curl http://localhost:9545/api/auth/sso/login"
echo "   - Monitor logs: docker-compose logs -f kong"
echo "   - Edit config/kong.yml untuk perubahan selanjutnya"
echo ""
echo "🔄 To update again:"
echo "   ./scripts/update-kong-yml.sh"
echo ""
echo "🔄 To rollback:"
echo "   curl -X POST http://localhost:9546/config -F \"config=@$BACKUP_FILE\""
