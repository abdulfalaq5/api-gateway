#!/bin/bash

# Script untuk debugging Kong routes
# Usage: ./debug-kong-routes.sh [kong-admin-url]

KONG_ADMIN_URL="${1:-http://localhost:8001}"
KONG_PROXY_URL="${2:-http://localhost:8000}"

echo "================================================"
echo "🔍 KONG ROUTE DEBUGGING TOOL"
echo "================================================"
echo "Kong Admin URL: $KONG_ADMIN_URL"
echo "Kong Proxy URL: $KONG_PROXY_URL"
echo ""

# Check if Kong Admin API is accessible
echo "1️⃣  Checking Kong Admin API..."
if ! curl -s -f "$KONG_ADMIN_URL/status" > /dev/null 2>&1; then
    echo "❌ ERROR: Cannot connect to Kong Admin API at $KONG_ADMIN_URL"
    echo "   Make sure Kong is running!"
    exit 1
fi
echo "✅ Kong Admin API is accessible"
echo ""

# Check Kong status
echo "2️⃣  Kong Status:"
curl -s "$KONG_ADMIN_URL/status" | jq '{
    database: .database.reachable,
    server: .server.connections_accepted,
    memory: .memory.lua_shared_dicts
}' 2>/dev/null || curl -s "$KONG_ADMIN_URL/status"
echo ""

# List all services
echo "3️⃣  Registered Services:"
echo "================================================"
curl -s "$KONG_ADMIN_URL/services" | jq -r '.data[] | "Service: \(.name)\n  URL: \(.url)\n  ID: \(.id)\n"' 2>/dev/null || echo "Error fetching services"
echo ""

# List all routes
echo "4️⃣  Registered Routes:"
echo "================================================"
ROUTES=$(curl -s "$KONG_ADMIN_URL/routes" | jq -r '.data[] | "Route: \(.name)\n  Paths: \(.paths // [])\n  Methods: \(.methods // [])\n  Service: \(.service.id)\n  Strip Path: \(.strip_path)\n"' 2>/dev/null)

if [ -z "$ROUTES" ]; then
    echo "❌ No routes found or error fetching routes!"
else
    echo "$ROUTES"
fi
echo ""

# Count routes
ROUTE_COUNT=$(curl -s "$KONG_ADMIN_URL/routes" | jq '.data | length' 2>/dev/null)
echo "📊 Total Routes: $ROUTE_COUNT"
echo ""

# Test specific path
echo "5️⃣  Testing Common Paths:"
echo "================================================"

# Test root path
echo "Testing: GET /"
curl -s -o /dev/null -w "Status: %{http_code}\n" "$KONG_PROXY_URL/"
echo ""

# Test some common paths from your config
COMMON_PATHS=(
    "/api/auth/sso/login"
    "/api/menus"
    "/api/categories"
    "/api/powerbi"
)

for path in "${COMMON_PATHS[@]}"; do
    echo "Testing: GET $path"
    curl -s -o /dev/null -w "Status: %{http_code}\n" "$KONG_PROXY_URL$path"
done
echo ""

# Check for root path route
echo "6️⃣  Checking for Root Path (/) Route:"
echo "================================================"
ROOT_ROUTE=$(curl -s "$KONG_ADMIN_URL/routes" | jq -r '.data[] | select(.paths[]? == "/")' 2>/dev/null)
if [ -z "$ROOT_ROUTE" ]; then
    echo "⚠️  WARNING: No route configured for root path (/)"
    echo "   This is why you get 'no Route matched' error!"
    echo ""
    echo "💡 SOLUTION:"
    echo "   Add a route for '/' or access specific endpoints like:"
    echo "   - /api/auth/sso/login"
    echo "   - /api/menus"
    echo "   - /api/powerbi"
else
    echo "✅ Root path route found:"
    echo "$ROOT_ROUTE" | jq '.'
fi
echo ""

echo "================================================"
echo "✅ Debugging Complete!"
echo "================================================"
echo ""
echo "📝 Next Steps:"
echo "1. Check if Kong config is loaded (kong.yml)"
echo "2. Restart Kong if routes are missing"
echo "3. Access specific API endpoints instead of root path"
echo ""

