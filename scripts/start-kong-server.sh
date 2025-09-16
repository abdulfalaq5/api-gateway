#!/bin/bash

# Start Kong Server - Simple and Correct Way
echo "🚀 Starting Kong Server..."

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Step 1: Clean up existing containers
print_status "Cleaning up existing containers..."
docker-compose -f docker-compose.server.yml down 2>/dev/null || true
docker rm -f kong-gateway kong-migrations 2>/dev/null || true

# Step 2: Clean networks
print_status "Cleaning Docker networks..."
docker network prune -f

# Step 3: Start Kong with server configuration
print_status "Starting Kong with server configuration..."
docker-compose -f docker-compose.server.yml up -d kong

# Step 4: Wait for Kong to start
print_status "Waiting for Kong to start..."
sleep 20

# Step 5: Check if Kong is running
print_status "Checking Kong status..."
if docker ps | grep -q kong-gateway; then
    print_success "Kong container is running"
    
    # Check Kong health
    print_status "Checking Kong health..."
    health_attempts=0
    max_attempts=30
    
    while [[ $health_attempts -lt $max_attempts ]]; do
        if curl -s http://localhost:9546/status > /dev/null 2>&1; then
            print_success "Kong is healthy and responding"
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
    
    # Step 6: Check routes
    print_status "Checking Kong routes..."
    routes=$(curl -s http://localhost:9546/routes 2>/dev/null)
    route_count=$(echo "$routes" | jq '.data | length' 2>/dev/null || echo "0")
    
    if [[ "$route_count" -gt 0 ]]; then
        print_success "Found $route_count routes"
        echo "$routes" | jq '.data[].name' 2>/dev/null || true
    else
        print_warning "No routes found - this is normal for fresh start"
    fi
    
    # Step 7: Test basic connectivity
    print_status "Testing Kong proxy..."
    if curl -s http://localhost:9545/ > /dev/null 2>&1; then
        print_success "Kong proxy is responding"
    else
        print_warning "Kong proxy test failed"
    fi
    
    echo ""
    print_success "✅ Kong Server is now running!"
    echo ""
    echo "📍 Kong Endpoints:"
    echo "   - Proxy: http://localhost:9545"
    echo "   - Admin API: http://localhost:9546"
    echo "   - Admin GUI: http://localhost:9547"
    echo ""
    echo "🧪 Test SSO endpoint:"
    echo "   curl -X POST http://localhost:9545/api/auth/sso/login \\"
    echo "     -H \"Content-Type: application/json\" \\"
    echo "     -d '{\"email\": \"admin@sso-testing.com\", \"password\": \"admin123\", \"client_id\": \"string\", \"redirect_uri\": \"string\"}'"
    
else
    print_error "Kong container failed to start"
    print_status "Docker Compose logs:"
    docker-compose -f docker-compose.server.yml logs kong
    exit 1
fi