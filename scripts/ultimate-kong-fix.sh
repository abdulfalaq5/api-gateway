#!/bin/bash

# Ultimate Kong Fix Script
# Script ultimate untuk memperbaiki Kong

set -e

echo "🔧 Ultimate Kong Fix Script"
echo "==========================="

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

# Function to check Kong logs
check_kong_logs() {
    print_status "Checking Kong logs..."
    
    execute_remote "docker logs kong-gateway --tail 20 | grep -i 'error\|warn\|config\|route'"
}

# Function to verify kong.yml in container
verify_kong_yml() {
    print_status "Verifying kong.yml in container..."
    
    execute_remote "docker exec kong-gateway ls -la /kong/"
    execute_remote "docker exec kong-gateway cat /kong/kong.yml | head -20"
}

# Function to restart Kong with force
restart_kong_force() {
    print_status "Force restarting Kong..."
    
    # Stop Kong
    execute_remote "docker-compose -f docker-compose.server.yml down kong"
    
    # Remove container
    execute_remote "docker rm -f kong-gateway 2>/dev/null || true"
    
    # Wait
    sleep 5
    
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
    echo "🚀 Starting Ultimate Kong Fix..."
    echo "==============================="
    
    # Step 1: Check Kong status
    print_status "Step 1: Checking Kong status..."
    execute_remote "docker ps | grep kong-gateway"
    
    # Step 2: Check Kong logs
    check_kong_logs
    
    # Step 3: Verify kong.yml in container
    verify_kong_yml
    
    # Step 4: Copy kong.yml to server
    print_status "Step 4: Copying kong.yml to server..."
    copy_to_server "config/kong.yml" "$SERVER_DIR/config/kong.yml"
    
    # Step 5: Force restart Kong
    restart_kong_force
    
    # Step 6: Check Kong health
    print_status "Step 6: Checking Kong health..."
    execute_remote "curl -s http://localhost:9546/status | jq '.server'"
    
    # Step 7: Check routes
    print_status "Step 7: Checking routes..."
    execute_remote "curl -s http://localhost:9546/routes | jq '.data | length'"
    
    # Step 8: Show routes
    print_status "Step 8: Showing routes..."
    execute_remote "curl -s http://localhost:9546/routes | jq '.data[] | {name: .name, paths: .paths, methods: .methods}'"
    
    # Step 9: Test SSO endpoint
    test_sso_endpoint
    
    # Step 10: Test external endpoint
    test_external_endpoint
    
    print_success "✅ Ultimate Kong fix completed!"
    echo ""
    echo "🎉 Test the endpoint:"
    echo "curl --location 'https://services.motorsights.com/api/auth/sso/login' \\"
    echo "  --header 'Content-Type: application/json' \\"
    echo "  --data-raw '{\"email\": \"admin@sso-testing.com\", \"password\": \"admin123\", \"client_id\": \"string\", \"redirect_uri\": \"string\"}'"
}

# Run main function
main "$@"
