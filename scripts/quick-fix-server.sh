#!/bin/bash

# Quick Fix for Kong Server Routing
echo "🔧 Quick Fix Kong Server Routing..."

# Check Kong status
echo "📋 Checking Kong status..."
if docker ps | grep -q kong-gateway; then
    echo "✅ Kong is running"
else
    echo "❌ Kong is not running"
    exit 1
fi

# Check current routes
echo "📋 Checking current routes..."
routes=$(curl -s http://localhost:9546/routes 2>/dev/null)
route_count=$(echo "$routes" | jq '.data | length' 2>/dev/null || echo "0")

echo "Found $route_count routes"

if [[ "$route_count" -eq 0 ]]; then
    echo "⚠️  No routes found - deploying configuration..."
    
    # Stop Kong
    echo "🛑 Stopping Kong..."
    docker-compose -f docker-compose.server.yml stop kong
    
    # Start Kong
    echo "🚀 Starting Kong..."
    docker-compose -f docker-compose.server.yml up -d kong
    
    # Wait for Kong
    echo "⏳ Waiting for Kong to be ready..."
    sleep 15
    
    # Check routes again
    echo "📋 Checking routes after restart..."
    routes=$(curl -s http://localhost:9546/routes 2>/dev/null)
    route_count=$(echo "$routes" | jq '.data | length' 2>/dev/null || echo "0")
    echo "Found $route_count routes"
    
    if [[ "$route_count" -gt 0 ]]; then
        echo "✅ Routes loaded successfully"
        echo "Routes:"
        echo "$routes" | jq '.data[].name' 2>/dev/null || true
    else
        echo "❌ Still no routes found"
        echo "📋 Kong logs:"
        docker logs kong-gateway --tail 10
        exit 1
    fi
else
    echo "✅ Routes already exist"
fi

# Test SSO endpoint
echo "🧪 Testing SSO endpoint..."
test_response=$(curl -s -X POST http://localhost:9545/api/auth/sso/login \
    -H "Content-Type: application/json" \
    -d '{"email": "admin@sso-testing.com", "password": "admin123", "client_id": "string", "redirect_uri": "string"}' \
    2>/dev/null || echo "ERROR")

if echo "$test_response" | grep -q "Login SSO berhasil"; then
    echo "✅ SSO endpoint working correctly!"
    echo ""
    echo "🎉 Kong Server is ready!"
    echo "📍 SSO URL: http://your-server-ip:9545/api/auth/sso/login"
else
    echo "❌ SSO endpoint not working"
    echo "Response: $test_response"
    
    # Show Kong logs
    echo ""
    echo "📋 Recent Kong logs:"
    docker logs kong-gateway --tail 20
fi
