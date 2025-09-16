#!/bin/bash

# Quick Kong Test Script
# Script untuk test endpoint Kong secara cepat

set -e

echo "⚡ Quick Kong Test"
echo "================="

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
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to execute command on remote server
execute_remote() {
    local command="$1"
    sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "cd $SERVER_DIR && $command"
}

# Test specific endpoint
test_endpoint() {
    local endpoint="$1"
    print_status "Testing endpoint: $endpoint"
    
    local response=$(execute_remote "curl -s -w 'HTTP_CODE:%{http_code}' http://localhost:9545$endpoint")
    local http_code=$(echo "$response" | grep -o 'HTTP_CODE:[0-9]*' | cut -d: -f2)
    local body=$(echo "$response" | sed 's/HTTP_CODE:[0-9]*$//')
    
    echo "Response: $body"
    echo "HTTP Code: $http_code"
    echo "---"
}

# Test all endpoints
main() {
    print_status "Testing Kong endpoints..."
    echo ""
    
    # Test SSO Profile endpoint (the one that was problematic)
    test_endpoint "/api/auth/sso/profil"
    
    # Test SSO Login endpoint
    test_endpoint "/api/auth/sso/login"
    
    # Test SSO Userinfo endpoint
    test_endpoint "/api/auth/sso/userinfo"
    
    # Test SSO Menus endpoint
    test_endpoint "/api/menus"
    
    # Test Example endpoint
    test_endpoint "/api/v1/example"
    
    print_status "Testing completed!"
}

# Run main function
main "$@"
