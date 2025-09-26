#!/bin/bash

# Quick Server Fix for Kong
echo "🚀 Quick Server Fix for Kong..."

# Stop Kong
echo "🛑 Stopping Kong..."
docker-compose -f docker-compose.server.yml down
docker rm -f kong-gateway 2>/dev/null || true

# Clean up
echo "🧹 Cleaning up..."
docker network prune -f

# Start Kong
echo "🚀 Starting Kong..."
docker-compose -f docker-compose.server.yml up -d

# Wait
echo "⏳ Waiting for Kong..."
sleep 20

# Check status
echo "📋 Checking Kong status..."
if docker ps | grep -q kong-gateway; then
    echo "✅ Kong is running"
    
    # Check health
    if curl -s http://localhost:9546/status > /dev/null 2>&1; then
        echo "✅ Kong is healthy"
    else
        echo "❌ Kong is not healthy"
        exit 1
    fi
    
    # Check routes
    echo "📋 Checking routes..."
    routes=$(curl -s http://localhost:9546/routes 2>/dev/null)
    route_count=$(echo "$routes" | jq '.data | length' 2>/dev/null || echo "0")
    
    if [[ "$route_count" -gt 0 ]]; then
        echo "✅ Found $route_count routes"
        echo "Routes:"
        echo "$routes" | jq '.data[].name' 2>/dev/null || true
    else
        echo "❌ No routes found"
        echo "📋 Kong logs:"
        docker logs kong-gateway --tail 20
        exit 1
    fi
    
    # Test SSO
    echo "🧪 Testing SSO endpoint..."
    test_response=$(curl -s -X POST http://localhost:9545/api/auth/sso/login \
        -H "Content-Type: application/json" \
        -d '{"email": "admin@sso-testing.com", "password": "admin123", "client_id": "string", "redirect_uri": "string"}' \
        2>/dev/null || echo "ERROR")
    
    if echo "$test_response" | grep -q "Login SSO berhasil"; then
        echo "✅ SSO endpoint working!"
    elif echo "$test_response" | grep -q "no Route matched"; then
        echo "❌ Still getting 'no Route matched'"
        echo "Response: $test_response"
        
        # Debug
        echo ""
        echo "🔍 Debug info:"
        echo "1. Kong version:"
        docker exec kong-gateway kong version 2>/dev/null || echo "Unknown"
        echo "2. Config file:"
        docker exec kong-gateway ls -la /kong/kong.yml 2>/dev/null || echo "Not found"
        echo "3. Kong config:"
        docker exec kong-gateway kong config -c /kong/kong.yml 2>/dev/null || echo "Config error"
        
        exit 1
    else
        echo "⚠️  Unexpected response: $test_response"
    fi
    
else
    echo "❌ Kong failed to start"
    echo "📋 Docker logs:"
    docker-compose -f docker-compose.server.yml logs kong
    exit 1
fi

echo ""
echo "🎉 Kong Server is ready!"
echo "📍 SSO: http://localhost:9545/api/auth/sso/login"
