#!/bin/bash

# Kong Helper Script - Quick operations untuk Kong API Gateway
# File: scripts/kong-helper.sh

set -e

# Colors untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Kong Admin API URL
KONG_ADMIN="http://localhost:9546"
KONG_PROXY="http://localhost:9545"

# Fungsi helper
print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Fungsi untuk cek Kong status
check_kong_status() {
    if curl -s --connect-timeout 5 "$KONG_ADMIN/" > /dev/null 2>&1; then
        print_success "Kong is running"
        return 0
    else
        print_error "Kong is not running or not accessible"
        return 1
    fi
}

# Fungsi untuk list services
list_services() {
    print_header "Kong Services"
    curl -s "$KONG_ADMIN/services/" | jq '.data[] | {name: .name, host: .host, port: .port, protocol: .protocol, url: .url}' 2>/dev/null || print_error "Cannot get services"
}

# Fungsi untuk list routes
list_routes() {
    print_header "Kong Routes"
    curl -s "$KONG_ADMIN/routes/" | jq '.data[] | {name: .name, paths: .paths, methods: .methods, service: .service.name}' 2>/dev/null || print_error "Cannot get routes"
}

# Fungsi untuk list plugins
list_plugins() {
    print_header "Kong Plugins"
    curl -s "$KONG_ADMIN/plugins/" | jq '.data[] | {name: .name, service: .service.name, enabled: .enabled}' 2>/dev/null || print_error "Cannot get plugins"
}

# Fungsi untuk cek service spesifik
check_service() {
    local service_name=$1
    if [ -z "$service_name" ]; then
        print_error "Service name required"
        return 1
    fi
    
    print_header "Service: $service_name"
    curl -s "$KONG_ADMIN/services/$service_name" | jq '{name: .name, host: .host, port: .port, protocol: .protocol, url: .url, connect_timeout: .connect_timeout}' 2>/dev/null || print_error "Cannot get service $service_name"
}

# Fungsi untuk cek routes service
check_service_routes() {
    local service_name=$1
    if [ -z "$service_name" ]; then
        print_error "Service name required"
        return 1
    fi
    
    print_header "Routes for Service: $service_name"
    curl -s "$KONG_ADMIN/services/$service_name/routes" | jq '.data[] | {name: .name, paths: .paths, methods: .methods}' 2>/dev/null || print_error "Cannot get routes for service $service_name"
}

# Fungsi untuk test endpoint
test_endpoint() {
    local endpoint=$1
    if [ -z "$endpoint" ]; then
        print_error "Endpoint required"
        return 1
    fi
    
    print_header "Testing Endpoint: $endpoint"
    if curl -s --connect-timeout 10 "$KONG_PROXY$endpoint" > /dev/null 2>&1; then
        print_success "Endpoint accessible"
    else
        print_error "Endpoint not accessible"
    fi
}

# Fungsi untuk test SSO endpoint
test_sso() {
    print_header "Testing SSO Endpoint"
    response=$(curl -s --connect-timeout 10 -w "%{http_code}" -X POST "$KONG_PROXY/api/auth/sso/login" \
      -H "Content-Type: application/json" \
      -d '{"email":"admin@sso-testing.com","password":"admin123","client_id":"string","redirect_uri":"string"}' 2>/dev/null)
    
    http_code="${response: -3}"
    
    if [ "$http_code" = "200" ]; then
        print_success "SSO endpoint working (HTTP 200)"
    elif [ "$http_code" = "502" ]; then
        print_error "Bad Gateway (HTTP 502)"
    elif [ "$http_code" = "504" ]; then
        print_error "Gateway Timeout (HTTP 504)"
    else
        print_warning "Unexpected response (HTTP $http_code)"
    fi
}

# Fungsi untuk backup
backup_config() {
    local backup_dir="backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    print_header "Creating Backup"
    echo "Backup directory: $backup_dir"
    
    curl -s "$KONG_ADMIN/config" > "$backup_dir/kong_config.json"
    curl -s "$KONG_ADMIN/services/" > "$backup_dir/services.json"
    curl -s "$KONG_ADMIN/routes/" > "$backup_dir/routes.json"
    curl -s "$KONG_ADMIN/plugins/" > "$backup_dir/plugins.json"
    
    print_success "Backup created in $backup_dir"
}

# Fungsi untuk restart Kong
restart_kong() {
    print_header "Restarting Kong"
    docker-compose restart kong
    print_success "Kong restarted"
    print_warning "Waiting for Kong to start..."
    sleep 15
    
    if check_kong_status; then
        print_success "Kong is running after restart"
    else
        print_error "Kong failed to start"
    fi
}

# Fungsi untuk cleanup
cleanup_wrong_configs() {
    print_header "Cleaning Up Wrong Configurations"
    
    # Hapus services yang salah
    print_warning "Removing wrong services..."
    curl -s "$KONG_ADMIN/services/" | jq -r '.data[] | select(.host == "host.docker.internal" or .host == "172.17.0.1" or .port == 9588) | .id' | while read service_id; do
        if [ ! -z "$service_id" ]; then
            curl -X DELETE "$KONG_ADMIN/services/$service_id" > /dev/null 2>&1
            print_success "Removed service: $service_id"
        fi
    done
    
    # Hapus routes yang salah
    print_warning "Removing wrong routes..."
    curl -s "$KONG_ADMIN/routes/" | jq -r '.data[] | select(.name | contains("api-gate") or contains("services-direct")) | .id' | while read route_id; do
        if [ ! -z "$route_id" ]; then
            curl -X DELETE "$KONG_ADMIN/routes/$route_id" > /dev/null 2>&1
            print_success "Removed route: $route_id"
        fi
    done
    
    print_success "Cleanup completed"
}

# Fungsi untuk fix SSO
fix_sso() {
    print_header "Fixing SSO Configuration"
    
    # Backup dulu
    backup_config
    
    # Cleanup
    cleanup_wrong_configs
    
    # Update SSO service
    print_warning "Updating SSO service..."
    curl -X PATCH "$KONG_ADMIN/services/sso-service" \
      -d "url=https://api-gate.motorsights.com" \
      -d "connect_timeout=60000" \
      -d "write_timeout=60000" \
      -d "read_timeout=60000" > /dev/null 2>&1
    
    print_success "SSO service updated"
    
    # Restart Kong
    restart_kong
    
    # Test SSO
    test_sso
}

# Fungsi untuk monitor logs
monitor_logs() {
    print_header "Monitoring Kong Logs"
    print_warning "Press Ctrl+C to stop monitoring"
    docker-compose logs -f kong
}

# Fungsi untuk show help
show_help() {
    echo "Kong Helper Script"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  status                    - Check Kong status"
    echo "  services                 - List all services"
    echo "  routes                   - List all routes"
    echo "  plugins                  - List all plugins"
    echo "  service <name>           - Check specific service"
    echo "  routes <service>          - Check routes for service"
    echo "  test <endpoint>          - Test endpoint"
    echo "  sso                     - Test SSO endpoint"
    echo "  backup                  - Backup Kong configuration"
    echo "  restart                 - Restart Kong"
    echo "  cleanup                 - Cleanup wrong configurations"
    echo "  fix-sso                 - Fix SSO configuration"
    echo "  logs                    - Monitor Kong logs"
    echo "  help                    - Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 service sso-service"
    echo "  $0 routes sso-service"
    echo "  $0 test /api/auth/sso/login"
    echo "  $0 fix-sso"
}

# Main script logic
case "$1" in
    "status")
        check_kong_status
        ;;
    "services")
        check_kong_status && list_services
        ;;
    "routes")
        check_kong_status && list_routes
        ;;
    "plugins")
        check_kong_status && list_plugins
        ;;
    "service")
        check_kong_status && check_service "$2"
        ;;
    "routes")
        check_kong_status && check_service_routes "$2"
        ;;
    "test")
        check_kong_status && test_endpoint "$2"
        ;;
    "sso")
        check_kong_status && test_sso
        ;;
    "backup")
        check_kong_status && backup_config
        ;;
    "restart")
        restart_kong
        ;;
    "cleanup")
        check_kong_status && cleanup_wrong_configs
        ;;
    "fix-sso")
        check_kong_status && fix_sso
        ;;
    "logs")
        monitor_logs
        ;;
    "help"|"--help"|"-h"|"")
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
