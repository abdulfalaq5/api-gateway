#!/bin/bash

# Script untuk deploy konfigurasi Kong dengan database
# File: scripts/deploy-kong-config-db.sh

set -e

echo "🚀 Deploying Kong Configuration (Database Mode)..."

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
curl -s http://localhost:9546/services/ > "services_$BACKUP_FILE"
curl -s http://localhost:9546/routes/ > "routes_$BACKUP_FILE"
curl -s http://localhost:9546/plugins/ > "plugins_$BACKUP_FILE"
echo "   Backup tersimpan di: services_$BACKUP_FILE, routes_$BACKUP_FILE, plugins_$BACKUP_FILE"

# Validasi file YML
echo "✅ Validating YML..."
if [ -f "config/kong.yml" ]; then
    echo "   ✅ File kong.yml ditemukan"
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

# Deploy services dan routes dari YML
echo "🔄 Deploying services and routes..."

# Hapus services yang ada (opsional - hati-hati!)
echo "⚠️  Menghapus services yang ada..."
curl -s -X DELETE http://localhost:9546/services/example-service 2>/dev/null || echo "   Service example-service tidak ada"
curl -s -X DELETE http://localhost:9546/services/sso-service 2>/dev/null || echo "   Service sso-service tidak ada"

# Tambahkan example-service
echo "📝 Adding example-service..."
curl -s -X POST http://localhost:9546/services/ \
  -d "name=example-service" \
  -d "url=http://localhost:3000"

# Tambahkan routes untuk example-service
echo "📝 Adding example-route..."
curl -s -X POST http://localhost:9546/services/example-service/routes \
  -d "name=example-route" \
  -d "paths[]=/api/v1/example" \
  -d "methods[]=GET" \
  -d "methods[]=POST" \
  -d "methods[]=PUT" \
  -d "methods[]=DELETE" \
  -d "strip_path=true"

# Tambahkan sso-service
echo "📝 Adding sso-service..."
curl -s -X POST http://localhost:9546/services/ \
  -d "name=sso-service" \
  -d "url=http://host.docker.internal:9588"

# Tambahkan routes untuk sso-service
echo "📝 Adding sso-login-routes..."
curl -s -X POST http://localhost:9546/services/sso-service/routes \
  -d "name=sso-login-routes" \
  -d "paths[]=/api/auth/sso/login" \
  -d "methods[]=POST" \
  -d "methods[]=OPTIONS" \
  -d "strip_path=false"

echo "📝 Adding sso-userinfo-routes..."
curl -s -X POST http://localhost:9546/services/sso-service/routes \
  -d "name=sso-userinfo-routes" \
  -d "paths[]=/api/auth/sso/userinfo" \
  -d "methods[]=GET" \
  -d "methods[]=OPTIONS" \
  -d "strip_path=true"

echo "📝 Adding sso-menus-routes..."
curl -s -X POST http://localhost:9546/services/sso-service/routes \
  -d "name=sso-menus-routes" \
  -d "paths[]=/api/menus" \
  -d "methods[]=GET" \
  -d "methods[]=POST" \
  -d "methods[]=PUT" \
  -d "methods[]=DELETE" \
  -d "methods[]=OPTIONS" \
  -d "strip_path=true"

# Tambahkan rate-limiting plugin untuk sso-service
echo "📝 Adding rate-limiting plugin..."
curl -s -X POST http://localhost:9546/services/sso-service/plugins \
  -d "name=rate-limiting" \
  -d "config.minute=100" \
  -d "config.hour=1000" \
  -d "config.policy=local"

# Tambahkan CORS plugin global
echo "📝 Adding CORS plugin..."
curl -s -X POST http://localhost:9546/plugins \
  -d "name=cors" \
  -d "config.origins[]=*" \
  -d "config.methods[]=GET" \
  -d "config.methods[]=POST" \
  -d "config.methods[]=PUT" \
  -d "config.methods[]=DELETE" \
  -d "config.methods[]=OPTIONS" \
  -d "config.headers[]=Accept" \
  -d "config.headers[]=Accept-Version" \
  -d "config.headers[]=Content-Length" \
  -d "config.headers[]=Content-MD5" \
  -d "config.headers[]=Content-Type" \
  -d "config.headers[]=Date" \
  -d "config.headers[]=Authorization" \
  -d "config.headers[]=X-Auth-Token" \
  -d "config.exposed_headers[]=X-Auth-Token" \
  -d "config.exposed_headers[]=Authorization" \
  -d "config.credentials=true" \
  -d "config.max_age=3600" \
  -d "config.preflight_continue=false"

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

# Test endpoint
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
echo "   - Test example service: curl http://localhost:9545/api/v1/example"
echo "   - Test SSO login: curl -X POST http://localhost:9545/api/auth/sso/login"
echo "   - Monitor logs: docker-compose logs -f kong"
echo "   - Cek services: curl http://localhost:9546/services/"
echo "   - Cek routes: curl http://localhost:9546/routes/"
echo ""
echo "🔄 Jika ada masalah, cek log: docker-compose logs kong"
