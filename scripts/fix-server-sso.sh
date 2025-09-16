#!/bin/bash

# Fix Server SSO Issues
# Script untuk memperbaiki masalah SSO di server

set -e

echo "🔧 Fixing Server SSO Issues..."
echo "=============================="

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

# Function to restart Kong
restart_kong() {
    print_status "Restarting Kong..."
    
    # Stop Kong
    docker-compose -f docker-compose.server.yml down kong
    
    # Wait
    sleep 3
    
    # Start Kong
    docker-compose -f docker-compose.server.yml up -d kong
    
    # Wait for Kong to be ready
    print_status "Waiting for Kong to be ready..."
    sleep 10
    
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

# Function to restart Nginx
restart_nginx() {
    print_status "Restarting Nginx..."
    
    # Test config first
    if sudo nginx -t; then
        print_success "Nginx config is valid"
        
        # Restart Nginx
        sudo systemctl restart nginx
        
        # Check status
        if systemctl is-active --quiet nginx; then
            print_success "Nginx restarted successfully"
            return 0
        else
            print_error "Nginx failed to start"
            return 1
        fi
    else
        print_error "Nginx config has errors"
        return 1
    fi
}

# Function to deploy Kong config
deploy_kong_config() {
    print_status "Deploying Kong configuration..."
    
    if [[ ! -f "config/kong.yml" ]]; then
        print_error "config/kong.yml not found"
        return 1
    fi
    
    # Deploy using Kong Admin API
    local response=$(curl -s -X POST http://localhost:9546/config \
        -H "Content-Type: application/json" \
        -d @"config/kong.yml" 2>/dev/null || echo "ERROR")
    
    if [[ "$response" == "ERROR" ]]; then
        print_warning "Direct config deployment failed, restarting Kong instead..."
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

# Main execution
main() {
    echo "🚀 Starting Server SSO Fix..."
    echo "============================="
    
    # Step 1: Check if Kong is running
    if ! docker ps | grep -q kong-gateway; then
        print_error "Kong container is not running"
        print_status "Starting Kong..."
        docker-compose -f docker-compose.server.yml up -d kong
        sleep 10
    fi
    
    # Step 2: Check Kong health
    if ! curl -s http://localhost:9546/status > /dev/null 2>&1; then
        print_error "Kong is not healthy, restarting..."
        restart_kong
    fi
    
    # Step 3: Check routes
    local routes_count=$(curl -s http://localhost:9546/routes | jq '.data | length' 2>/dev/null || echo "0")
    if [[ "$routes_count" -eq 0 ]]; then
        print_error "No routes found, deploying configuration..."
        deploy_kong_config
    else
        print_success "Found $routes_count routes"
    fi
    
    # Step 4: Test SSO endpoint
    if test_sso_endpoint; then
        print_success "✅ SSO endpoint is working correctly!"
        echo ""
        echo "🎉 You can now access SSO at:"
        echo "   https://services.motorsights.com/api/auth/sso/login"
        echo ""
        echo "📋 Test command:"
        echo "curl --location 'https://services.motorsights.com/api/auth/sso/login' \\"
        echo "  --header 'Content-Type: application/json' \\"
        echo "  --data-raw '{\"email\": \"admin@sso-testing.com\", \"password\": \"admin123\", \"client_id\": \"string\", \"redirect_uri\": \"string\"}'"
    else
        print_error "❌ SSO endpoint still not working"
        echo ""
        echo "📋 Troubleshooting steps:"
        echo "1. Check Kong logs: docker logs kong-gateway"
        echo "2. Check Nginx logs: sudo tail -f /var/log/nginx/error.log"
        echo "3. Verify Kong config: cat config/kong.yml"
        echo "4. Test Kong directly: curl -X POST http://localhost:9545/api/auth/sso/login"
        echo "5. Test Nginx proxy: curl -X POST https://localhost/api/auth/sso/login -k"
        
        # Try restarting Nginx
        print_status "Trying to restart Nginx..."
        if restart_nginx; then
            print_status "Testing SSO endpoint again..."
            if test_sso_endpoint; then
                print_success "✅ SSO endpoint is now working after Nginx restart!"
            else
                print_error "❌ Still not working after Nginx restart"
            fi
        fi
    fi
}

# Run main function
main "$@"
