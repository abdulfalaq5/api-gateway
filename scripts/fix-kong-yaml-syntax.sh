#!/bin/bash

# Fix Kong YAML Syntax Script
# Script untuk memperbaiki masalah syntax YAML di kong.yml

set -e

echo "🔧 Fix Kong YAML Syntax Script"
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

# Function to fix Kong YAML syntax and deploy
fix_and_deploy() {
    print_status "🔧 Fixing Kong YAML syntax and deploying..."
    echo ""
    
    # Step 1: Backup current config on server
    print_status "1. Backing up current config on server..."
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    execute_remote "cp config/kong.yml config/kong.yml.backup.$timestamp"
    print_success "Backup saved as: config/kong.yml.backup.$timestamp"
    echo ""
    
    # Step 2: Copy fixed kong.yml to server
    print_status "2. Copying fixed kong.yml to server..."
    copy_to_server "config/kong.yml" "$SERVER_DIR/config/kong.yml"
    print_success "Fixed kong.yml copied to server"
    echo ""
    
    # Step 3: Validate YAML syntax on server
    print_status "3. Validating YAML syntax on server..."
    if execute_remote "python3 -c 'import yaml; yaml.safe_load(open(\"config/kong.yml\"))' >/dev/null 2>&1"; then
        print_success "YAML syntax is valid on server"
    else
        print_error "YAML syntax validation failed on server!"
        execute_remote "python3 -c 'import yaml; yaml.safe_load(open(\"config/kong.yml\"))'"
        return 1
    fi
    echo ""
    
    # Step 4: Stop Kong container
    print_status "4. Stopping Kong container..."
    execute_remote "docker-compose -f docker-compose.server.yml stop kong"
    execute_remote "docker rm -f kong-gateway 2>/dev/null || true"
    print_success "Kong container stopped and removed"
    echo ""
    
    # Step 5: Clean up Docker resources
    print_status "5. Cleaning up Docker resources..."
    execute_remote "docker network prune -f"
    execute_remote "docker volume prune -f"
    print_success "Docker resources cleaned"
    echo ""
    
    # Step 6: Start Kong with fixed configuration
    print_status "6. Starting Kong with fixed configuration..."
    execute_remote "docker-compose -f docker-compose.server.yml up -d kong"
    print_success "Kong container started"
    echo ""
    
    # Step 7: Wait for Kong to be ready
    print_status "7. Waiting for Kong to be ready..."
    sleep 15
    
    # Monitor startup
    for i in {1..30}; do
        print_status "Checking Kong health... (attempt $i/30)"
        
        # Check if container is running
        local container_running=$(sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "cd $SERVER_DIR && docker ps --filter name=kong-gateway --format '{{.Names}}'")
        if [[ -z "$container_running" ]]; then
            print_error "Kong container is not running!"
            execute_remote "docker logs kong-gateway --tail 20"
            return 1
        fi
        
        # Check health endpoint
        local health_check=$(sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "cd $SERVER_DIR && timeout 5 curl -s http://localhost:9546/status 2>/dev/null || echo 'FAILED'")
        if [[ "$health_check" != "FAILED" ]]; then
            print_success "Kong is responding!"
            break
        fi
        
        sleep 3
    done
    echo ""
    
    # Step 8: Final verification
    print_status "8. Final verification..."
    
    # Check Kong status
    execute_remote "curl -s http://localhost:9546/status | jq '.server'"
    
    # Check routes
    local route_count=$(sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "cd $SERVER_DIR && curl -s http://localhost:9546/routes | jq '.data | length'")
    print_success "Kong is running with $route_count routes!"
    
    # Show route details
    print_status "Route details:"
    execute_remote "curl -s http://localhost:9546/routes | jq '.data[].name'"
    
    # Show service details
    print_status "Service details:"
    execute_remote "curl -s http://localhost:9546/services | jq '.data[].name'"
    
    print_success "✅ Kong YAML syntax fixed and deployed successfully!"
}

# Function to show help
show_help() {
    echo "🔧 Fix Kong YAML Syntax Script"
    echo "==============================="
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  fix-and-deploy         - Fix YAML syntax and deploy to Kong"
    echo "  help                   - Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 fix-and-deploy"
}

# Main execution
main() {
    local command="$1"
    
    case "$command" in
        "fix-and-deploy")
            fix_and_deploy
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
