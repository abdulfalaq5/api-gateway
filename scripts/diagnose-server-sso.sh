#!/bin/bash

# Diagnose Server SSO Issues
# Script untuk mendiagnosis masalah SSO di server

set -e

echo "🔍 Diagnosing Server SSO Issues..."
echo "=================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Step 1: Check Kong container status
print_status "1. Checking Kong container status..."
if docker ps | grep -q kong-gateway; then
    print_success "Kong container is running"
    docker ps | grep kong-gateway
else
    print_error "Kong container is not running"
    echo "Available containers:"
    docker ps
fi

# Step 2: Check Kong health
print_status "2. Checking Kong health..."
kong_health=$(curl -s http://localhost:9546/status 2>/dev/null || echo "ERROR")
if [[ "$kong_health" == "ERROR" ]]; then
    print_error "Cannot access Kong Admin API"
else
    print_success "Kong is healthy"
    echo "$kong_health" | jq '.' 2>/dev/null || echo "$kong_health"
fi

# Step 3: Check Kong routes
print_status "3. Checking Kong routes..."
routes_response=$(curl -s http://localhost:9546/routes 2>/dev/null || echo "ERROR")
if [[ "$routes_response" == "ERROR" ]]; then
    print_error "Cannot access Kong routes"
else
    route_count=$(echo "$routes_response" | jq '.data | length' 2>/dev/null || echo "0")
    print_success "Found $route_count routes"
    
    # Show SSO routes specifically
    echo "$routes_response" | jq '.data[] | select(.name | contains("sso")) | {name: .name, paths: .paths, methods: .methods}' 2>/dev/null || true
fi

# Step 4: Test Kong directly (port 9545)
print_status "4. Testing Kong directly on port 9545..."
kong_direct=$(curl -s -X POST http://localhost:9545/api/auth/sso/login \
    -H "Content-Type: application/json" \
    -d '{"email": "admin@sso-testing.com", "password": "admin123", "client_id": "string", "redirect_uri": "string"}' \
    2>/dev/null || echo "ERROR")

if [[ "$kong_direct" == "ERROR" ]]; then
    print_error "Cannot access Kong on port 9545"
else
    if echo "$kong_direct" | grep -q "Login SSO berhasil"; then
        print_success "Kong SSO endpoint works on port 9545"
    else
        print_warning "Kong SSO response: $(echo "$kong_direct" | head -c 100)..."
    fi
fi

# Step 5: Test through Nginx (port 443)
print_status "5. Testing through Nginx (HTTPS)..."
nginx_test=$(curl -s -X POST https://localhost/api/auth/sso/login \
    -H "Content-Type: application/json" \
    -d '{"email": "admin@sso-testing.com", "password": "admin123", "client_id": "string", "redirect_uri": "string"}' \
    -k 2>/dev/null || echo "ERROR")

if [[ "$nginx_test" == "ERROR" ]]; then
    print_error "Cannot access through Nginx"
else
    if echo "$nginx_test" | grep -q "Login SSO berhasil"; then
        print_success "Nginx proxy works correctly"
    elif echo "$nginx_test" | grep -q "no Route matched"; then
        print_error "Nginx proxy: No route matched"
    else
        print_warning "Nginx response: $(echo "$nginx_test" | head -c 100)..."
    fi
fi

# Step 6: Check Nginx status
print_status "6. Checking Nginx status..."
if systemctl is-active --quiet nginx; then
    print_success "Nginx is running"
else
    print_error "Nginx is not running"
fi

# Step 7: Check Nginx configuration
print_status "7. Checking Nginx configuration..."
if [[ -f "/etc/nginx/sites-available/services.motorsights.com" ]]; then
    print_success "Nginx config file exists"
    
    # Check if config is enabled
    if [[ -L "/etc/nginx/sites-enabled/services.motorsights.com" ]]; then
        print_success "Nginx config is enabled"
    else
        print_error "Nginx config is not enabled"
        echo "Run: sudo ln -s /etc/nginx/sites-available/services.motorsights.com /etc/nginx/sites-enabled/"
    fi
    
    # Test nginx config
    if sudo nginx -t 2>/dev/null; then
        print_success "Nginx configuration is valid"
    else
        print_error "Nginx configuration has errors"
        sudo nginx -t
    fi
else
    print_error "Nginx config file not found"
fi

# Step 8: Check Kong logs
print_status "8. Checking Kong logs (last 20 lines)..."
echo "--- Kong Error Logs ---"
docker logs kong-gateway --tail 20 2>&1 | grep -i error || echo "No errors in Kong logs"

echo ""
echo "--- Kong Access Logs ---"
docker logs kong-gateway --tail 10 2>&1 | grep -i "api/auth/sso" || echo "No SSO requests in Kong logs"

# Step 9: Check Nginx logs
print_status "9. Checking Nginx logs..."
echo "--- Nginx Error Logs ---"
sudo tail -10 /var/log/nginx/error.log 2>/dev/null || echo "Cannot access Nginx error logs"

echo ""
echo "--- Nginx Access Logs ---"
sudo tail -5 /var/log/nginx/access.log 2>/dev/null || echo "Cannot access Nginx access logs"

# Step 10: Network connectivity test
print_status "10. Testing network connectivity..."
if nc -z localhost 9545; then
    print_success "Port 9545 is accessible"
else
    print_error "Port 9545 is not accessible"
fi

if nc -z localhost 443; then
    print_success "Port 443 is accessible"
else
    print_error "Port 443 is not accessible"
fi

echo ""
echo "🎯 DIAGNOSIS SUMMARY:"
echo "===================="
echo "1. Kong container: $(docker ps | grep -q kong-gateway && echo "✅ Running" || echo "❌ Not running")"
echo "2. Kong health: $(curl -s http://localhost:9546/status >/dev/null 2>&1 && echo "✅ Healthy" || echo "❌ Unhealthy")"
echo "3. Kong routes: $(curl -s http://localhost:9546/routes | jq '.data | length' 2>/dev/null || echo "❌ Error") routes found"
echo "4. Kong direct (9545): $(curl -s -X POST http://localhost:9545/api/auth/sso/login -H "Content-Type: application/json" -d '{"email":"test"}' | grep -q "Login SSO berhasil" && echo "✅ Working" || echo "❌ Not working")"
echo "5. Nginx status: $(systemctl is-active --quiet nginx && echo "✅ Running" || echo "❌ Not running")"
echo "6. Nginx config: $(sudo nginx -t >/dev/null 2>&1 && echo "✅ Valid" || echo "❌ Invalid")"

echo ""
echo "📋 NEXT STEPS:"
echo "=============="
echo "If Kong direct works but Nginx doesn't:"
echo "1. Restart Nginx: sudo systemctl restart nginx"
echo "2. Check Nginx config: sudo nginx -t"
echo "3. Reload Nginx: sudo nginx -s reload"
echo ""
echo "If Kong direct doesn't work:"
echo "1. Restart Kong: docker-compose -f docker-compose.server.yml restart kong"
echo "2. Check Kong config: cat config/kong.yml"
echo "3. Deploy config: curl -X POST http://localhost:9546/config -H 'Content-Type: application/json' -d @config/kong.yml"
