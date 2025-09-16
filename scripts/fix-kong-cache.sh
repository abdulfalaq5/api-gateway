#!/bin/bash

# Fix Kong Cache Issues Script
# Script untuk mengatasi masalah cache Kong yang menyebabkan route baru tidak muncul

set -e

echo "🔧 Fix Kong Cache Issues Script"
echo "==============================="

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

# Function to clean Kong cache and restart
clean_kong_cache() {
    print_status "🧹 Cleaning Kong cache and restarting..."
    
    # Step 1: Stop Kong container
    print_status "Stopping Kong container..."
    execute_remote "docker-compose -f docker-compose.server.yml stop kong"
    
    # Step 2: Remove Kong container completely
    print_status "Removing Kong container..."
    execute_remote "docker rm -f kong-gateway 2>/dev/null || true"
    
    # Step 3: Clean up Docker networks
    print_status "Cleaning up Docker networks..."
    execute_remote "docker network prune -f"
    
    # Step 4: Remove Kong-related networks
    print_status "Removing Kong networks..."
    execute_remote "docker network ls --format '{{.Name}}' | grep -E '(kong|api-gateway)' | xargs -r docker network rm 2>/dev/null || true"
    
    # Step 5: Clean up volumes
    print_status "Cleaning up unused volumes..."
    execute_remote "docker volume prune -f"
    
    # Step 6: Pull latest Kong image to ensure fresh state
    print_status "Pulling latest Kong image..."
    execute_remote "docker pull kong:3.4"
    
    # Step 7: Start Kong with fresh state
    print_status "Starting Kong with fresh configuration..."
    execute_remote "docker-compose -f docker-compose.server.yml up -d kong"
    
    # Step 8: Wait for Kong to be ready
    print_status "Waiting for Kong to be ready..."
    sleep 20
    
    # Step 9: Verify Kong is healthy
    print_status "Checking Kong health..."
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
        print_status "Kong logs:"
        execute_remote "docker logs kong-gateway --tail 20"
        return 1
    fi
    
    print_success "✅ Kong cache has been cleaned successfully!"
}

# Function to deploy config with cache cleaning
deploy_with_cache_clean() {
    print_status "🚀 Deploying Kong configuration with cache cleaning..."
    
    # Step 1: Copy kong.yml to server
    copy_to_server "config/kong.yml" "$SERVER_DIR/config/kong.yml"
    
    # Step 2: Clean Kong cache
    clean_kong_cache
    
    # Step 3: Verify routes are loaded
    print_status "Verifying routes are loaded..."
    sleep 5
    
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

# Function to show Kong status
show_kong_status() {
    print_status "📊 Kong Status:"
    echo ""
    
    # Health check
    print_status "Health check:"
    execute_remote "curl -s http://localhost:9546/status | jq '.server'"
    echo ""
    
    # Routes
    print_status "Routes:"
    execute_remote "curl -s http://localhost:9546/routes | jq '.data[].name'"
    echo ""
    
    # Services
    print_status "Services:"
    execute_remote "curl -s http://localhost:9546/services | jq '.data[].name'"
    echo ""
    
    # Plugins
    print_status "Plugins:"
    execute_remote "curl -s http://localhost:9546/plugins | jq '.data[].name'"
}

# Function to show help
show_help() {
    echo "🔧 Fix Kong Cache Issues Script"
    echo "==============================="
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  clean-cache              - Clean Kong cache and restart"
    echo "  deploy                   - Deploy config with cache cleaning"
    echo "  status                   - Show Kong status"
    echo "  help                     - Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 clean-cache"
    echo "  $0 deploy"
    echo "  $0 status"
}

# Main execution
main() {
    local command="$1"
    
    case "$command" in
        "clean-cache")
            clean_kong_cache
            ;;
        "deploy")
            deploy_with_cache_clean
            ;;
        "status")
            show_kong_status
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
