#!/bin/bash

# Script untuk debugging Kong di remote server
# Usage: ./debug-remote-kong.sh

echo "================================================"
echo "🔍 REMOTE KONG DEBUGGING TOOL"
echo "================================================"
echo "Target: https://services.motorsights.com"
echo ""

# Test root path
echo "1️⃣  Testing Root Path (/):"
echo "================================================"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" https://services.motorsights.com/)
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

echo "Status Code: $HTTP_CODE"
echo "Response Body:"
echo "$BODY"
echo ""

# Test common API endpoints
echo "2️⃣  Testing API Endpoints:"
echo "================================================"

ENDPOINTS=(
    "/api/auth/sso/login"
    "/api/menus"
    "/api/companies"
    "/api/categories"
    "/api/powerbi"
    "/api/candidates"
)

for endpoint in "${ENDPOINTS[@]}"; do
    echo -n "Testing $endpoint ... "
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST https://services.motorsights.com$endpoint -H "Content-Type: application/json" 2>/dev/null)
    
    if [ "$STATUS" = "404" ]; then
        echo "❌ $STATUS (Not Found)"
    elif [ "$STATUS" = "401" ]; then
        echo "✅ $STATUS (Unauthorized - Route exists, needs auth)"
    elif [ "$STATUS" = "200" ]; then
        echo "✅ $STATUS (OK)"
    elif [ "$STATUS" = "405" ]; then
        echo "⚠️  $STATUS (Method Not Allowed - Try GET)"
        # Try GET method
        STATUS_GET=$(curl -s -o /dev/null -w "%{http_code}" https://services.motorsights.com$endpoint 2>/dev/null)
        echo "   GET method: $STATUS_GET"
    else
        echo "⚠️  $STATUS"
    fi
done
echo ""

# Try to get Kong version (if admin API is exposed)
echo "3️⃣  Checking Kong Configuration:"
echo "================================================"
echo "Trying to access Kong Admin API..."
ADMIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://services.motorsights.com:8001/status 2>/dev/null)
if [ "$ADMIN_STATUS" = "000" ]; then
    echo "⚠️  Kong Admin API not accessible from external (this is good for security)"
else
    echo "Status: $ADMIN_STATUS"
fi
echo ""

echo "4️⃣  Diagnosis:"
echo "================================================"
if [ "$HTTP_CODE" = "404" ]; then
    echo "❌ Root path (/) is not configured in Kong routes"
    echo ""
    echo "📋 KEMUNGKINAN PENYEBAB:"
    echo "1. Tidak ada route yang defined untuk path '/'"
    echo "2. Kong config (kong.yml) belum di-load ke server"
    echo "3. Kong service belum di-restart setelah update config"
    echo ""
    echo "💡 SOLUSI:"
    echo "1. Akses endpoint spesifik seperti:"
    echo "   - https://services.motorsights.com/api/auth/sso/login"
    echo "   - https://services.motorsights.com/api/menus"
    echo "   - https://services.motorsights.com/api/categories"
    echo ""
    echo "2. Atau tambahkan route untuk root path (/) di kong.yml:"
    echo "   services:"
    echo "     - name: default-service"
    echo "       url: http://your-default-backend"
    echo "       routes:"
    echo "         - name: root-route"
    echo "           paths:"
    echo "             - /"
    echo ""
    echo "3. Deploy ulang config ke server:"
    echo "   ./scripts/deploy-kong-config-server.sh"
fi
echo ""

echo "================================================"
echo "✅ Remote Debugging Complete!"
echo "================================================"

