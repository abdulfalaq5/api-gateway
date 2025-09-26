#!/bin/bash

# Quick Kong Cache Fix Script
# Script cepat untuk mengatasi masalah cache Kong

set -e

echo "⚡ Quick Kong Cache Fix"
echo "======================"

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

# Main function
main() {
    print_status "🚀 Starting quick Kong cache fix..."
    
    # Step 1: Copy kong.yml to server
    copy_to_server "config/kong.yml" "$SERVER_DIR/config/kong.yml"
    
    # Step 2: Stop Kong
    print_status "Stopping Kong..."
    execute_remote "docker-compose -f docker-compose.server.yml stop kong"
    
    # Step 3: Remove Kong container
    print_status "Removing Kong container..."
    execute_remote "docker rm -f kong-gateway 2>/dev/null || true"
    
    # Step 4: Clean networks
    print_status "Cleaning Docker networks..."
    execute_remote "docker network prune -f"
    
    # Step 5: Start Kong fresh
    print_status "Starting Kong with fresh configuration..."
    execute_remote "docker-compose -f docker-compose.server.yml up -d kong"
    
    # Step 6: Wait and verify
    print_status "Waiting for Kong to be ready..."
    sleep 15
    
    # Check health
    print_status "Checking Kong health..."
    execute_remote "curl -s http://localhost:9546/status | jq '.server'"
    
    # Check routes
    print_status "Checking routes..."
    local route_count=$(sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "cd $SERVER_DIR && curl -s http://localhost:9546/routes | jq '.data | length'")
    
    if [[ "$route_count" -gt 0 ]]; then
        print_success "✅ Kong cache fixed! Found $route_count routes."
        print_status "Routes:"
        execute_remote "curl -s http://localhost:9546/routes | jq '.data[].name'"
    else
        print_error "❌ No routes found. Check Kong logs."
        execute_remote "docker logs kong-gateway --tail 10"
    fi
}

# Run main function
main "$@"
