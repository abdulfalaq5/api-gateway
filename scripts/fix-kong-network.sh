#!/bin/bash

# Fix Kong Network Connection Script
# Script untuk memperbaiki koneksi Kong ke backend menggunakan network_mode: host

set -e

echo "🔧 Fix Kong Network Connection"
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

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

execute_remote() {
    sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "cd $SERVER_DIR && $1"
}

copy_to_server() {
    sshpass -p "$SERVER_PASS" scp -o StrictHostKeyChecking=no "$1" "$SERVER_USER@$SERVER_IP:$2"
}

# Function to fix using network_mode: host
fix_with_host_network() {
    print_status "🔧 Fixing Kong with network_mode: host..."
    echo ""
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    
    # Step 1: Update kong.yml - ganti host.docker.internal dengan localhost
    print_status "1. Updating kong.yml to use localhost..."
    cp config/kong.yml "config/kong.yml.backup.$timestamp"
    
    sed -i.tmp 's|http://host\.docker\.internal:|http://localhost:|g' config/kong.yml
    rm -f config/kong.yml.tmp
    
    print_success "kong.yml updated:"
    grep -n "url: http://localhost:" config/kong.yml | head -5
    echo ""
    
    # Step 2: Update docker-compose.server.yml - tambah network_mode: host
    print_status "2. Updating docker-compose.server.yml with network_mode: host..."
    cp docker-compose.server.yml "docker-compose.server.yml.backup.$timestamp"
    
    # Create updated docker-compose
    cat > docker-compose.server.yml << 'EOF'
services:
  kong:
    image: kong:3.4
    container_name: kong-gateway
    network_mode: host
    environment:
      # Use db-less mode for server deployment
      KONG_DATABASE: "off"
      KONG_DECLARATIVE_CONFIG: /kong/kong.yml
      # Listen addresses (dengan host network, bind ke host directly)
      KONG_PROXY_LISTEN: 0.0.0.0:9545
      KONG_ADMIN_LISTEN: 0.0.0.0:9546
      KONG_ADMIN_GUI_LISTEN: 0.0.0.0:9547
      # Logging
      KONG_PROXY_ACCESS_LOG: /dev/stdout
      KONG_ADMIN_ACCESS_LOG: /dev/stdout
      KONG_PROXY_ERROR_LOG: /dev/stderr
      KONG_ADMIN_ERROR_LOG: /dev/stderr
      KONG_ADMIN_GUI_ERROR_LOG: /dev/stderr
      # Timeout settings
      KONG_PROXY_CONNECT_TIMEOUT: 60000
      KONG_PROXY_SEND_TIMEOUT: 60000
      KONG_PROXY_READ_TIMEOUT: 60000
      KONG_UPSTREAM_CONNECT_TIMEOUT: 60000
      KONG_UPSTREAM_SEND_TIMEOUT: 60000
      KONG_UPSTREAM_READ_TIMEOUT: 60000
      # DNS Configuration
      KONG_DNS_RESOLVER: "8.8.8.8:53,8.8.4.4:53,1.1.1.1:53"
      KONG_DNS_ORDER: "LAST,A,CNAME"
    volumes:
      - ./config/kong.yml:/kong/kong.yml:ro
      - ./config/resolv.conf:/etc/resolv.conf:ro
    healthcheck:
      test: ["CMD", "kong", "health"]
      interval: 10s
      timeout: 10s
      retries: 10
    restart: unless-stopped
EOF
    
    print_success "docker-compose.server.yml updated with network_mode: host"
    echo ""
    
    # Step 3: Deploy ke server
    print_status "3. Deploying to server..."
    copy_to_server "config/kong.yml" "$SERVER_DIR/config/kong.yml"
    copy_to_server "docker-compose.server.yml" "$SERVER_DIR/docker-compose.server.yml"
    print_success "Files deployed to server"
    echo ""
    
    # Step 4: Restart Kong
    print_status "4. Stopping Kong container..."
    execute_remote "docker-compose -f docker-compose.server.yml down"
    sleep 3
    
    print_status "5. Starting Kong with host network mode..."
    execute_remote "docker-compose -f docker-compose.server.yml up -d"
    sleep 15
    
    print_status "6. Checking Kong container status..."
    execute_remote "docker ps --filter name=kong-gateway --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
    echo ""
    
    # Step 5: Wait for Kong to be ready
    print_status "7. Waiting for Kong to be ready..."
    for i in {1..20}; do
        sleep 3
        if execute_remote "curl -s http://localhost:9546/status >/dev/null 2>&1"; then
            print_success "Kong is ready!"
            break
        fi
        echo -n "."
    done
    echo ""
    echo ""
    
    # Step 6: Test connection
    print_status "8. Testing Kong connection to backend..."
    
    print_status "Kong status:"
    execute_remote "curl -s http://localhost:9546/status | jq '.server'"
    echo ""
    
    print_status "Testing backend connection through Kong:"
    execute_remote "timeout 10 curl -s http://localhost:9545/api/catalogs/categories/get -H 'Content-Type: application/json' -d '{}' | head -c 200 || echo 'Request completed'"
    echo ""
    echo ""
    
    print_success "✅ Kong configuration updated!"
    echo ""
    echo "📊 Changes made:"
    echo "  ✅ kong.yml: host.docker.internal → localhost"
    echo "  ✅ docker-compose.server.yml: Added network_mode: host"
    echo "  ✅ Kong restarted with host network mode"
    echo ""
    echo "🧪 Test from server:"
    echo "  curl -v http://localhost:9545/api/catalogs/categories/get -H 'Content-Type: application/json' -d '{}'"
    echo ""
    echo "💡 Benefit: Kong sekarang di host network, bisa akses localhost backend langsung!"
}

# Function to check port bindings
check_ports() {
    print_status "🔍 Checking backend service port bindings on server..."
    echo ""
    
    execute_remote "sudo netstat -tlnp | grep -E '9518|9550|9502|9544' || echo 'No ports found'"
    echo ""
    
    print_status "✅ Check complete"
}

show_help() {
    echo "🔧 Fix Kong Network Connection"
    echo "==============================="
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  fix                - Fix Kong with network_mode: host"
    echo "  check-ports        - Check backend port bindings"
    echo "  help               - Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 fix"
    echo "  $0 check-ports"
}

main() {
    case "$1" in
        "fix")
            fix_with_host_network
            ;;
        "check-ports")
            check_ports
            ;;
        "help"|"")
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"

