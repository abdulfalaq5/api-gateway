#!/bin/bash

# Script untuk setup Kong di server baru dengan konfigurasi yang sudah ada
# File: scripts/setup-kong-new-server.sh

set -e

echo "🚀 Setting up Kong on New Server"
echo "================================"

# Cek apakah Kong sudah berjalan
if docker-compose ps | grep -q "kong-gateway.*Up"; then
    echo "✅ Kong sudah berjalan"
else
    echo "📦 Starting Kong..."
    docker-compose up -d
    echo "⏳ Waiting for Kong to start..."
    sleep 30
fi

# Cek apakah Kong accessible
if ! curl -s --connect-timeout 5 http://localhost:9546/ > /dev/null 2>&1; then
    echo "❌ Kong tidak accessible. Checking logs..."
    docker-compose logs kong | tail -20
    exit 1
fi

echo "✅ Kong is accessible"

# Cek apakah ada konfigurasi yang sudah ada
echo "🔍 Checking existing configuration..."
SERVICES_COUNT=$(curl -s http://localhost:9546/services/ | jq 'length' 2>/dev/null || echo "0")
ROUTES_COUNT=$(curl -s http://localhost:9546/routes/ | jq 'length' 2>/dev/null || echo "0")

if [ "$SERVICES_COUNT" -gt 0 ] || [ "$ROUTES_COUNT" -gt 0 ]; then
    echo "⚠️  Kong sudah memiliki konfigurasi:"
    echo "   Services: $SERVICES_COUNT"
    echo "   Routes: $ROUTES_COUNT"
    echo ""
    echo "Pilihan:"
    echo "1. Backup dan replace dengan konfigurasi baru"
    echo "2. Skip setup (konfigurasi sudah ada)"
    echo "3. Exit"
    echo ""
    read -p "Pilih (1/2/3): " choice
    
    case $choice in
        1)
            echo "📦 Creating backup..."
            BACKUP_FILE="kong_backup_$(date +%Y%m%d_%H%M%S).json"
            curl -s http://localhost:9546/config > "$BACKUP_FILE"
            echo "   Backup tersimpan di: $BACKUP_FILE"
            ;;
        2)
            echo "✅ Skipping setup. Kong sudah dikonfigurasi."
            exit 0
            ;;
        3)
            echo "👋 Exiting..."
            exit 0
            ;;
        *)
            echo "❌ Pilihan tidak valid"
            exit 1
            ;;
    esac
fi

# Setup konfigurasi default
echo "🔧 Setting up default configuration..."

# Buat service SSO
echo "   Creating SSO service..."
curl -X POST http://localhost:9546/services/ \
  -d "name=sso-service" \
  -d "url=https://api-gate.motorsights.com" \
  -d "connect_timeout=60000" \
  -d "write_timeout=60000" \
  -d "read_timeout=60000" > /dev/null 2>&1

# Buat routes SSO
echo "   Creating SSO routes..."

# SSO Login Route
curl -X POST http://localhost:9546/services/sso-service/routes \
  -d "name=sso-login-routes" \
  -d "paths[]=/api/auth/sso/login" \
  -d "methods[]=POST" \
  -d "methods[]=OPTIONS" \
  -d "strip_path=false" > /dev/null 2>&1

# SSO Userinfo Route
curl -X POST http://localhost:9546/services/sso-service/routes \
  -d "name=sso-userinfo-routes" \
  -d "paths[]=/api/auth/sso/userinfo" \
  -d "methods[]=GET" \
  -d "methods[]=OPTIONS" \
  -d "strip_path=true" > /dev/null 2>&1

# SSO Menus Route
curl -X POST http://localhost:9546/services/sso-service/routes \
  -d "name=sso-menus-routes" \
  -d "paths[]=/api/menus" \
  -d "methods[]=GET" \
  -d "methods[]=POST" \
  -d "methods[]=PUT" \
  -d "methods[]=DELETE" \
  -d "methods[]=OPTIONS" \
  -d "strip_path=true" > /dev/null 2>&1

# Tambahkan plugins
echo "   Adding plugins..."

# Rate limiting untuk service
curl -X POST http://localhost:9546/services/sso-service/plugins \
  -d "name=rate-limiting" \
  -d "config.minute=100" \
  -d "config.hour=1000" \
  -d "config.policy=local" > /dev/null 2>&1

# CORS global
curl -X POST http://localhost:9546/plugins \
  -d "name=cors" \
  -d "config.origins=*" \
  -d "config.methods=GET,POST,PUT,DELETE,OPTIONS" \
  -d "config.headers=Accept,Accept-Version,Content-Length,Content-MD5,Content-Type,Date,Authorization,X-Auth-Token" \
  -d "config.exposed_headers=X-Auth-Token,Authorization" \
  -d "config.credentials=true" \
  -d "config.max_age=3600" \
  -d "config.preflight_continue=false" > /dev/null 2>&1

echo "✅ Default configuration created"

# Verifikasi setup
echo "🔍 Verifying setup..."
SERVICES_COUNT=$(curl -s http://localhost:9546/services/ | jq 'length' 2>/dev/null || echo "0")
ROUTES_COUNT=$(curl -s http://localhost:9546/routes/ | jq 'length' 2>/dev/null || echo "0")
PLUGINS_COUNT=$(curl -s http://localhost:9546/plugins/ | jq 'length' 2>/dev/null || echo "0")

echo "   Services: $SERVICES_COUNT"
echo "   Routes: $ROUTES_COUNT"
echo "   Plugins: $PLUGINS_COUNT"

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
echo "✅ Kong setup completed!"
echo ""
echo "📋 Next steps:"
echo "   - Test endpoints: curl http://localhost:9545/api/auth/sso/login"
echo "   - Monitor logs: docker-compose logs -f kong"
echo "   - Add more services/routes as needed"
echo ""
echo "🔧 To add more endpoints:"
echo "   curl -X POST http://localhost:9546/services/sso-service/routes \\"
echo "     -d \"name=your-endpoint-routes\" \\"
echo "     -d \"paths[]=/api/your-endpoint\" \\"
echo "     -d \"methods[]=GET\" \\"
echo "     -d \"methods[]=POST\" \\"
echo "     -d \"strip_path=false\""
echo ""
echo "📊 Monitor logs:"
echo "   docker-compose logs -f kong"
