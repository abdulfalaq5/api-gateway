#!/bin/bash

# Kong Config Manager Script
# Script untuk mengelola konfigurasi kong.yml

set -e

echo "🔧 Kong Config Manager Script"
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

# Function to copy file to remote server
copy_to_server() {
    local local_file="$1"
    local remote_file="$2"
    print_status "Copying $local_file to server..."
    
    sshpass -p "$SERVER_PASS" scp -o StrictHostKeyChecking=no "$local_file" "$SERVER_USER@$SERVER_IP:$remote_file"
}

# Function to backup current config
backup_config() {
    print_status "Backing up current Kong configuration..."
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="kong_backup_${timestamp}.yml"
    
    execute_remote "cp config/kong.yml config/$backup_file"
    print_success "Backup saved as: config/$backup_file"
}

# Function to deploy config to Kong
deploy_config() {
    print_status "Deploying Kong configuration..."
    
    # Copy kong.yml to server
    copy_to_server "config/kong.yml" "$SERVER_DIR/config/kong.yml"
    
    # Clean restart Kong to avoid cache issues
    print_status "Performing clean restart to avoid cache issues..."
    
    # Stop Kong container
    execute_remote "docker-compose -f docker-compose.server.yml stop kong"
    
    # Remove Kong container completely
    execute_remote "docker rm -f kong-gateway 2>/dev/null || true"
    
    # Clean up networks
    execute_remote "docker network prune -f"
    
    # Start Kong with fresh state
    execute_remote "docker-compose -f docker-compose.server.yml up -d kong"
    
    # Wait for Kong to be ready
    print_status "Waiting for Kong to be ready..."
    sleep 20
    
    # Check health
    health_attempts=0
    max_attempts=30
    
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
        execute_remote "docker logs kong-gateway --tail 20"
        return 1
    fi
    
    # Show Kong status
    execute_remote "curl -s http://localhost:9546/status | jq '.server'"
    
    # Verify routes
    local route_count=$(sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "cd $SERVER_DIR && curl -s http://localhost:9546/routes | jq '.data | length'")
    
    if [[ "$route_count" -gt 0 ]]; then
        print_success "Configuration deployed successfully! Found $route_count routes."
        
        # Show route details
        print_status "Route details:"
        execute_remote "curl -s http://localhost:9546/routes | jq '.data[].name'"
        
        # Show service details
        print_status "Service details:"
        execute_remote "curl -s http://localhost:9546/services | jq '.data[].name'"
        
    else
        print_error "Configuration deployment failed! No routes found."
        return 1
    fi
}

# Function to deploy config with cache cleaning
deploy_with_cache_clean() {
    print_status "Deploying Kong configuration with cache cleaning..."
    
    # Copy kong.yml to server
    copy_to_server "config/kong.yml" "$SERVER_DIR/config/kong.yml"
    
    # Use the dedicated cache fix script
    print_status "Using cache fix script for clean deployment..."
    execute_remote "./scripts/fix-kong-cache.sh deploy"
}

# Function to add service to kong.yml
add_service() {
    local name="$1"
    local url="$2"
    local path="$3"
    local methods="$4"
    
    if [[ -z "$name" || -z "$url" || -z "$path" ]]; then
        print_error "Usage: add_service <name> <url> <path> [methods]"
        return 1
    fi
    
    if [[ -z "$methods" ]]; then
        methods="GET,POST,PUT,DELETE,OPTIONS"
    fi
    
    print_status "Adding service to kong.yml: $name"
    
    # Backup current config
    backup_config
    
    # Create temporary file with new service
    local temp_file=$(mktemp)
    
    # Read current kong.yml and add new service
    cat config/kong.yml > "$temp_file"
    
    # Add new service to the end of services array
    sed -i.bak "/^services:/a\\
  - name: $name\\
    url: $url\\
    connect_timeout: 60000\\
    write_timeout: 60000\\
    read_timeout: 60000\\
    routes:\\
      - name: ${name}-route\\
        paths:\\
          - $path\\
        methods:\\
          - $(echo $methods | tr ',' '\n' | sed 's/^/          - /')\\
        strip_path: true" "$temp_file"
    
    # Replace original file
    mv "$temp_file" config/kong.yml
    
    print_success "Service added to kong.yml"
}

# Function to remove service from kong.yml
remove_service() {
    local name="$1"
    
    if [[ -z "$name" ]]; then
        print_error "Usage: remove_service <name>"
        return 1
    fi
    
    print_status "Removing service from kong.yml: $name"
    
    # Backup current config
    backup_config
    
    # Create temporary file without the service
    local temp_file=$(mktemp)
    
    # Remove service from kong.yml
    awk -v service_name="$name" '
    BEGIN { in_service = 0; service_found = 0 }
    /^services:/ { print; next }
    /^  - name: / { 
        if ($3 == service_name) { 
            in_service = 1; 
            service_found = 1; 
            next 
        } 
    }
    /^  - name: / && in_service { 
        in_service = 0 
    }
    in_service == 0 { print }
    END { 
        if (service_found == 0) { 
            print "Service not found: " service_name > "/dev/stderr" 
        } 
    }' config/kong.yml > "$temp_file"
    
    # Replace original file
    mv "$temp_file" config/kong.yml
    
    print_success "Service removed from kong.yml"
}

# Function to show current config
show_config() {
    print_status "Current Kong configuration:"
    echo ""
    cat config/kong.yml
}

# Function to show help
show_help() {
    echo "🔧 Kong Config Manager Script"
    echo "=============================="
    echo ""
    echo "Usage: $0 <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  show                              - Show current configuration"
    echo "  backup                            - Backup current configuration"
    echo "  deploy                            - Deploy configuration to Kong"
    echo "  deploy-clean                      - Deploy configuration with cache cleaning"
    echo "  add-service <name> <url> <path> [methods] - Add service to kong.yml"
    echo "  remove-service <name>             - Remove service from kong.yml"
    echo ""
    echo "Examples:"
    echo "  $0 show"
    echo "  $0 backup"
    echo "  $0 add-service my-api http://backend:3000 /api/users GET,POST"
    echo "  $0 remove-service my-api"
    echo "  $0 deploy"
    echo "  $0 deploy-clean"
}

# Main execution
main() {
    local command="$1"
    
    case "$command" in
        "show")
            show_config
            ;;
        "backup")
            backup_config
            ;;
        "deploy")
            deploy_config
            ;;
        "deploy-clean")
            deploy_with_cache_clean
            ;;
        "add-service")
            add_service "$2" "$3" "$4" "$5"
            ;;
        "remove-service")
            remove_service "$2"
            ;;
        *)
            show_help
            ;;
    esac
}

# Run main function
main "$@"
