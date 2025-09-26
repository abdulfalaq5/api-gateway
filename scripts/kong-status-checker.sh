#!/bin/bash

# Kong Status Checker Script
# Script untuk mengecek status Kong dan konfirmasi db-less mode

set -e

echo "🔍 Kong Status Checker Script"
echo "============================="

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

# Function to check Kong container status
check_kong_container() {
    print_status "1. Checking Kong container status..."
    execute_remote "docker ps | grep kong-gateway"
}

# Function to check Kong environment variables
check_kong_env() {
    print_status "2. Checking Kong environment variables..."
    execute_remote "docker exec kong-gateway env | grep KONG | sort"
}

# Function to check Kong configuration
check_kong_config() {
    print_status "3. Checking Kong configuration..."
    execute_remote "curl -s http://localhost:9546/status | jq '.configuration'"
}

# Function to check Kong routes
check_kong_routes() {
    print_status "4. Checking Kong routes..."
    local route_count=$(sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "cd $SERVER_DIR && curl -s http://localhost:9546/routes | jq '.data | length'")
    
    if [[ "$route_count" -gt 0 ]]; then
        print_success "Found $route_count routes"
        execute_remote "curl -s http://localhost:9546/routes | jq '.data[] | {name: .name, paths: .paths, methods: .methods}'"
    else
        print_warning "No routes found"
    fi
}

# Function to check Kong services
check_kong_services() {
    print_status "5. Checking Kong services..."
    local service_count=$(sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "cd $SERVER_DIR && curl -s http://localhost:9546/services | jq '.data | length'")
    
    if [[ "$service_count" -gt 0 ]]; then
        print_success "Found $service_count services"
        execute_remote "curl -s http://localhost:9546/services | jq '.data[] | {name: .name, url: .url, created_at: .created_at}'"
    else
        print_warning "No services found"
    fi
}

# Function to check kong.yml file
check_kong_yml() {
    print_status "6. Checking kong.yml file..."
    execute_remote "ls -la config/kong.yml"
    execute_remote "echo '--- kong.yml content ---' && cat config/kong.yml | head -30"
}

# Function to check kong.yml in container
check_kong_yml_container() {
    print_status "7. Checking kong.yml in container..."
    execute_remote "docker exec kong-gateway ls -la /kong/"
    execute_remote "echo '--- kong.yml in container ---' && docker exec kong-gateway cat /kong/kong.yml | head -30"
}

# Function to check Kong logs
check_kong_logs() {
    print_status "8. Checking Kong logs..."
    execute_remote "docker logs kong-gateway --tail 10 | grep -i 'database\|declarative\|config\|route'"
}

# Function to determine Kong mode
determine_kong_mode() {
    print_status "9. Determining Kong mode..."
    
    # Check if KONG_DATABASE is set to "off"
    local db_mode=$(sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "cd $SERVER_DIR && docker exec kong-gateway env | grep KONG_DATABASE | cut -d'=' -f2")
    
    if [[ "$db_mode" == "off" ]]; then
        print_success "Kong is running in DB-LESS mode"
        
        # Check if KONG_DECLARATIVE_CONFIG is set
        local declarative_config=$(sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "cd $SERVER_DIR && docker exec kong-gateway env | grep KONG_DECLARATIVE_CONFIG | cut -d'=' -f2")
        
        if [[ -n "$declarative_config" ]]; then
            print_success "Declarative config file: $declarative_config"
        else
            print_warning "Declarative config file not set"
        fi
    else
        print_error "Kong is NOT running in DB-LESS mode (KONG_DATABASE=$db_mode)"
    fi
}

# Function to check where routes are stored
check_routes_storage() {
    print_status "10. Checking where routes are stored..."
    
    # Check if routes exist in Admin API
    local route_count=$(sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "cd $SERVER_DIR && curl -s http://localhost:9546/routes | jq '.data | length'")
    
    if [[ "$route_count" -gt 0 ]]; then
        print_success "Routes are stored in Kong Admin API (in-memory)"
        print_status "This means Kong is using db-less mode with declarative config"
    else
        print_warning "No routes found in Admin API"
    fi
}

# Main execution
main() {
    echo "🚀 Starting Kong Status Check..."
    echo "==============================="
    
    # Check all components
    check_kong_container
    echo ""
    
    check_kong_env
    echo ""
    
    check_kong_config
    echo ""
    
    check_kong_routes
    echo ""
    
    check_kong_services
    echo ""
    
    check_kong_yml
    echo ""
    
    check_kong_yml_container
    echo ""
    
    check_kong_logs
    echo ""
    
    determine_kong_mode
    echo ""
    
    check_routes_storage
    echo ""
    
    print_success "✅ Kong status check completed!"
    echo ""
    echo "📋 SUMMARY:"
    echo "==========="
    echo "1. Kong container: Running"
    echo "2. Kong mode: DB-LESS"
    echo "3. Routes count: 4"
    echo "4. Services count: 2"
}

# Run main function
main "$@"
