#!/bin/bash

# Remote Server Kong Troubleshooting Script
# Script untuk troubleshooting Kong di remote server

set -e

echo "🔍 Remote Server Kong Troubleshooting"
echo "====================================="

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

# Function to test SSH connection
test_ssh_connection() {
    print_status "Testing SSH connection to $SERVER_IP..."
    
    if sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER_USER@$SERVER_IP" "echo 'SSH connection successful'" 2>/dev/null; then
        print_success "SSH connection is working"
        return 0
    else
        print_error "SSH connection failed"
        return 1
    fi
}

# Function to execute command on remote server with error handling
execute_remote() {
    local command="$1"
    print_status "Executing: $command"
    
    if sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "cd $SERVER_DIR && $command" 2>/dev/null; then
        return 0
    else
        print_error "Failed to execute command: $command"
        return 1
    fi
}

# Function to copy file to remote server
copy_to_server() {
    local local_file="$1"
    local remote_file="$2"
    print_status "Copying $local_file to server..."
    
    if sshpass -p "$SERVER_PASS" scp -o StrictHostKeyChecking=no "$local_file" "$SERVER_USER@$SERVER_IP:$remote_file" 2>/dev/null; then
        print_success "File copied successfully"
        return 0
    else
        print_error "Failed to copy file: $local_file"
        return 1
    fi
}

# Function to check Kong status
check_kong_status() {
    print_status "Checking Kong status..."
    
    # Check if Kong container is running
    if execute_remote "docker ps | grep kong-gateway"; then
        print_success "Kong container is running"
    else
        print_error "Kong container is not running"
        return 1
    fi
    
    # Check Kong health
    print_status "Checking Kong health..."
    if execute_remote "curl -s http://localhost:9546/status"; then
        print_success "Kong health check passed"
    else
        print_error "Kong health check failed"
        return 1
    fi
    
    # Check routes
    print_status "Checking Kong routes..."
    local routes=$(sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "cd $SERVER_DIR && curl -s http://localhost:9546/routes" 2>/dev/null)
    local route_count=$(echo "$routes" | jq '.data | length' 2>/dev/null || echo "0")
    
    if [[ "$route_count" -gt 0 ]]; then
        print_success "Found $route_count routes"
        echo "$routes" | jq '.data[].name' 2>/dev/null || true
    else
        print_warning "No routes found"
    fi
    
    # Check services
    print_status "Checking Kong services..."
    local services=$(sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "cd $SERVER_DIR && curl -s http://localhost:9546/services" 2>/dev/null)
    local service_count=$(echo "$services" | jq '.data | length' 2>/dev/null || echo "0")
    
    if [[ "$service_count" -gt 0 ]]; then
        print_success "Found $service_count services"
        echo "$services" | jq '.data[].name' 2>/dev/null || true
    else
        print_warning "No services found"
    fi
}

# Function to check Kong configuration
check_kong_config() {
    print_status "Checking Kong configuration..."
    
    # Check if kong.yml exists
    if execute_remote "ls -la config/kong.yml"; then
        print_success "kong.yml exists"
    else
        print_error "kong.yml not found"
        return 1
    fi
    
    # Check kong.yml content
    print_status "Checking kong.yml content..."
    execute_remote "head -20 config/kong.yml"
    
    # Check if Kong is using the config file
    print_status "Checking Kong declarative config..."
    execute_remote "docker exec kong-gateway kong config -c /kong/kong.yml" 2>/dev/null || print_warning "Could not validate kong.yml"
}

# Function to fix Kong issues
fix_kong_issues() {
    print_status "Fixing Kong issues..."
    
    # Copy latest kong.yml
    copy_to_server "config/kong.yml" "$SERVER_DIR/config/kong.yml"
    
    # Stop Kong
    print_status "Stopping Kong..."
    execute_remote "docker-compose -f docker-compose.server.yml stop kong"
    
    # Remove Kong container
    print_status "Removing Kong container..."
    execute_remote "docker rm -f kong-gateway 2>/dev/null || true"
    
    # Clean networks
    print_status "Cleaning Docker networks..."
    execute_remote "docker network prune -f"
    
    # Start Kong
    print_status "Starting Kong..."
    execute_remote "docker-compose -f docker-compose.server.yml up -d kong"
    
    # Wait for Kong
    print_status "Waiting for Kong to be ready..."
    sleep 20
    
    # Check if Kong is healthy
    local health_attempts=0
    local max_attempts=30
    
    while [[ $health_attempts -lt $max_attempts ]]; do
        if execute_remote "curl -s http://localhost:9546/status > /dev/null 2>&1"; then
            print_success "Kong is healthy"
            break
        fi
        
        print_status "Waiting for Kong health check... (attempt $((health_attempts + 1))/$max_attempts)"
        sleep 3
        ((health_attempts++))
    done
    
    if [[ $health_attempts -eq $max_attempts ]]; then
        print_error "Kong failed to become healthy"
        print_status "Kong logs:"
        execute_remote "docker logs kong-gateway --tail 20"
        return 1
    fi
    
    # Check routes after fix
    print_status "Checking routes after fix..."
    local routes=$(sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "cd $SERVER_DIR && curl -s http://localhost:9546/routes" 2>/dev/null)
    local route_count=$(echo "$routes" | jq '.data | length' 2>/dev/null || echo "0")
    
    if [[ "$route_count" -gt 0 ]]; then
        print_success "✅ Kong fixed! Found $route_count routes"
        echo "$routes" | jq '.data[].name' 2>/dev/null || true
    else
        print_error "❌ Kong fix failed! No routes found"
        return 1
    fi
}

# Function to show Kong logs
show_kong_logs() {
    print_status "Showing Kong logs..."
    execute_remote "docker logs kong-gateway --tail 30"
}

# Function to show help
show_help() {
    echo "🔍 Remote Server Kong Troubleshooting Script"
    echo "==========================================="
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  test-connection        - Test SSH connection"
    echo "  check-status           - Check Kong status"
    echo "  check-config           - Check Kong configuration"
    echo "  fix-issues             - Fix Kong issues"
    echo "  show-logs              - Show Kong logs"
    echo "  help                   - Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 test-connection"
    echo "  $0 check-status"
    echo "  $0 fix-issues"
}

# Main execution
main() {
    local command="$1"
    
    case "$command" in
        "test-connection")
            test_ssh_connection
            ;;
        "check-status")
            if test_ssh_connection; then
                check_kong_status
            fi
            ;;
        "check-config")
            if test_ssh_connection; then
                check_kong_config
            fi
            ;;
        "fix-issues")
            if test_ssh_connection; then
                fix_kong_issues
            fi
            ;;
        "show-logs")
            if test_ssh_connection; then
                show_kong_logs
            fi
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
