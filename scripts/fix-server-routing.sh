#!/bin/bash

# Fix Kong Server Routing Issues
# Script untuk memperbaiki masalah routing di server

set -e

echo "🔧 Memperbaiki Kong Server Routing Issues..."

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

# Check if running on server
if [[ "$(hostname)" == *"server"* ]] || [[ "$(whoami)" == "msiserver" ]]; then
    print_status "Detected server environment"
    SERVER_MODE=true
else
    print_status "Detected local environment"
    SERVER_MODE=false
fi

# Function to check Kong status
check_kong_status() {
    print_status "Checking Kong status..."
    
    if docker ps | grep -q kong-gateway; then
        print_success "Kong container is running"
        return 0
    else
        print_error "Kong container is not running"
        return 1
    fi
}

# Function to check routes
check_routes() {
    print_status "Checking Kong routes..."
    
    local routes_response=$(curl -s http://localhost:9546/routes 2>/dev/null || echo "ERROR")
    
    if [[ "$routes_response" == "ERROR" ]]; then
        print_error "Cannot access Kong Admin API"
        return 1
    fi
    
    local route_count=$(echo "$routes_response" | jq '.data | length' 2>/dev/null || echo "0")
    
    if [[ "$route_count" -gt 0 ]]; then
        print_success "Found $route_count routes"
        echo "$routes_response" | jq '.data[].name' 2>/dev/null || true
        return 0
    else
        print_error "No routes found"
        return 1
    fi
}

# Function to restart Kong with correct config
restart_kong() {
    print_status "Restarting Kong with correct configuration..."
    
    # Stop Kong
    print_status "Stopping Kong..."
    docker-compose -f docker-compose.server.yml down kong
    
    # Wait a bit
    sleep 3
    
    # Start Kong
    print_status "Starting Kong..."
    docker-compose -f docker-compose.server.yml up -d kong
    
    # Wait for Kong to be ready
    print_status "Waiting for Kong to be ready..."
    sleep 10
    
    # Check health
    local health_attempts=0
    local max_attempts=30
    
    while [[ $health_attempts -lt $max_attempts ]]; do
        if curl -s http://localhost:9546/status > /dev/null 2>&1; then
            print_success "Kong is healthy"
            return 0
        fi
        
        print_status "Waiting for Kong health check... (attempt $((health_attempts + 1))/$max_attempts)"
        sleep 2
        ((health_attempts++))
    done
    
    print_error "Kong failed to become healthy"
    return 1
}

# Function to deploy config to Kong
deploy_config() {
    print_status "Deploying configuration to Kong..."
    
    # Check if we have kong.yml
    if [[ ! -f "config/kong.yml" ]]; then
        print_error "config/kong.yml not found"
        return 1
    fi
    
    # Deploy using Kong Admin API
    local config_response=$(curl -s -X POST http://localhost:9546/config \
        -H "Content-Type: application/json" \
        -d @"config/kong.yml" 2>/dev/null || echo "ERROR")
    
    if [[ "$config_response" == "ERROR" ]]; then
        print_warning "Direct config deployment failed, trying alternative method..."
        
        # Alternative: restart with config file
        restart_kong
        return $?
    else
        print_success "Configuration deployed successfully"
        return 0
    fi
}

# Function to test SSO endpoint
test_sso_endpoint() {
    print_status "Testing SSO endpoint..."
    
    local test_response=$(curl -s -X POST http://localhost:9545/api/auth/sso/login \
        -H "Content-Type: application/json" \
        -d '{"email": "admin@sso-testing.com", "password": "admin123", "client_id": "string", "redirect_uri": "string"}' \
        2>/dev/null || echo "ERROR")
    
    if [[ "$test_response" == "ERROR" ]]; then
        print_error "Cannot test SSO endpoint"
        return 1
    fi
    
    if echo "$test_response" | grep -q "Login SSO berhasil"; then
        print_success "SSO endpoint is working correctly"
        return 0
    elif echo "$test_response" | grep -q "no Route matched"; then
        print_error "SSO endpoint: No route matched"
        return 1
    else
        print_warning "SSO endpoint response: $test_response"
        return 1
    fi
}

# Main execution
main() {
    echo "🚀 Starting Kong Server Routing Fix..."
    echo "=================================="
    
    # Step 1: Check Kong status
    if ! check_kong_status; then
        print_error "Kong is not running. Please start Kong first."
        exit 1
    fi
    
    # Step 2: Check routes
    if check_routes; then
        print_success "Routes are already configured"
        
        # Test SSO endpoint
        if test_sso_endpoint; then
            print_success "Everything is working correctly!"
            exit 0
        else
            print_warning "Routes exist but SSO endpoint not working"
        fi
    else
        print_error "No routes found, need to deploy configuration"
    fi
    
    # Step 3: Deploy configuration
    print_status "Deploying configuration..."
    if deploy_config; then
        print_success "Configuration deployed"
    else
        print_error "Failed to deploy configuration"
        exit 1
    fi
    
    # Step 4: Verify routes
    if ! check_routes; then
        print_error "Routes still not found after deployment"
        exit 1
    fi
    
    # Step 5: Test SSO endpoint
    if test_sso_endpoint; then
        print_success "✅ Kong Server routing is now working correctly!"
        echo ""
        echo "🎉 You can now access SSO at:"
        echo "   http://your-server-ip:9545/api/auth/sso/login"
    else
        print_error "❌ SSO endpoint still not working after fix"
        echo ""
        echo "📋 Troubleshooting steps:"
        echo "   1. Check Kong logs: docker logs kong-gateway"
        echo "   2. Verify config file: cat config/kong.yml"
        echo "   3. Check routes: curl http://localhost:9546/routes"
        exit 1
    fi
}

# Run main function
main "$@"
