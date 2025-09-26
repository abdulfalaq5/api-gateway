#!/bin/bash

# Manual Kong Routes Creation
# Script untuk membuat routes Kong secara manual

set -e

echo "🔧 Manual Kong Routes Creation"
echo "==============================="

# Server details
SERVER_IP="162.11.0.232"
SERVER_USER="msiserver"
SERVER_PASS="m0t0r519ht5!@#"
SERVER_DIR="/home/msiserver/MSI/api-gateway"

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

# Function to execute command on remote server
execute_remote() {
    local command="$1"
    print_status "Executing: $command"
    
    sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "cd $SERVER_DIR && $command"
}

# Function to create SSO service
create_sso_service() {
    print_status "Creating SSO service..."
    
    local service_json='{
        "name": "sso-service",
        "url": "https://api-gate.motorsights.com",
        "connect_timeout": 60000,
        "write_timeout": 60000,
        "read_timeout": 60000
    }'
    
    execute_remote "curl -X POST http://localhost:9546/services -H 'Content-Type: application/json' -d '$service_json'"
}

# Function to create SSO login route
create_sso_login_route() {
    print_status "Creating SSO login route..."
    
    local route_json='{
        "name": "sso-login-routes",
        "paths": ["/api/auth/sso/login"],
        "methods": ["POST", "OPTIONS"],
        "strip_path": false,
        "service": {"name": "sso-service"}
    }'
    
    execute_remote "curl -X POST http://localhost:9546/routes -H 'Content-Type: application/json' -d '$route_json'"
}

# Function to create SSO userinfo route
create_sso_userinfo_route() {
    print_status "Creating SSO userinfo route..."
    
    local route_json='{
        "name": "sso-userinfo-routes",
        "paths": ["/api/auth/sso/userinfo"],
        "methods": ["GET", "OPTIONS"],
        "strip_path": true,
        "service": {"name": "sso-service"}
    }'
    
    execute_remote "curl -X POST http://localhost:9546/routes -H 'Content-Type: application/json' -d '$route_json'"
}

# Function to create SSO menus route
create_sso_menus_route() {
    print_status "Creating SSO menus route..."
    
    local route_json='{
        "name": "sso-menus-routes",
        "paths": ["/api/menus"],
        "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        "strip_path": true,
        "service": {"name": "sso-service"}
    }'
    
    execute_remote "curl -X POST http://localhost:9546/routes -H 'Content-Type: application/json' -d '$route_json'"
}

# Function to add CORS plugin
add_cors_plugin() {
    print_status "Adding CORS plugin..."
    
    local plugin_json='{
        "name": "cors",
        "config": {
            "origins": ["*"],
            "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
            "headers": ["Accept", "Accept-Version", "Content-Length", "Content-MD5", "Content-Type", "Date", "Authorization", "X-Auth-Token"],
            "exposed_headers": ["X-Auth-Token", "Authorization"],
            "credentials": true,
            "max_age": 3600,
            "preflight_continue": false
        }
    }'
    
    execute_remote "curl -X POST http://localhost:9546/plugins -H 'Content-Type: application/json' -d '$plugin_json'"
}

# Function to add rate limiting plugin to SSO service
add_rate_limiting_plugin() {
    print_status "Adding rate limiting plugin to SSO service..."
    
    local plugin_json='{
        "name": "rate-limiting",
        "config": {
            "minute": 100,
            "hour": 1000,
            "policy": "local"
        },
        "service": {"name": "sso-service"}
    }'
    
    execute_remote "curl -X POST http://localhost:9546/plugins -H 'Content-Type: application/json' -d '$plugin_json'"
}

# Main execution
main() {
    echo "🚀 Starting Manual Kong Routes Creation..."
    echo "=========================================="
    
    # Step 1: Check Kong status
    print_status "Step 1: Checking Kong status..."
    execute_remote "docker ps | grep kong-gateway"
    
    # Step 2: Check Kong health
    print_status "Step 2: Checking Kong health..."
    execute_remote "curl -s http://localhost:9546/status | jq '.server'"
    
    # Step 3: Create SSO service
    create_sso_service
    
    # Step 4: Create SSO routes
    create_sso_login_route
    create_sso_userinfo_route
    create_sso_menus_route
    
    # Step 5: Add plugins
    add_cors_plugin
    add_rate_limiting_plugin
    
    # Step 6: Verify routes
    print_status "Step 6: Verifying routes..."
    execute_remote "curl -s http://localhost:9546/routes | jq '.data | length'"
    
    # Step 7: Show routes
    print_status "Step 7: Showing routes..."
    execute_remote "curl -s http://localhost:9546/routes | jq '.data[] | {name: .name, paths: .paths, methods: .methods}'"
    
    # Step 8: Test SSO endpoint
    print_status "Step 8: Testing SSO endpoint..."
    execute_remote "curl -s -X POST http://localhost:9545/api/auth/sso/login -H 'Content-Type: application/json' -d '{\"email\": \"admin@sso-testing.com\", \"password\": \"admin123\", \"client_id\": \"string\", \"redirect_uri\": \"string\"}' | head -c 200"
    
    # Step 9: Test through Nginx
    print_status "Step 9: Testing through Nginx..."
    execute_remote "curl -s -X POST https://localhost/api/auth/sso/login -H 'Content-Type: application/json' -d '{\"email\": \"admin@sso-testing.com\", \"password\": \"admin123\", \"client_id\": \"string\", \"redirect_uri\": \"string\"}' -k | head -c 200"
    
    print_success "✅ Manual Kong routes creation completed!"
    echo ""
    echo "🎉 Test the endpoint:"
    echo "curl --location 'https://services.motorsights.com/api/auth/sso/login' \\"
    echo "  --header 'Content-Type: application/json' \\"
    echo "  --data-raw '{\"email\": \"admin@sso-testing.com\", \"password\": \"admin123\", \"client_id\": \"string\", \"redirect_uri\": \"string\"}'"
}

# Run main function
main "$@"
