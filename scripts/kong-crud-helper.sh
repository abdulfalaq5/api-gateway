#!/bin/bash

# Kong CRUD Helper Script
# Script untuk memudahkan CRUD operations di Kong

set -e

echo "🔧 Kong CRUD Helper Script"
echo "=========================="

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

# Function to list all services
list_services() {
    print_status "Listing all services..."
    execute_remote "curl -s http://localhost:9546/services | jq '.data[] | {name: .name, url: .url, created_at: .created_at}'"
}

# Function to list all routes
list_routes() {
    print_status "Listing all routes..."
    execute_remote "curl -s http://localhost:9546/routes | jq '.data[] | {name: .name, paths: .paths, methods: .methods, service: .service.name}'"
}

# Function to create service
create_service() {
    local name="$1"
    local url="$2"
    
    if [[ -z "$name" || -z "$url" ]]; then
        print_error "Usage: create_service <name> <url>"
        return 1
    fi
    
    print_status "Creating service: $name"
    
    local service_json="{
        \"name\": \"$name\",
        \"url\": \"$url\",
        \"connect_timeout\": 60000,
        \"write_timeout\": 60000,
        \"read_timeout\": 60000
    }"
    
    execute_remote "curl -X POST http://localhost:9546/services -H 'Content-Type: application/json' -d '$service_json'"
}

# Function to create route
create_route() {
    local name="$1"
    local service_name="$2"
    local path="$3"
    local methods="$4"
    
    if [[ -z "$name" || -z "$service_name" || -z "$path" ]]; then
        print_error "Usage: create_route <name> <service_name> <path> [methods]"
        return 1
    fi
    
    if [[ -z "$methods" ]]; then
        methods="GET,POST,PUT,DELETE,OPTIONS"
    fi
    
    print_status "Creating route: $name"
    
    local route_json="{
        \"name\": \"$name\",
        \"paths\": [\"$path\"],
        \"methods\": [\"$(echo $methods | tr ',' '\"' | sed 's/,/","/g')\"],
        \"strip_path\": true,
        \"service\": {\"name\": \"$service_name\"}
    }"
    
    execute_remote "curl -X POST http://localhost:9546/routes -H 'Content-Type: application/json' -d '$route_json'"
}

# Function to update service
update_service() {
    local name="$1"
    local url="$2"
    
    if [[ -z "$name" || -z "$url" ]]; then
        print_error "Usage: update_service <name> <url>"
        return 1
    fi
    
    print_status "Updating service: $name"
    
    local service_json="{
        \"url\": \"$url\"
    }"
    
    execute_remote "curl -X PATCH http://localhost:9546/services/$name -H 'Content-Type: application/json' -d '$service_json'"
}

# Function to update route
update_route() {
    local name="$1"
    local path="$2"
    local methods="$3"
    
    if [[ -z "$name" || -z "$path" ]]; then
        print_error "Usage: update_route <name> <path> [methods]"
        return 1
    fi
    
    if [[ -z "$methods" ]]; then
        methods="GET,POST,PUT,DELETE,OPTIONS"
    fi
    
    print_status "Updating route: $name"
    
    local route_json="{
        \"paths\": [\"$path\"],
        \"methods\": [\"$(echo $methods | tr ',' '\"' | sed 's/,/","/g')\"]
    }"
    
    execute_remote "curl -X PATCH http://localhost:9546/routes/$name -H 'Content-Type: application/json' -d '$route_json'"
}

# Function to delete service
delete_service() {
    local name="$1"
    
    if [[ -z "$name" ]]; then
        print_error "Usage: delete_service <name>"
        return 1
    fi
    
    print_status "Deleting service: $name"
    execute_remote "curl -X DELETE http://localhost:9546/services/$name"
}

# Function to delete route
delete_route() {
    local name="$1"
    
    if [[ -z "$name" ]]; then
        print_error "Usage: delete_route <name>"
        return 1
    fi
    
    print_status "Deleting route: $name"
    execute_remote "curl -X DELETE http://localhost:9546/routes/$name"
}

# Function to show help
show_help() {
    echo "🔧 Kong CRUD Helper Script"
    echo "=========================="
    echo ""
    echo "Usage: $0 <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  list-services                    - List all services"
    echo "  list-routes                       - List all routes"
    echo "  create-service <name> <url>       - Create new service"
    echo "  create-route <name> <service> <path> [methods] - Create new route"
    echo "  update-service <name> <url>       - Update service URL"
    echo "  update-route <name> <path> [methods] - Update route"
    echo "  delete-service <name>             - Delete service"
    echo "  delete-route <name>               - Delete route"
    echo ""
    echo "Examples:"
    echo "  $0 list-services"
    echo "  $0 create-service my-api http://backend:3000"
    echo "  $0 create-route my-route my-api /api/users GET,POST"
    echo "  $0 update-service my-api http://new-backend:3000"
    echo "  $0 delete-route my-route"
}

# Main execution
main() {
    local command="$1"
    
    case "$command" in
        "list-services")
            list_services
            ;;
        "list-routes")
            list_routes
            ;;
        "create-service")
            create_service "$2" "$3"
            ;;
        "create-route")
            create_route "$2" "$3" "$4" "$5"
            ;;
        "update-service")
            update_service "$2" "$3"
            ;;
        "update-route")
            update_route "$2" "$3" "$4"
            ;;
        "delete-service")
            delete_service "$2"
            ;;
        "delete-route")
            delete_route "$2"
            ;;
        *)
            show_help
            ;;
    esac
}

# Run main function
main "$@"
