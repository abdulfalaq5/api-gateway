#!/bin/bash

# Diagnose Kong Hanging Issue Script
# Script untuk mendiagnosis masalah Kong yang terhenti pada health check

set -e

echo "🔍 Diagnose Kong Hanging Issue Script"
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

# Function to execute command on remote server and return output
execute_remote_output() {
    local command="$1"
    sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "cd $SERVER_DIR && $command"
}

# Function to diagnose Kong hanging issue
diagnose_kong_hanging() {
    print_status "🔍 Starting Kong diagnosis..."
    echo ""
    
    # Step 1: Check if Kong container is running
    print_status "1. Checking Kong container status..."
    local container_status=$(execute_remote_output "docker ps -a --filter name=kong-gateway --format '{{.Status}}'")
    echo "Container status: $container_status"
    echo ""
    
    # Step 2: Check Kong container logs
    print_status "2. Checking Kong container logs (last 50 lines)..."
    execute_remote "docker logs kong-gateway --tail 50"
    echo ""
    
    # Step 3: Check if Kong ports are accessible
    print_status "3. Checking Kong port accessibility..."
    
    # Check admin API port
    local admin_check=$(execute_remote_output "curl -s -o /dev/null -w '%{http_code}' http://localhost:9546/status 2>/dev/null || echo 'FAILED'")
    echo "Admin API (9546) response: $admin_check"
    
    # Check proxy port
    local proxy_check=$(execute_remote_output "curl -s -o /dev/null -w '%{http_code}' http://localhost:9545/ 2>/dev/null || echo 'FAILED'")
    echo "Proxy API (9545) response: $proxy_check"
    echo ""
    
    # Step 4: Check Kong configuration file
    print_status "4. Checking Kong configuration file..."
    execute_remote "ls -la config/kong.yml"
    echo ""
    
    # Step 5: Check if kong.yml is valid YAML
    print_status "5. Validating kong.yml syntax..."
    local yaml_check=$(execute_remote_output "python3 -c 'import yaml; yaml.safe_load(open(\"config/kong.yml\"))' 2>&1 || echo 'YAML_ERROR'")
    if [[ "$yaml_check" == "YAML_ERROR" ]]; then
        print_error "kong.yml has YAML syntax errors!"
        execute_remote "python3 -c 'import yaml; yaml.safe_load(open(\"config/kong.yml\"))'"
    else
        print_success "kong.yml syntax is valid"
    fi
    echo ""
    
    # Step 6: Check Docker network
    print_status "6. Checking Docker network..."
    execute_remote "docker network ls | grep api-gateway"
    echo ""
    
    # Step 7: Check system resources
    print_status "7. Checking system resources..."
    execute_remote "free -h"
    execute_remote "df -h /"
    echo ""
    
    # Step 8: Check if Kong process is responsive
    print_status "8. Checking Kong process responsiveness..."
    local kong_pid=$(execute_remote_output "docker exec kong-gateway ps aux | grep kong | grep -v grep | awk '{print \$2}' | head -1")
    if [[ -n "$kong_pid" ]]; then
        echo "Kong process PID: $kong_pid"
        execute_remote "docker exec kong-gateway ps aux | grep kong | grep -v grep"
    else
        print_error "No Kong process found!"
    fi
    echo ""
    
    # Step 9: Check Kong health endpoint directly
    print_status "9. Testing Kong health endpoint directly..."
    execute_remote "timeout 10 curl -v http://localhost:9546/status || echo 'TIMEOUT_OR_ERROR'"
    echo ""
    
    # Step 10: Check if there are any hanging connections
    print_status "10. Checking for hanging connections..."
    execute_remote "netstat -tulpn | grep :9546 || echo 'No connections on port 9546'"
    execute_remote "netstat -tulpn | grep :9545 || echo 'No connections on port 9545'"
    echo ""
}

# Function to fix Kong hanging issue
fix_kong_hanging() {
    print_status "🔧 Attempting to fix Kong hanging issue..."
    echo ""
    
    # Step 1: Force stop and remove Kong container
    print_status "1. Force stopping and removing Kong container..."
    execute_remote "docker stop kong-gateway 2>/dev/null || true"
    execute_remote "docker rm -f kong-gateway 2>/dev/null || true"
    echo ""
    
    # Step 2: Clean up networks and volumes
    print_status "2. Cleaning up Docker resources..."
    execute_remote "docker network prune -f"
    execute_remote "docker volume prune -f"
    echo ""
    
    # Step 3: Check and fix kong.yml if needed
    print_status "3. Validating and fixing kong.yml..."
    
    # Backup current config
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    execute_remote "cp config/kong.yml config/kong.yml.backup.$timestamp"
    
    # Check if kong.yml exists and is readable
    if ! execute_remote_output "test -r config/kong.yml"; then
        print_error "kong.yml is not readable!"
        return 1
    fi
    
    # Validate YAML syntax
    if ! execute_remote_output "python3 -c 'import yaml; yaml.safe_load(open(\"config/kong.yml\"))' >/dev/null 2>&1"; then
        print_error "kong.yml has syntax errors!"
        execute_remote "python3 -c 'import yaml; yaml.safe_load(open(\"config/kong.yml\"))'"
        return 1
    fi
    echo ""
    
    # Step 4: Start Kong with verbose logging
    print_status "4. Starting Kong with verbose logging..."
    execute_remote "docker-compose -f docker-compose.server.yml up -d kong"
    echo ""
    
    # Step 5: Wait and monitor startup
    print_status "5. Monitoring Kong startup..."
    for i in {1..30}; do
        print_status "Waiting for Kong... (attempt $i/30)"
        
        # Check if container is running
        local container_running=$(execute_remote_output "docker ps --filter name=kong-gateway --format '{{.Names}}'")
        if [[ -z "$container_running" ]]; then
            print_error "Kong container is not running!"
            execute_remote "docker logs kong-gateway --tail 20"
            return 1
        fi
        
        # Check health endpoint
        local health_check=$(execute_remote_output "timeout 5 curl -s http://localhost:9546/status 2>/dev/null || echo 'FAILED'")
        if [[ "$health_check" != "FAILED" ]]; then
            print_success "Kong is responding!"
            break
        fi
        
        sleep 3
    done
    echo ""
    
    # Step 6: Final verification
    print_status "6. Final verification..."
    execute_remote "curl -s http://localhost:9546/status | jq '.server'"
    
    local route_count=$(execute_remote_output "curl -s http://localhost:9546/routes | jq '.data | length'")
    print_success "Kong is running with $route_count routes!"
}

# Function to show help
show_help() {
    echo "🔍 Diagnose Kong Hanging Issue Script"
    echo "====================================="
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  diagnose              - Diagnose Kong hanging issue"
    echo "  fix                   - Fix Kong hanging issue"
    echo "  help                  - Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 diagnose"
    echo "  $0 fix"
}

# Main execution
main() {
    local command="$1"
    
    case "$command" in
        "diagnose")
            diagnose_kong_hanging
            ;;
        "fix")
            fix_kong_hanging
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
