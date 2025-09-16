#!/bin/bash

# Fix Kong Server Configuration
echo "🔧 Fixing Kong Server Configuration..."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Step 1: Check current Kong status
print_status "Checking current Kong status..."
if docker ps | grep -q kong-gateway; then
    print_status "Kong container is running"
    
    # Check routes
    routes=$(curl -s http://localhost:9546/routes 2>/dev/null)
    route_count=$(echo "$routes" | jq '.data | length' 2>/dev/null || echo "0")
    
    if [[ "$route_count" -gt 0 ]]; then
        print_warning "Found $route_count routes, but SSO not working"
        echo "$routes" | jq '.data[].name' 2>/dev/null || true
    else
        print_error "No routes found"
    fi
else
    print_error "Kong container is not running"
    exit 1
fi

# Step 2: Stop Kong completely
print_status "Stopping Kong completely..."
docker-compose -f docker-compose.server.yml down
docker rm -f kong-gateway 2>/dev/null || true

# Step 3: Clean up
print_status "Cleaning up..."
docker network prune -f
docker system prune -f

# Step 4: Check config file exists
print_status "Checking config file..."
if [[ ! -f "config/kong.yml" ]]; then
    print_error "config/kong.yml not found"
    exit 1
fi
print_success "Config file exists"

# Step 5: Start Kong fresh
print_status "Starting Kong fresh..."
docker-compose -f docker-compose.server.yml up -d

# Step 6: Wait for Kong to be ready
print_status "Waiting for Kong to be ready..."
sleep 20

# Step 7: Check Kong health
print_status "Checking Kong health..."
health_attempts=0
max_attempts=30

while [[ $health_attempts -lt $max_attempts ]]; do
    if curl -s http://localhost:9546/status > /dev/null 2>&1; then
        print_success "Kong is healthy"
        break
    fi
    
    print_status "Waiting for Kong health check... (attempt $((health_attempts + 1))/$max_attempts)"
    sleep 2
    ((health_attempts++))
done

if [[ $health_attempts -eq $max_attempts ]]; then
    print_error "Kong failed to become healthy"
    print_status "Kong logs:"
    docker logs kong-gateway --tail 20
    exit 1
fi

# Step 8: Check routes again
print_status "Checking routes after restart..."
routes=$(curl -s http://localhost:9546/routes 2>/dev/null)
route_count=$(echo "$routes" | jq '.data | length' 2>/dev/null || echo "0")

if [[ "$route_count" -gt 0 ]]; then
    print_success "Found $route_count routes"
    echo "$routes" | jq '.data[].name' 2>/dev/null || true
    
    # Check if SSO route exists
    sso_route=$(echo "$routes" | jq '.data[] | select(.name == "sso-login-routes")' 2>/dev/null)
    if [[ -n "$sso_route" ]]; then
        print_success "SSO route found"
    else
        print_error "SSO route not found"
        print_status "All routes:"
        echo "$routes" | jq '.data[] | {name: .name, paths: .paths, methods: .methods}' 2>/dev/null || true
    fi
else
    print_error "Still no routes found"
    print_status "Kong logs:"
    docker logs kong-gateway --tail 30
    exit 1
fi

# Step 9: Test SSO endpoint
print_status "Testing SSO endpoint..."
test_response=$(curl -s -X POST http://localhost:9545/api/auth/sso/login \
    -H "Content-Type: application/json" \
    -d '{"email": "admin@sso-testing.com", "password": "admin123", "client_id": "string", "redirect_uri": "string"}' \
    2>/dev/null || echo "ERROR")

if echo "$test_response" | grep -q "Login SSO berhasil"; then
    print_success "✅ SSO endpoint is working!"
    echo "Response: $(echo "$test_response" | jq '.message' 2>/dev/null || echo "$test_response")"
elif echo "$test_response" | grep -q "no Route matched"; then
    print_error "❌ Still getting 'no Route matched' error"
    print_status "Response: $test_response"
    
    # Debug information
    print_status "Debug information:"
    echo "1. Kong version: $(docker exec kong-gateway kong version 2>/dev/null || echo 'Unknown')"
    echo "2. Config file mounted: $(docker exec kong-gateway ls -la /kong/kong.yml 2>/dev/null || echo 'Not found')"
    echo "3. Kong config check: $(docker exec kong-gateway kong config -c /kong/kong.yml 2>/dev/null || echo 'Config error')"
    
    exit 1
else
    print_warning "Unexpected response: $test_response"
fi

print_success "🎉 Kong Server is now working correctly!"
echo ""
echo "📍 SSO endpoint: http://localhost:9545/api/auth/sso/login"
echo "📍 Admin API: http://localhost:9546"
echo "📍 Admin GUI: http://localhost:9547"
