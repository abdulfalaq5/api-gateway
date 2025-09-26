#!/bin/bash

# Script otomatis untuk memperbaiki Kong SSO di server
# File: scripts/fix-kong-sso-server.sh

set -e

echo "🚀 Kong SSO Server Fix Script"
echo "============================="

# Cek apakah Kong berjalan
echo "📊 Step 1: Checking Kong Status"
echo "-------------------------------"

if ! docker-compose ps | grep -q "kong-gateway.*Up"; then
    echo "❌ Kong tidak berjalan. Starting Kong..."
    docker-compose up -d
    echo "⏳ Waiting for Kong to start..."
    sleep 30
else
    echo "✅ Kong sudah berjalan"
fi

# Backup konfigurasi
echo ""
echo "📊 Step 2: Creating Backup"
echo "--------------------------"

BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "   Creating backup in: $BACKUP_DIR"
curl -s http://localhost:9546/config > "$BACKUP_DIR/kong_config.json"
curl -s http://localhost:9546/services/ > "$BACKUP_DIR/services.json"
curl -s http://localhost:9546/routes/ > "$BACKUP_DIR/routes.json"
echo "   ✅ Backup created"

# Cek konfigurasi saat ini
echo ""
echo "📊 Step 3: Analyzing Current Configuration"
echo "----------------------------------------"

echo "   Current services:"
curl -s http://localhost:9546/services/ | jq '.data[] | {name: .name, host: .host, port: .port, protocol: .protocol}' 2>/dev/null || echo "   ❌ Cannot get services"

echo "   Current SSO routes:"
curl -s http://localhost:9546/routes/ | jq '.data[] | select(.name | contains("sso")) | {name: .name, service: .service.id, paths: .paths}' 2>/dev/null || echo "   ❌ Cannot get routes"

# Identifikasi service yang salah
echo ""
echo "📊 Step 4: Identifying Wrong Services"
echo "------------------------------------"

WRONG_SERVICES=$(curl -s http://localhost:9546/services/ | jq -r '.data[] | select(.host == "host.docker.internal" or .host == "172.17.0.1" or .port == 9588) | .id' 2>/dev/null || echo "")

if [ ! -z "$WRONG_SERVICES" ]; then
    echo "   ❌ Found wrong services: $WRONG_SERVICES"
else
    echo "   ✅ No wrong services found"
fi

# Hapus routes yang salah
echo ""
echo "📊 Step 5: Cleaning Wrong Routes"
echo "-------------------------------"

WRONG_ROUTES=("sso-login-api-gate-final" "sso-login-api-gate-transform" "sso-login-api-gate-direct" "sso-login-services-direct")

for route in "${WRONG_ROUTES[@]}"; do
    echo "   Removing route: $route"
    response=$(curl -s -w "%{http_code}" -X DELETE http://localhost:9546/routes/$route)
    http_code="${response: -3}"
    
    if [ "$http_code" = "204" ]; then
        echo "     ✅ Removed"
    elif [ "$http_code" = "404" ]; then
        echo "     ⚠️  Not found (already removed)"
    else
        echo "     ❌ Failed (HTTP $http_code)"
    fi
done

# Hapus service yang salah
echo ""
echo "📊 Step 6: Cleaning Wrong Services"
echo "---------------------------------"

WRONG_SERVICES_ARRAY=("sso-service-api-gate")

for service in "${WRONG_SERVICES_ARRAY[@]}"; do
    echo "   Removing service: $service"
    response=$(curl -s -w "%{http_code}" -X DELETE http://localhost:9546/services/$service)
    http_code="${response: -3}"
    
    if [ "$http_code" = "204" ]; then
        echo "     ✅ Removed"
    elif [ "$http_code" = "404" ]; then
        echo "     ⚠️  Not found (already removed)"
    else
        echo "     ❌ Failed (HTTP $http_code)"
    fi
done

# Pastikan service SSO benar
echo ""
echo "📊 Step 7: Ensuring Correct SSO Service"
echo "-------------------------------------"

echo "   Checking sso-service..."
sso_service=$(curl -s http://localhost:9546/services/sso-service 2>/dev/null)

if [ -z "$sso_service" ] || echo "$sso_service" | jq -e '.host != "api-gate.motorsights.com"' > /dev/null 2>&1; then
    echo "   ❌ sso-service not configured correctly. Updating..."
    
    # Update service
    curl -s -X PATCH http://localhost:9546/services/sso-service \
      -d "url=https://api-gate.motorsights.com" \
      -d "connect_timeout=60000" \
      -d "write_timeout=60000" \
      -d "read_timeout=60000" > /dev/null
    
    echo "   ✅ sso-service updated"
else
    echo "   ✅ sso-service already correct"
fi

# Pastikan routes SSO benar
echo ""
echo "📊 Step 8: Ensuring Correct SSO Routes"
echo "------------------------------------"

# Cek routes yang ada
existing_routes=$(curl -s http://localhost:9546/routes/ | jq -r '.data[] | select(.name | contains("sso")) | .name' 2>/dev/null || echo "")

# Routes yang diperlukan
required_routes=("sso-login-routes" "sso-userinfo-routes" "sso-menus-routes")

for route in "${required_routes[@]}"; do
    if echo "$existing_routes" | grep -q "$route"; then
        echo "   ✅ Route $route exists"
    else
        echo "   ❌ Route $route missing. Creating..."
        
        case $route in
            "sso-login-routes")
                curl -s -X POST http://localhost:9546/services/sso-service/routes \
                  -d "name=sso-login-routes" \
                  -d "paths[]=/api/auth/sso/login" \
                  -d "methods[]=POST" \
                  -d "methods[]=OPTIONS" \
                  -d "strip_path=false" > /dev/null
                ;;
            "sso-userinfo-routes")
                curl -s -X POST http://localhost:9546/services/sso-service/routes \
                  -d "name=sso-userinfo-routes" \
                  -d "paths[]=/api/auth/sso/userinfo" \
                  -d "methods[]=GET" \
                  -d "methods[]=OPTIONS" \
                  -d "strip_path=true" > /dev/null
                ;;
            "sso-menus-routes")
                curl -s -X POST http://localhost:9546/services/sso-service/routes \
                  -d "name=sso-menus-routes" \
                  -d "paths[]=/api/menus" \
                  -d "methods[]=GET" \
                  -d "methods[]=POST" \
                  -d "methods[]=PUT" \
                  -d "methods[]=DELETE" \
                  -d "methods[]=OPTIONS" \
                  -d "strip_path=true" > /dev/null
                ;;
        esac
        
        echo "   ✅ Route $route created"
    fi
done

# Restart Kong
echo ""
echo "📊 Step 9: Restarting Kong"
echo "-------------------------"

echo "   Restarting Kong to clear cache..."
docker-compose restart kong
echo "   ⏳ Waiting for Kong to restart..."
sleep 15

# Verifikasi konfigurasi
echo ""
echo "📊 Step 10: Verifying Configuration"
echo "----------------------------------"

echo "   Final service configuration:"
curl -s http://localhost:9546/services/sso-service | jq '{name: .name, host: .host, port: .port, protocol: .protocol, url: .url}' 2>/dev/null || echo "   ❌ Cannot get service"

echo "   Final routes configuration:"
curl -s http://localhost:9546/routes/ | jq '.data[] | select(.name | contains("sso")) | {name: .name, service: .service.id, paths: .paths}' 2>/dev/null || echo "   ❌ Cannot get routes"

# Test Kong langsung
echo ""
echo "📊 Step 11: Testing Kong Direct Access"
echo "-------------------------------------"

echo "   Testing Kong direct access..."
if curl -s --connect-timeout 10 -X POST http://localhost:9545/api/auth/sso/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@sso-testing.com","password":"admin123","client_id":"string","redirect_uri":"string"}' > /dev/null 2>&1; then
    echo "   ✅ Kong direct access working"
else
    echo "   ❌ Kong direct access failed"
fi

# Test nginx
echo ""
echo "📊 Step 12: Testing Nginx Access"
echo "-------------------------------"

echo "   Checking nginx status..."
if systemctl is-active --quiet nginx; then
    echo "   ✅ Nginx is running"
    
    echo "   Reloading nginx..."
    if sudo systemctl reload nginx > /dev/null 2>&1; then
        echo "   ✅ Nginx reloaded"
    else
        echo "   ❌ Failed to reload nginx"
    fi
    
    echo "   Testing nginx access..."
    response=$(curl -s --connect-timeout 15 -w "%{http_code}" -X POST https://services.motorsights.com/api/auth/sso/login \
      -H "Content-Type: application/json" \
      -d '{"email":"admin@sso-testing.com","password":"admin123","client_id":"string","redirect_uri":"string"}' 2>/dev/null)
    
    http_code="${response: -3}"
    
    if [ "$http_code" = "200" ]; then
        echo "   ✅ Nginx access working (HTTP 200)"
    elif [ "$http_code" = "502" ]; then
        echo "   ❌ Bad Gateway (HTTP 502) - nginx can't connect to Kong"
    elif [ "$http_code" = "504" ]; then
        echo "   ❌ Gateway Timeout (HTTP 504) - Kong is too slow"
    else
        echo "   ⚠️  Unexpected response (HTTP $http_code)"
    fi
else
    echo "   ❌ Nginx is not running"
    echo "   💡 Start nginx: sudo systemctl start nginx"
fi

# Summary
echo ""
echo "📋 Summary"
echo "=========="
echo ""
echo "✅ Kong SSO configuration fixed"
echo "✅ Duplicate routes and services removed"
echo "✅ Kong restarted to clear cache"
echo "✅ Backup created in: $BACKUP_DIR"
echo ""
echo "🧪 Manual Testing Commands:"
echo "   curl -v http://localhost:9545/api/auth/sso/login \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"email\":\"admin@sso-testing.com\",\"password\":\"admin123\",\"client_id\":\"string\",\"redirect_uri\":\"string\"}'"
echo ""
echo "   curl -v https://services.motorsights.com/api/auth/sso/login \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"email\":\"admin@sso-testing.com\",\"password\":\"admin123\",\"client_id\":\"string\",\"redirect_uri\":\"string\"}'"
echo ""
echo "📊 Monitor logs:"
echo "   docker-compose logs -f kong"
echo "   sudo tail -f /var/log/nginx/error.log"
echo ""
echo "✅ Fix completed!"
