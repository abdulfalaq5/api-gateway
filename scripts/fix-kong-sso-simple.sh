#!/bin/bash

# Simple Kong SSO Fix Script
echo "🔧 Kong SSO Fix Script..."

# Check if we're in the right directory
if [ ! -f "config/kong.yml" ]; then
    echo "❌ Error: config/kong.yml not found. Please run this script from the project root directory."
    exit 1
fi

# Check current configuration
echo "🔍 Checking current configuration..."
if grep -A 5 "sso-login-routes" config/kong.yml | grep -q "strip_path: false"; then
    echo "✅ Configuration already correct (strip_path: false)"
else
    echo "🔧 Fixing strip_path configuration..."
    # Create backup
    cp config/kong.yml config/kong.yml.backup.$(date +%Y%m%d_%H%M%S)
    
    # Fix the configuration
    sed -i 's/strip_path: true/strip_path: false/g' config/kong.yml
    echo "✅ Configuration updated successfully"
fi

# Stop Kong
echo "🛑 Stopping Kong..."
docker-compose -f docker-compose.server.yml down

# Clean up networks
echo "🧹 Cleaning up networks..."
docker network prune -f

# Start Kong
echo "🚀 Starting Kong..."
docker-compose -f docker-compose.server.yml up -d

# Wait for Kong to start
echo "⏳ Waiting for Kong to start..."
sleep 20

# Check Kong status
echo "📋 Checking Kong status..."
if docker ps | grep -q kong-gateway; then
    echo "✅ Kong is running"
else
    echo "❌ Kong failed to start"
    exit 1
fi

# Test SSO endpoint
echo "🧪 Testing SSO endpoint..."
test_response=$(curl -s -X POST http://localhost:9545/api/auth/sso/login \
    -H "Content-Type: application/json" \
    -d '{"email": "admin@sso-testing.com", "password": "admin123", "client_id": "string", "redirect_uri": "string"}' \
    2>/dev/null)

if echo "$test_response" | grep -q "Login SSO berhasil"; then
    echo "✅ SSO endpoint working correctly!"
    echo "🎉 Kong SSO configuration fixed successfully!"
else
    echo "❌ SSO endpoint still not working"
    echo "Response: $test_response"
    exit 1
fi

echo ""
echo "🎉 Kong SSO configuration is working!"
echo "📍 Available endpoints:"
echo "   - SSO Login: http://localhost:9545/api/auth/sso/login"
echo "   - SSO User Info: http://localhost:9545/api/auth/sso/userinfo"
echo "   - SSO Menus: http://localhost:9545/api/menus"
echo "   - Example Service: http://localhost:9545/api/v1/example"
