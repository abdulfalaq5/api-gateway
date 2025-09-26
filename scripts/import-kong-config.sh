#!/bin/bash

# Script untuk import Kong configuration ke server baru
# File: scripts/import-kong-config.sh

set -e

echo "🚀 Importing Kong Configuration to New Server"
echo "=============================================="

# Cek parameter
if [ -z "$1" ]; then
    echo "❌ Usage: $0 <config-file>"
    echo "   Example: $0 kong.yml"
    echo "   Example: $0 kong_full_config.json"
    exit 1
fi

CONFIG_FILE="$1"

# Cek apakah file ada
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ File $CONFIG_FILE tidak ditemukan!"
    exit 1
fi

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
echo "🔄 Deploying configuration from $CONFIG_FILE..."

# Cek jenis file
if [[ "$CONFIG_FILE" == *.yml ]] || [[ "$CONFIG_FILE" == *.yaml ]]; then
    # Declarative YAML
    echo "   Detected YAML configuration"
    DEPLOY_RESPONSE=$(curl -s -w "%{http_code}" -X POST http://localhost:9546/config -F "config=@$CONFIG_FILE")
elif [[ "$CONFIG_FILE" == *.json ]]; then
    # JSON configuration
    echo "   Detected JSON configuration"
    DEPLOY_RESPONSE=$(curl -s -w "%{http_code}" -X POST http://localhost:9546/config -F "config=@$CONFIG_FILE")
else
    echo "   ❌ Unsupported file format. Use .yml, .yaml, or .json"
    exit 1
fi

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

# Tunggu sebentar untuk Kong memproses
sleep 5

SERVICES_COUNT=$(curl -s http://localhost:9546/services/ | jq 'length' 2>/dev/null || echo "0")
ROUTES_COUNT=$(curl -s http://localhost:9546/routes/ | jq 'length' 2>/dev/null || echo "0")
PLUGINS_COUNT=$(curl -s http://localhost:9546/plugins/ | jq 'length' 2>/dev/null || echo "0")

echo "   Services deployed: $SERVICES_COUNT"
echo "   Routes deployed: $ROUTES_COUNT"
echo "   Plugins deployed: $PLUGINS_COUNT"

# Test Kong proxy
echo "🧪 Testing Kong proxy..."
if curl -s http://localhost:9545/ > /dev/null 2>&1; then
    echo "   ✅ Kong Proxy accessible"
else
    echo "   ❌ Kong Proxy tidak dapat diakses"
fi

# Test endpoints jika ada
echo "🧪 Testing endpoints..."
if curl -s --connect-timeout 10 -X POST http://localhost:9545/api/auth/sso/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@sso-testing.com","password":"admin123","client_id":"string","redirect_uri":"string"}' > /dev/null 2>&1; then
    echo "   ✅ SSO endpoint working"
else
    echo "   ⚠️  SSO endpoint timeout (check if SSO service is accessible)"
fi

# Show services
echo "📋 Deployed services:"
curl -s http://localhost:9546/services/ | jq '.data[] | {name: .name, host: .host, port: .port, protocol: .protocol}' 2>/dev/null || echo "   ❌ Cannot get services"

echo ""
echo "✅ Import completed!"
echo ""
echo "📋 Next steps:"
echo "   - Test endpoints: curl http://localhost:9545/api/your-endpoint"
echo "   - Monitor logs: docker-compose logs -f kong"
echo "   - Cek services: curl http://localhost:9546/services/"
echo "   - Cek routes: curl http://localhost:9546/routes/"
echo ""
echo "🔄 Jika ada masalah, rollback dengan:"
echo "   curl -X POST http://localhost:9546/config -F \"config=@$BACKUP_FILE\""
echo ""
echo "📊 Monitor logs:"
echo "   docker-compose logs -f kong"
