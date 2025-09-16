#!/bin/bash

# Deploy Kong Configuration to Server
# Script untuk deploy konfigurasi Kong ke server

set -e

echo "🚀 Deploying Kong Configuration to Server..."
echo "============================================="

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

# Function to deploy Kong config
deploy_kong_config() {
    print_status "Deploying Kong configuration..."
    
    if [[ ! -f "config/kong.yml" ]]; then
        print_error "config/kong.yml not found"
        return 1
    fi
    
    # Deploy using Kong Admin API
    print_status "Sending configuration to Kong Admin API..."
    local response=$(curl -s -X POST http://localhost:9546/config \
        -H "Content-Type: application/json" \
        -d @"config/kong.yml" 2>/dev/null || echo "ERROR")
    
    if [[ "$response" == "ERROR" ]]; then
        print_error "Failed to deploy configuration via Admin API"
        return 1
    fi
    
    # Check if deployment was successful
    if echo "$response" | grep -q "success"; then
        print_success "Configuration deployed successfully"
        return 0
    else
        print_warning "Deployment response: $response"
        return 1
    fi
}

# Function to verify routes
verify_routes() {
    print_status "Verifying routes deployment..."
    
    local routes_response=$(curl -s http://localhost:9546/routes 2>/dev/null || echo "ERROR")
    
    if [[ "$routes_response" == "ERROR" ]]; then
        print_error "Cannot access Kong routes"
        return 1
    fi
    
    local route_count=$(echo "$routes_response" | jq '.data | length' 2>/dev/null || echo "0")
    
    if [[ "$route_count" -gt 0 ]]; then
        print_success "Found $route_count routes"
        echo "$routes_response" | jq '.data[] | {name: .name, paths: .paths, methods: .methods}' 2>/dev/null || true
        return 0
    else
        print_error "No routes found after deployment"
        return 1
    fi
}

# Function to test SSO endpoint
test_sso_endpoint() {
    print_status "Testing SSO endpoint..."
    
    # Test Kong directly
    local kong_response=$(curl -s -X POST http://localhost:9545/api/auth/sso/login \
        -H "Content-Type: application/json" \
        -d '{"email": "admin@sso-testing.com", "password": "admin123", "client_id": "string", "redirect_uri": "string"}' \
        2>/dev/null || echo "ERROR")
    
    if [[ "$kong_response" == "ERROR" ]]; then
        print_error "Kong direct test failed"
        return 1
    fi
    
    if echo "$kong_response" | grep -q "Login SSO berhasil"; then
        print_success "Kong SSO endpoint works"
        
        # Test through Nginx
        local nginx_response=$(curl -s -X POST https://localhost/api/auth/sso/login \
            -H "Content-Type: application/json" \
            -d '{"email": "admin@sso-testing.com", "password": "admin123", "client_id": "string", "redirect_uri": "string"}' \
            -k 2>/dev/null || echo "ERROR")
        
        if [[ "$nginx_response" == "ERROR" ]]; then
            print_error "Nginx proxy test failed"
            return 1
        fi
        
        if echo "$nginx_response" | grep -q "Login SSO berhasil"; then
            print_success "Nginx proxy works correctly"
            return 0
        else
            print_error "Nginx proxy response: $(echo "$nginx_response" | head -c 100)..."
            return 1
        fi
    else
        print_error "Kong SSO response: $(echo "$kong_response" | head -c 100)..."
        return 1
    fi
}

# Function to restart Kong with config
restart_kong_with_config() {
    print_status "Restarting Kong with configuration file..."
    
    # Stop Kong
    docker-compose -f docker-compose.server.yml down kong
    
    # Wait
    sleep 3
    
    # Start Kong
    docker-compose -f docker-compose.server.yml up -d kong
    
    # Wait for Kong to be ready
    print_status "Waiting for Kong to be ready..."
    sleep 15
    
    # Check health
    local attempts=0
    local max_attempts=30
    
    while [[ $attempts -lt $max_attempts ]]; do
        if curl -s http://localhost:9546/status > /dev/null 2>&1; then
            print_success "Kong is healthy"
            return 0
        fi
        
        print_status "Waiting for Kong health check... (attempt $((attempts + 1))/$max_attempts)"
        sleep 2
        ((attempts++))
    done
    
    print_error "Kong failed to become healthy"
    return 1
}

# Main execution
main() {
    echo "🚀 Starting Kong Configuration Deployment..."
    echo "==========================================="
    
    # Step 1: Check Kong status
    if ! docker ps | grep -q kong-gateway; then
        print_error "Kong container is not running"
        exit 1
    fi
    
    # Step 2: Check Kong health
    if ! curl -s http://localhost:9546/status > /dev/null 2>&1; then
        print_error "Kong is not healthy"
        exit 1
    fi
    
    # Step 3: Try to deploy configuration
    if deploy_kong_config; then
        print_success "Configuration deployed via Admin API"
    else
        print_warning "Admin API deployment failed, trying restart method..."
        
        # Try restarting Kong with config file
        if restart_kong_with_config; then
            print_success "Kong restarted with configuration file"
        else
            print_error "Failed to restart Kong with configuration"
            exit 1
        fi
    fi
    
    # Step 4: Verify routes
    if ! verify_routes; then
        print_error "Routes verification failed"
        exit 1
    fi
    
    # Step 5: Test SSO endpoint
    if test_sso_endpoint; then
        print_success "✅ Kong configuration deployed successfully!"
        echo ""
        echo "🎉 SSO endpoint is now working at:"
        echo "   https://services.motorsights.com/api/auth/sso/login"
        echo ""
        echo "📋 Test command:"
        echo "curl --location 'https://services.motorsights.com/api/auth/sso/login' \\"
        echo "  --header 'Content-Type: application/json' \\"
        echo "  --data-raw '{\"email\": \"admin@sso-testing.com\", \"password\": \"admin123\", \"client_id\": \"string\", \"redirect_uri\": \"string\"}'"
    else
        print_error "❌ SSO endpoint still not working after deployment"
        echo ""
        echo "📋 Troubleshooting steps:"
        echo "1. Check Kong logs: docker logs kong-gateway"
        echo "2. Check Kong config: cat config/kong.yml"
        echo "3. Verify routes: curl -s http://localhost:9546/routes | jq '.data[]'"
        echo "4. Test Kong directly: curl -X POST http://localhost:9545/api/auth/sso/login"
        exit 1
    fi
}

# Run main function
main "$@"
