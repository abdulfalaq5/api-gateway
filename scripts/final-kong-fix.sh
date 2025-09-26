#!/bin/bash

# Final Kong Fix Script
# Script final untuk memperbaiki Kong

set -e

echo "🔧 Final Kong Fix Script"
echo "========================"

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

# Function to check Kong configuration
check_kong_config() {
    print_status "Checking Kong configuration..."
    
    execute_remote "docker exec kong-gateway env | grep -i kong | grep -i database"
    execute_remote "docker exec kong-gateway env | grep -i kong | grep -i declarative"
}

# Function to switch Kong to db-less mode
switch_to_dbless() {
    print_status "Switching Kong to db-less mode..."
    
    # Stop Kong
    execute_remote "docker-compose -f docker-compose.server.yml down kong"
    
    # Wait
    sleep 5
    
    # Update docker-compose to use db-less mode
    execute_remote "sed -i 's/KONG_DATABASE: \"off\"/KONG_DATABASE: \"off\"/' docker-compose.server.yml"
    execute_remote "sed -i 's/KONG_DECLARATIVE_CONFIG: \/kong\/kong.yml/KONG_DECLARATIVE_CONFIG: \/kong\/kong.yml/' docker-compose.server.yml"
    
    # Start Kong
    execute_remote "docker-compose -f docker-compose.server.yml up -d kong"
    
    # Wait for Kong to be ready
    sleep 20
    
    # Check health
    execute_remote "curl -s http://localhost:9546/status | jq '.server'"
}

# Function to test SSO endpoint
test_sso_endpoint() {
    print_status "Testing SSO endpoint..."
    
    # Test Kong directly
    execute_remote "curl -s -X POST http://localhost:9545/api/auth/sso/login -H 'Content-Type: application/json' -d '{\"email\": \"admin@sso-testing.com\", \"password\": \"admin123\", \"client_id\": \"string\", \"redirect_uri\": \"string\"}' | head -c 200"
    
    # Test through Nginx
    execute_remote "curl -s -X POST https://localhost/api/auth/sso/login -H 'Content-Type: application/json' -d '{\"email\": \"admin@sso-testing.com\", \"password\": \"admin123\", \"client_id\": \"string\", \"redirect_uri\": \"string\"}' -k | head -c 200"
}

# Function to test external endpoint
test_external_endpoint() {
    print_status "Testing external SSO endpoint..."
    
    curl -s -X POST "https://services.motorsights.com/api/auth/sso/login" \
        -H "Content-Type: application/json" \
        -d '{"email": "admin@sso-testing.com", "password": "admin123", "client_id": "string", "redirect_uri": "string"}' \
        | head -c 200
}

# Main execution
main() {
    echo "🚀 Starting Final Kong Fix..."
    echo "============================="
    
    # Step 1: Check Kong status
    print_status "Step 1: Checking Kong status..."
    execute_remote "docker ps | grep kong-gateway"
    
    # Step 2: Check Kong configuration
    check_kong_config
    
    # Step 3: Check current routes
    print_status "Step 3: Checking current routes..."
    execute_remote "curl -s http://localhost:9546/routes | jq '.data | length'"
    
    # Step 4: Switch to db-less mode
    switch_to_dbless
    
    # Step 5: Check routes after switch
    print_status "Step 5: Checking routes after switch..."
    execute_remote "curl -s http://localhost:9546/routes | jq '.data | length'"
    
    # Step 6: Show routes
    print_status "Step 6: Showing routes..."
    execute_remote "curl -s http://localhost:9546/routes | jq '.data[] | {name: .name, paths: .paths, methods: .methods}'"
    
    # Step 7: Test SSO endpoint
    test_sso_endpoint
    
    # Step 8: Test external endpoint
    test_external_endpoint
    
    print_success "✅ Final Kong fix completed!"
    echo ""
    echo "🎉 Test the endpoint:"
    echo "curl --location 'https://services.motorsights.com/api/auth/sso/login' \\"
    echo "  --header 'Content-Type: application/json' \\"
    echo "  --data-raw '{\"email\": \"admin@sso-testing.com\", \"password\": \"admin123\", \"client_id\": \"string\", \"redirect_uri\": \"string\"}'"
}

# Run main function
main "$@"
