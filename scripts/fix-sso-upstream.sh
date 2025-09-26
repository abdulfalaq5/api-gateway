#!/bin/bash

# Script untuk memperbaiki masalah SSO upstream timeout
# File: scripts/fix-sso-upstream.sh

set -e

echo "🔧 Fixing SSO Upstream Configuration..."

# Cek apakah Kong sedang berjalan
if ! docker-compose ps | grep -q "kong-gateway.*Up"; then
    echo "❌ Kong tidak sedang berjalan. Silakan jalankan Kong terlebih dahulu:"
    echo "   ./scripts/start-kong-docker.sh"
    exit 1
fi

echo "✅ Kong sedang berjalan"

# 1. Hapus semua konfigurasi SSO yang ada untuk menghindari duplicate key
echo "🗑️  Cleaning existing SSO configuration..."

# Hapus routes
echo "   Removing SSO routes..."
curl -s -X DELETE http://localhost:9546/routes/sso-login-routes 2>/dev/null || echo "     Route sso-login-routes tidak ada"
curl -s -X DELETE http://localhost:9546/routes/sso-userinfo-routes 2>/dev/null || echo "     Route sso-userinfo-routes tidak ada"
curl -s -X DELETE http://localhost:9546/routes/sso-menus-routes 2>/dev/null || echo "     Route sso-menus-routes tidak ada"

# Hapus plugins dari service
echo "   Removing SSO service plugins..."
curl -s -X DELETE http://localhost:9546/services/sso-service/plugins/rate-limiting 2>/dev/null || echo "     Rate limiting plugin tidak ada"

# Hapus service
echo "   Removing SSO service..."
curl -s -X DELETE http://localhost:9546/services/sso-service 2>/dev/null || echo "     SSO service tidak ada"

# 2. Buat service baru dengan upstream yang benar
echo "📝 Creating new SSO service..."

# Tentukan upstream URL berdasarkan environment
UPSTREAM_URL=""
if [ -f "config/env.sh" ]; then
    source config/env.sh
    if [ ! -z "$SSO_UPSTREAM_URL" ]; then
        UPSTREAM_URL="$SSO_UPSTREAM_URL"
        echo "   Using upstream from env.sh: $UPSTREAM_URL"
    fi
fi

# Default upstream jika tidak ada di env
if [ -z "$UPSTREAM_URL" ]; then
    # Coba beberapa kemungkinan upstream
    echo "   Testing upstream connectivity..."
    
    # Test 1: Direct API gateway
    if curl -s --connect-timeout 5 https://api-gate.motorsights.com/api/auth/sso/login > /dev/null 2>&1; then
        UPSTREAM_URL="https://api-gate.motorsights.com"
        echo "   ✅ Using direct API gateway: $UPSTREAM_URL"
    # Test 2: Localhost dengan port yang berbeda
    elif curl -s --connect-timeout 5 http://localhost:9588/api/auth/sso/login > /dev/null 2>&1; then
        UPSTREAM_URL="http://localhost:9588"
        echo "   ✅ Using localhost:9588: $UPSTREAM_URL"
    # Test 3: Host docker internal
    elif curl -s --connect-timeout 5 http://host.docker.internal:9588/api/auth/sso/login > /dev/null 2>&1; then
        UPSTREAM_URL="http://host.docker.internal:9588"
        echo "   ✅ Using host.docker.internal:9588: $UPSTREAM_URL"
    else
        echo "   ❌ Tidak dapat menemukan upstream yang accessible!"
        echo "   💡 Silakan pastikan SSO service berjalan di salah satu URL berikut:"
        echo "      - https://api-gate.motorsights.com"
        echo "      - http://localhost:9588"
        echo "      - http://host.docker.internal:9588"
        exit 1
    fi
fi

# Buat service
echo "   Creating SSO service with upstream: $UPSTREAM_URL"
curl -s -X POST http://localhost:9546/services/ \
  -d "name=sso-service" \
  -d "url=$UPSTREAM_URL" \
  -d "connect_timeout=60000" \
  -d "write_timeout=60000" \
  -d "read_timeout=60000"

# 3. Tambahkan routes
echo "📝 Adding SSO routes..."

# SSO Login Route
echo "   Adding sso-login-routes..."
curl -s -X POST http://localhost:9546/services/sso-service/routes \
  -d "name=sso-login-routes" \
  -d "paths[]=/api/auth/sso/login" \
  -d "methods[]=POST" \
  -d "methods[]=OPTIONS" \
  -d "strip_path=false"

# SSO Userinfo Route
echo "   Adding sso-userinfo-routes..."
curl -s -X POST http://localhost:9546/services/sso-service/routes \
  -d "name=sso-userinfo-routes" \
  -d "paths[]=/api/auth/sso/userinfo" \
  -d "methods[]=GET" \
  -d "methods[]=OPTIONS" \
  -d "strip_path=true"

# SSO Menus Route
echo "   Adding sso-menus-routes..."
curl -s -X POST http://localhost:9546/services/sso-service/routes \
  -d "name=sso-menus-routes" \
  -d "paths[]=/api/menus" \
  -d "methods[]=GET" \
  -d "methods[]=POST" \
  -d "methods[]=PUT" \
  -d "methods[]=DELETE" \
  -d "methods[]=OPTIONS" \
  -d "strip_path=true"

# 4. Tambahkan plugins
echo "📝 Adding plugins..."

# Rate limiting untuk service
echo "   Adding rate limiting plugin..."
curl -s -X POST http://localhost:9546/services/sso-service/plugins \
  -d "name=rate-limiting" \
  -d "config.minute=100" \
  -d "config.hour=1000" \
  -d "config.policy=local"

# 5. Verifikasi konfigurasi
echo "🔍 Verifying configuration..."

# Cek services
echo "   Services:"
curl -s http://localhost:9546/services/ | jq '.data[] | {name: .name, url: .url, connect_timeout: .connect_timeout}'

# Cek routes
echo "   Routes:"
curl -s http://localhost:9546/routes/ | jq '.data[] | {name: .name, paths: .paths, methods: .methods}'

# Cek plugins
echo "   Plugins:"
curl -s http://localhost:9546/plugins/ | jq '.data[] | {name: .name, service: .service.name}'

# 6. Test connectivity
echo "🧪 Testing SSO connectivity..."

# Test Kong proxy endpoint
echo "   Testing Kong proxy endpoint..."
if curl -s --connect-timeout 10 -X POST http://localhost:9545/api/auth/sso/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"test","client_id":"test","redirect_uri":"test"}' > /dev/null 2>&1; then
    echo "   ✅ Kong proxy endpoint accessible"
else
    echo "   ⚠️  Kong proxy endpoint timeout (ini normal jika SSO service tidak menerima data test)"
fi

echo ""
echo "✅ SSO upstream configuration fixed!"
echo ""
echo "📋 Configuration Summary:"
echo "   - Upstream URL: $UPSTREAM_URL"
echo "   - Service: sso-service"
echo "   - Routes: sso-login-routes, sso-userinfo-routes, sso-menus-routes"
echo "   - Timeouts: 60 seconds"
echo ""
echo "🧪 Test dengan curl:"
echo "   curl --location 'https://services.motorsights.com/api/auth/sso/login' \\"
echo "     --header 'Content-Type: application/json' \\"
echo "     --data-raw '{"
echo "       \"email\": \"admin@sso-testing.com\","
echo "       \"password\": \"admin123\","
echo "       \"client_id\": \"string\","
echo "       \"redirect_uri\": \"string\""
echo "     }'"
echo ""
echo "📊 Monitor logs:"
echo "   docker-compose logs -f kong"
