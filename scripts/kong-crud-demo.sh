#!/bin/bash

# Kong DB-LESS CRUD Demo Script
# Script demo untuk CRUD operations di Kong dengan DB-less mode

set -e

echo "🎯 Kong DB-LESS CRUD Demo Script"
echo "================================"

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

# Function to demo CREATE operation
demo_create() {
    print_status "=== DEMO: CREATE Service & Route ==="
    
    # Backup current config
    print_status "1. Backing up current config..."
    execute_remote "cp config/kong.yml config/kong_backup_$(date +%Y%m%d_%H%M%S).yml"
    
    # Create new service in kong.yml
    print_status "2. Adding new service to kong.yml..."
    
    # Read current kong.yml and add new service
    local temp_file=$(mktemp)
    cat config/kong.yml > "$temp_file"
    
    # Add new service
    cat >> "$temp_file" << 'EOF'

  - name: demo-service
    url: http://demo-backend:3000
    connect_timeout: 60000
    write_timeout: 60000
    read_timeout: 60000
    routes:
      - name: demo-routes
        paths:
          - /api/demo
        methods:
          - GET
          - POST
          - PUT
          - DELETE
        strip_path: true
    plugins:
      - name: rate-limiting
        config:
          minute: 50
          hour: 500
          policy: local
EOF
    
    # Replace original file
    mv "$temp_file" config/kong.yml
    
    # Copy to server
    copy_to_server "config/kong.yml" "$SERVER_DIR/config/kong.yml"
    
    # Restart Kong
    print_status "3. Restarting Kong..."
    execute_remote "docker-compose -f docker-compose.server.yml restart kong"
    
    # Wait for Kong to be ready
    sleep 15
    
    # Verify creation
    print_status "4. Verifying creation..."
    execute_remote "curl -s http://localhost:9546/routes | jq '.data[] | select(.name == \"demo-routes\") | {name: .name, paths: .paths, methods: .methods}'"
    
    print_success "✅ CREATE operation completed!"
}

# Function to demo READ operation
demo_read() {
    print_status "=== DEMO: READ Services & Routes ==="
    
    # List all services
    print_status "1. Listing all services..."
    execute_remote "curl -s http://localhost:9546/services | jq '.data[] | {name: .name, url: .url, created_at: .created_at}'"
    
    # List all routes
    print_status "2. Listing all routes..."
    execute_remote "curl -s http://localhost:9546/routes | jq '.data[] | {name: .name, paths: .paths, methods: .methods, service: .service.name}'"
    
    # Detail specific service
    print_status "3. Detail of demo-service..."
    execute_remote "curl -s http://localhost:9546/services/demo-service | jq '.'"
    
    print_success "✅ READ operation completed!"
}

# Function to demo UPDATE operation
demo_update() {
    print_status "=== DEMO: UPDATE Service & Route ==="
    
    # Update service URL
    print_status "1. Updating service URL..."
    execute_remote "curl -X PATCH http://localhost:9546/services/demo-service -H 'Content-Type: application/json' -d '{\"url\": \"http://updated-demo-backend:3000\"}'"
    
    # Update route path
    print_status "2. Updating route path..."
    execute_remote "curl -X PATCH http://localhost:9546/routes/demo-routes -H 'Content-Type: application/json' -d '{\"paths\": [\"/api/updated-demo\"], \"methods\": [\"GET\", \"POST\", \"PUT\", \"DELETE\", \"PATCH\"]}'"
    
    # Verify updates
    print_status "3. Verifying updates..."
    execute_remote "curl -s http://localhost:9546/services/demo-service | jq '.url'"
    execute_remote "curl -s http://localhost:9546/routes/demo-routes | jq '{paths: .paths, methods: .methods}'"
    
    print_success "✅ UPDATE operation completed!"
}

# Function to demo DELETE operation
demo_delete() {
    print_status "=== DEMO: DELETE Service & Route ==="
    
    # Delete route first (due to dependency)
    print_status "1. Deleting route..."
    execute_remote "curl -X DELETE http://localhost:9546/routes/demo-routes"
    
    # Delete service
    print_status "2. Deleting service..."
    execute_remote "curl -X DELETE http://localhost:9546/services/demo-service"
    
    # Verify deletion
    print_status "3. Verifying deletion..."
    execute_remote "curl -s http://localhost:9546/routes | jq '.data[] | select(.name == \"demo-routes\")'"
    execute_remote "curl -s http://localhost:9546/services | jq '.data[] | select(.name == \"demo-service\")'"
    
    print_success "✅ DELETE operation completed!"
}

# Function to demo kong.yml management
demo_kong_yml() {
    print_status "=== DEMO: kong.yml Management ==="
    
    # Show current kong.yml
    print_status "1. Current kong.yml content..."
    execute_remote "echo '--- Current kong.yml ---' && cat config/kong.yml | head -20"
    
    # Add service to kong.yml
    print_status "2. Adding service to kong.yml..."
    
    # Create temporary file with new service
    local temp_file=$(mktemp)
    cat config/kong.yml > "$temp_file"
    
    # Add new service
    cat >> "$temp_file" << 'EOF'

  - name: yml-demo-service
    url: http://yml-backend:3000
    connect_timeout: 60000
    write_timeout: 60000
    read_timeout: 60000
    routes:
      - name: yml-demo-routes
        paths:
          - /api/yml-demo
        methods:
          - GET
          - POST
        strip_path: true
EOF
    
    # Replace original file
    mv "$temp_file" config/kong.yml
    
    # Copy to server
    copy_to_server "config/kong.yml" "$SERVER_DIR/config/kong.yml"
    
    # Restart Kong
    print_status "3. Restarting Kong with new config..."
    execute_remote "docker-compose -f docker-compose.server.yml restart kong"
    
    # Wait for Kong to be ready
    sleep 15
    
    # Verify
    print_status "4. Verifying kong.yml deployment..."
    execute_remote "curl -s http://localhost:9546/routes | jq '.data[] | select(.name == \"yml-demo-routes\") | {name: .name, paths: .paths, methods: .methods}'"
    
    print_success "✅ kong.yml management completed!"
}

# Function to demo testing endpoints
demo_test_endpoints() {
    print_status "=== DEMO: Testing Endpoints ==="
    
    # Test Kong directly
    print_status "1. Testing Kong directly..."
    execute_remote "curl -s -X GET http://localhost:9545/api/yml-demo | head -c 100"
    
    # Test through Nginx
    print_status "2. Testing through Nginx..."
    execute_remote "curl -s -X GET https://localhost/api/yml-demo -k | head -c 100"
    
    # Test external endpoint
    print_status "3. Testing external endpoint..."
    curl -s -X GET "https://services.motorsights.com/api/yml-demo" | head -c 100
    
    print_success "✅ Endpoint testing completed!"
}

# Function to show help
show_help() {
    echo "🎯 Kong DB-LESS CRUD Demo Script"
    echo "================================"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  create      - Demo CREATE operation"
    echo "  read        - Demo READ operation"
    echo "  update      - Demo UPDATE operation"
    echo "  delete      - Demo DELETE operation"
    echo "  kong-yml    - Demo kong.yml management"
    echo "  test        - Demo endpoint testing"
    echo "  full        - Run all demos"
    echo ""
    echo "Examples:"
    echo "  $0 create"
    echo "  $0 full"
}

# Main execution
main() {
    local command="$1"
    
    case "$command" in
        "create")
            demo_create
            ;;
        "read")
            demo_read
            ;;
        "update")
            demo_update
            ;;
        "delete")
            demo_delete
            ;;
        "kong-yml")
            demo_kong_yml
            ;;
        "test")
            demo_test_endpoints
            ;;
        "full")
            demo_create
            echo ""
            demo_read
            echo ""
            demo_update
            echo ""
            demo_delete
            echo ""
            demo_kong_yml
            echo ""
            demo_test_endpoints
            ;;
        *)
            show_help
            ;;
    esac
}

# Run main function
main "$@"
