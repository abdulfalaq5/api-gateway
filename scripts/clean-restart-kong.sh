#!/bin/bash

# Clean Restart Kong Server
echo "🧹 Cleaning and restarting Kong Server..."

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

# Step 1: Stop all Kong containers
print_status "Stopping all Kong containers..."
docker-compose -f docker-compose.server.yml down 2>/dev/null || true
docker-compose -f docker-compose.yml down 2>/dev/null || true

# Step 2: Remove Kong containers
print_status "Removing Kong containers..."
docker rm -f kong-gateway kong-migrations 2>/dev/null || true

# Step 3: Clean up networks
print_status "Cleaning up Docker networks..."
docker network prune -f

# Step 4: Remove orphaned networks
print_status "Removing orphaned networks..."
docker network ls --format "{{.Name}}" | grep -E "(kong|api-gateway)" | xargs -r docker network rm 2>/dev/null || true

# Step 5: Clean up volumes (optional)
print_status "Cleaning up unused volumes..."
docker volume prune -f

# Step 6: Pull latest Kong image
print_status "Pulling Kong image..."
docker pull kong:3.4

# Step 7: Create fresh network
print_status "Creating fresh Docker network..."
docker network create kong-network 2>/dev/null || true

# Step 8: Start Kong with clean state
print_status "Starting Kong with clean configuration..."

# Use the server configuration but modify it to avoid network issues
docker-compose -f docker-compose.server.yml up -d kong --no-deps

# Wait for Kong to be ready
print_status "Waiting for Kong to be ready..."
sleep 15

# Step 9: Check Kong health
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

# Step 10: Check routes
print_status "Checking Kong routes..."
routes=$(curl -s http://localhost:9546/routes 2>/dev/null)
route_count=$(echo "$routes" | jq '.data | length' 2>/dev/null || echo "0")

if [[ "$route_count" -gt 0 ]]; then
    print_success "Found $route_count routes"
    echo "$routes" | jq '.data[].name' 2>/dev/null || true
else
    print_warning "No routes found - this is expected for fresh start"
fi

# Step 11: Test basic connectivity
print_status "Testing basic Kong connectivity..."
if curl -s http://localhost:9545/ > /dev/null 2>&1; then
    print_success "Kong proxy is responding"
else
    print_error "Kong proxy is not responding"
    exit 1
fi

print_success "✅ Kong Server has been cleaned and restarted successfully!"
echo ""
echo "🎯 Next steps:"
echo "   1. Deploy your configuration: ./scripts/deploy-kong-config.sh"
echo "   2. Test SSO endpoint: curl -X POST http://localhost:9545/api/auth/sso/login"
echo ""
echo "📍 Kong is now running on:"
echo "   - Proxy: http://localhost:9545"
echo "   - Admin API: http://localhost:9546"
echo "   - Admin GUI: http://localhost:9547"
