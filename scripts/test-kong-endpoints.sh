#!/bin/bash

# Test Kong Endpoints Script
# Script untuk test endpoint Kong

set -e

echo "🧪 Testing Kong Endpoints"
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
NC='\033[0m'

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
    sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "cd $SERVER_DIR && $command"
}

# Function to test endpoint
test_endpoint() {
    local method="$1"
    local endpoint="$2"
    local expected_status="$3"
    
    print_status "Testing $method $endpoint..."
    
    local response=$(execute_remote "curl -s -w '%{http_code}' -X $method http://localhost:9545$endpoint -o /dev/null")
    
    if [[ "$response" == "$expected_status" ]]; then
        print_success "$method $endpoint -> $response ✓"
    else
        print_error "$method $endpoint -> $response (expected: $expected_status) ✗"
    fi
}

# Function to test all endpoints
test_all_endpoints() {
    print_status "Testing all Kong endpoints..."
    echo ""
    
    # Test SSO Login endpoint
    test_endpoint "POST" "/api/auth/sso/login" "200"
    
    # Test SSO Userinfo endpoint
    test_endpoint "GET" "/api/auth/sso/userinfo" "200"
    
    # Test SSO Profile endpoint
    test_endpoint "GET" "/auth/sso/profil" "200"
    
    # Test SSO Menus endpoint
    test_endpoint "GET" "/api/menus" "200"
    
    # Test Example endpoint
    test_endpoint "GET" "/api/v1/example" "200"
    
    echo ""
    print_status "Endpoint testing completed!"
}

# Function to show route details
show_route_details() {
    print_status "Showing detailed route information..."
    echo ""
    
    execute_remote "curl -s http://localhost:9546/routes | jq '.data[] | {name: .name, paths: .paths, methods: .methods, service: .service.name}'"
}

# Function to show service details
show_service_details() {
    print_status "Showing detailed service information..."
    echo ""
    
    execute_remote "curl -s http://localhost:9546/services | jq '.data[] | {name: .name, url: .url, connect_timeout: .connect_timeout}'"
}

# Function to test Kong admin endpoints
test_admin_endpoints() {
    print_status "Testing Kong admin endpoints..."
    echo ""
    
    # Test admin status
    print_status "Testing admin status endpoint..."
    execute_remote "curl -s http://localhost:9546/status | jq '.server'"
    
    echo ""
    
    # Test admin routes
    print_status "Testing admin routes endpoint..."
    local route_count=$(execute_remote "curl -s http://localhost:9546/routes | jq '.data | length'")
    print_success "Found $route_count routes"
    
    echo ""
    
    # Test admin services
    print_status "Testing admin services endpoint..."
    local service_count=$(execute_remote "curl -s http://localhost:9546/services | jq '.data | length'")
    print_success "Found $service_count services"
}

# Function to show help
show_help() {
    echo "🧪 Test Kong Endpoints Script"
    echo "============================="
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  test-endpoints        - Test all Kong endpoints"
    echo "  show-routes           - Show detailed route information"
    echo "  show-services         - Show detailed service information"
    echo "  test-admin            - Test Kong admin endpoints"
    echo "  help                  - Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 test-endpoints"
    echo "  $0 show-routes"
    echo "  $0 test-admin"
}

# Main execution
main() {
    local command="$1"
    
    case "$command" in
        "test-endpoints")
            test_all_endpoints
            ;;
        "show-routes")
            show_route_details
            ;;
        "show-services")
            show_service_details
            ;;
        "test-admin")
            test_admin_endpoints
            ;;
        "help"|"")
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
