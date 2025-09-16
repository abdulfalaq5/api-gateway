#!/bin/bash

# Remote Server Kong Fix Script
# Script untuk mengakses server dan memperbaiki Kong

set -e

echo "🔧 Remote Server Kong Fix Script"
echo "================================="

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

# Function to copy file to remote server
copy_to_server() {
    local local_file="$1"
    local remote_file="$2"
    print_status "Copying $local_file to server..."
    
    sshpass -p "$SERVER_PASS" scp -o StrictHostKeyChecking=no "$local_file" "$SERVER_USER@$SERVER_IP:$remote_file"
}

# Function to check Kong status on server
check_kong_status() {
    print_status "Checking Kong status on server..."
    
    execute_remote "docker ps | grep kong-gateway"
    execute_remote "curl -s http://localhost:9546/status | jq '.server'"
}

# Function to check Kong routes on server
check_kong_routes() {
    print_status "Checking Kong routes on server..."
    
    execute_remote "curl -s http://localhost:9546/routes | jq '.data | length'"
    execute_remote "curl -s http://localhost:9546/routes | jq '.data[] | {name: .name, paths: .paths, methods: .methods}'"
}

# Function to deploy Kong config on server
deploy_kong_config() {
    print_status "Deploying Kong configuration on server..."
    
    # Copy kong.yml to server
    copy_to_server "config/kong.yml" "$SERVER_DIR/config/kong.yml"
    
    # Deploy configuration
    execute_remote "curl -X POST http://localhost:9546/config -H 'Content-Type: application/json' -d @config/kong.yml"
    
    # Wait a bit
    sleep 5
    
    # Verify deployment
    execute_remote "curl -s http://localhost:9546/routes | jq '.data | length'"
}

# Function to restart Kong on server
restart_kong() {
    print_status "Restarting Kong on server..."
    
    execute_remote "docker-compose -f docker-compose.server.yml down kong"
    sleep 3
    execute_remote "docker-compose -f docker-compose.server.yml up -d kong"
    sleep 15
    
    # Check health
    execute_remote "curl -s http://localhost:9546/status | jq '.server'"
}

# Function to test SSO endpoint on server
test_sso_endpoint() {
    print_status "Testing SSO endpoint on server..."
    
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
    echo "🚀 Starting Remote Server Kong Fix..."
    echo "====================================="
    
    # Check if sshpass is available
    if ! command -v sshpass &> /dev/null; then
        print_error "sshpass is not installed. Please install it first:"
        echo "  macOS: brew install sshpass"
        echo "  Ubuntu: sudo apt-get install sshpass"
        exit 1
    fi
    
    # Step 1: Check Kong status
    print_status "Step 1: Checking Kong status..."
    check_kong_status
    
    # Step 2: Check Kong routes
    print_status "Step 2: Checking Kong routes..."
    check_kong_routes
    
    # Step 3: Deploy Kong config
    print_status "Step 3: Deploying Kong configuration..."
    deploy_kong_config
    
    # Step 4: Verify routes
    print_status "Step 4: Verifying routes..."
    check_kong_routes
    
    # Step 5: Test SSO endpoint
    print_status "Step 5: Testing SSO endpoint..."
    test_sso_endpoint
    
    # Step 6: Test external endpoint
    print_status "Step 6: Testing external endpoint..."
    test_external_endpoint
    
    print_success "✅ Remote server Kong fix completed!"
    echo ""
    echo "🎉 You can now test the endpoint:"
    echo "curl --location 'https://services.motorsights.com/api/auth/sso/login' \\"
    echo "  --header 'Content-Type: application/json' \\"
    echo "  --data-raw '{\"email\": \"admin@sso-testing.com\", \"password\": \"admin123\", \"client_id\": \"string\", \"redirect_uri\": \"string\"}'"
}

# Run main function
main "$@"
