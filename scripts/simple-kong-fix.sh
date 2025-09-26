#!/bin/bash

# Simple Kong Fix Script
# Script sederhana untuk memperbaiki Kong

set -e

echo "🔧 Simple Kong Fix Script"
echo "========================="

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

# Main execution
main() {
    echo "🚀 Starting Simple Kong Fix..."
    echo "============================="
    
    # Step 1: Check Kong status
    print_status "Step 1: Checking Kong status..."
    execute_remote "docker ps | grep kong-gateway"
    
    # Step 2: Check Kong health
    print_status "Step 2: Checking Kong health..."
    execute_remote "curl -s http://localhost:9546/status | jq '.server'"
    
    # Step 3: Check current routes
    print_status "Step 3: Checking current routes..."
    execute_remote "curl -s http://localhost:9546/routes | jq '.data | length'"
    
    # Step 4: Copy kong.yml to server
    print_status "Step 4: Copying kong.yml to server..."
    copy_to_server "config/kong.yml" "$SERVER_DIR/config/kong.yml"
    
    # Step 5: Stop Kong
    print_status "Step 5: Stopping Kong..."
    execute_remote "docker-compose -f docker-compose.server.yml down kong"
    
    # Step 6: Wait
    print_status "Step 6: Waiting..."
    sleep 5
    
    # Step 7: Start Kong
    print_status "Step 7: Starting Kong..."
    execute_remote "docker-compose -f docker-compose.server.yml up -d kong"
    
    # Step 8: Wait for Kong to be ready
    print_status "Step 8: Waiting for Kong to be ready..."
    sleep 20
    
    # Step 9: Check Kong health
    print_status "Step 9: Checking Kong health..."
    execute_remote "curl -s http://localhost:9546/status | jq '.server'"
    
    # Step 10: Check routes
    print_status "Step 10: Checking routes..."
    execute_remote "curl -s http://localhost:9546/routes | jq '.data | length'"
    
    # Step 11: Show routes
    print_status "Step 11: Showing routes..."
    execute_remote "curl -s http://localhost:9546/routes | jq '.data[] | {name: .name, paths: .paths, methods: .methods}'"
    
    # Step 12: Test SSO endpoint
    print_status "Step 12: Testing SSO endpoint..."
    execute_remote "curl -s -X POST http://localhost:9545/api/auth/sso/login -H 'Content-Type: application/json' -d '{\"email\": \"admin@sso-testing.com\", \"password\": \"admin123\", \"client_id\": \"string\", \"redirect_uri\": \"string\"}' | head -c 200"
    
    # Step 13: Test through Nginx
    print_status "Step 13: Testing through Nginx..."
    execute_remote "curl -s -X POST https://localhost/api/auth/sso/login -H 'Content-Type: application/json' -d '{\"email\": \"admin@sso-testing.com\", \"password\": \"admin123\", \"client_id\": \"string\", \"redirect_uri\": \"string\"}' -k | head -c 200"
    
    print_success "✅ Kong fix completed!"
    echo ""
    echo "🎉 Test the endpoint:"
    echo "curl --location 'https://services.motorsights.com/api/auth/sso/login' \\"
    echo "  --header 'Content-Type: application/json' \\"
    echo "  --data-raw '{\"email\": \"admin@sso-testing.com\", \"password\": \"admin123\", \"client_id\": \"string\", \"redirect_uri\": \"string\"}'"
}

# Run main function
main "$@"
