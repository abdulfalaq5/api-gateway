#!/bin/bash

# Fix Kong Host Connection Script
# Script untuk memperbaiki koneksi Kong ke backend services

set -e

echo "🔧 Fix Kong Host Connection Script"
echo "===================================="

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
    sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "cd $SERVER_DIR && $command"
}

# Function to copy file to remote server
copy_to_server() {
    local local_file="$1"
    local remote_file="$2"
    print_status "Copying $local_file to server..."
    sshpass -p "$SERVER_PASS" scp -o StrictHostKeyChecking=no "$local_file" "$SERVER_USER@$SERVER_IP:$remote_file"
}

# Function to diagnose connection issue
diagnose_connection() {
    print_status "🔍 Diagnosing Kong connection to backend services..."
    echo ""
    
    # Check if Kong container is running
    print_status "1. Checking Kong container status..."
    execute_remote "docker ps --filter name=kong-gateway --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
    echo ""
    
    # Check host.docker.internal resolution
    print_status "2. Testing host.docker.internal resolution in Kong..."
    execute_remote "docker exec kong-gateway nslookup host.docker.internal 2>&1 || echo 'host.docker.internal cannot be resolved'"
    echo ""
    
    # Get Docker host IP
    print_status "3. Getting Docker host IP..."
    local docker_host_ip=$(sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "cd $SERVER_DIR && docker network inspect bridge | jq -r '.[0].IPAM.Config[0].Gateway'")
    print_success "Docker host IP: $docker_host_ip"
    echo ""
    
    # Test connection from Kong to host IP
    print_status "4. Testing connection from Kong to host IP ($docker_host_ip)..."
    execute_remote "docker exec kong-gateway sh -c 'nc -zv $docker_host_ip 9550 2>&1' || echo 'Cannot connect to port 9550'"
    execute_remote "docker exec kong-gateway sh -c 'nc -zv $docker_host_ip 9518 2>&1' || echo 'Cannot connect to port 9518'"
    execute_remote "docker exec kong-gateway sh -c 'nc -zv $docker_host_ip 9502 2>&1' || echo 'Cannot connect to port 9502'"
    echo ""
    
    # Check Kong logs for errors
    print_status "5. Checking Kong logs for connection errors..."
    execute_remote "docker logs kong-gateway --tail 20 2>&1 | grep -i 'error\|timeout\|failed' || echo 'No obvious errors found'"
    echo ""
    
    print_success "Diagnosis complete!"
    echo ""
    echo "📊 Summary:"
    echo "  - Docker host IP: $docker_host_ip"
    echo "  - Recommended: Update kong.yml to use $docker_host_ip instead of host.docker.internal"
}

# Function to fix kong.yml with Docker host IP
fix_kong_yml() {
    print_status "🔧 Fixing kong.yml to use Docker host IP..."
    echo ""
    
    # Get Docker host IP from server
    print_status "1. Getting Docker host IP from server..."
    local docker_host_ip=$(sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "docker network inspect bridge | jq -r '.[0].IPAM.Config[0].Gateway'")
    
    if [[ -z "$docker_host_ip" || "$docker_host_ip" == "null" ]]; then
        print_warning "Could not get Docker host IP from bridge network, trying alternative..."
        docker_host_ip=$(sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "ip route | grep default | awk '{print \$3}'")
    fi
    
    if [[ -z "$docker_host_ip" ]]; then
        print_error "Could not determine Docker host IP!"
        return 1
    fi
    
    print_success "Docker host IP: $docker_host_ip"
    echo ""
    
    # Backup current kong.yml
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    print_status "2. Backing up current kong.yml..."
    cp config/kong.yml "config/kong.yml.backup.$timestamp"
    print_success "Backup saved: config/kong.yml.backup.$timestamp"
    echo ""
    
    # Replace host.docker.internal with Docker host IP
    print_status "3. Replacing host.docker.internal with $docker_host_ip in kong.yml..."
    sed -i.tmp "s|host\.docker\.internal|$docker_host_ip|g" config/kong.yml
    rm -f config/kong.yml.tmp
    
    # Show changes
    print_status "4. Verifying changes..."
    grep -n "url: http://$docker_host_ip" config/kong.yml | head -5
    echo ""
    
    print_success "kong.yml updated successfully!"
    echo ""
    
    # Deploy to server
    print_status "5. Deploying updated kong.yml to server..."
    copy_to_server "config/kong.yml" "$SERVER_DIR/config/kong.yml"
    print_success "Deployed to server"
    echo ""
    
    # Restart Kong
    print_status "6. Restarting Kong to apply changes..."
    execute_remote "docker-compose -f docker-compose.server.yml restart kong"
    sleep 10
    print_success "Kong restarted"
    echo ""
    
    # Verify Kong is running
    print_status "7. Verifying Kong status..."
    execute_remote "curl -s http://localhost:9546/status | jq '.server'"
    echo ""
    
    print_success "✅ Kong configuration updated with Docker host IP!"
    echo ""
    echo "🧪 Test with:"
    echo "  curl -v http://localhost:9545/api/catalogs/categories/get -H 'Content-Type: application/json' -d '{}'"
}

# Function to add extra_hosts to docker-compose
add_extra_hosts() {
    print_status "🔧 Adding extra_hosts to docker-compose.server.yml..."
    echo ""
    
    # Backup docker-compose
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    execute_remote "cp docker-compose.server.yml docker-compose.server.yml.backup.$timestamp"
    print_success "Backup saved on server"
    echo ""
    
    # Check if extra_hosts already exists
    local has_extra_hosts=$(sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "cd $SERVER_DIR && grep -c 'extra_hosts:' docker-compose.server.yml || echo '0'")
    
    if [[ "$has_extra_hosts" -gt 0 ]]; then
        print_success "extra_hosts already configured in docker-compose.server.yml"
        execute_remote "grep -A 1 'extra_hosts:' docker-compose.server.yml"
    else
        print_warning "extra_hosts not found, it should already be there"
        print_status "Checking docker-compose.server.yml content..."
        execute_remote "tail -10 docker-compose.server.yml"
    fi
    
    echo ""
    print_success "Docker compose configuration verified"
}

# Function to show help
show_help() {
    echo "🔧 Fix Kong Host Connection Script"
    echo "===================================="
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  diagnose              - Diagnose Kong connection issues"
    echo "  fix-yml               - Fix kong.yml to use Docker host IP"
    echo "  add-extra-hosts       - Add extra_hosts to docker-compose"
    echo "  help                  - Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 diagnose"
    echo "  $0 fix-yml"
}

# Main execution
main() {
    local command="$1"
    
    case "$command" in
        "diagnose")
            diagnose_connection
            ;;
        "fix-yml")
            fix_kong_yml
            ;;
        "add-extra-hosts")
            add_extra_hosts
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

