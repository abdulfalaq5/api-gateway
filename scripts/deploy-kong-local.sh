#!/bin/bash

# Deploy Kong Routes Script (Local)
# Script untuk deploy perubahan kong.yml di local environment

set -e

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

# Instance configuration
INSTANCE="${1:-1}"  # Default instance 1

if [ "$INSTANCE" = "1" ]; then
    CONTAINER_NAME="kong-gateway"
    ADMIN_PORT="9546"
    PROXY_PORT="9545"
    COMPOSE_FILE="docker-compose.server.yml"
    PROJECT_NAME="kong-instance1"
elif [ "$INSTANCE" = "2" ]; then
    CONTAINER_NAME="kong-gateway2"
    ADMIN_PORT="9589"
    PROXY_PORT="9588"
    COMPOSE_FILE="docker-compose.server2.yml"
    PROJECT_NAME="kong-instance2"
else
    print_error "Invalid instance number. Use 1 or 2"
    exit 1
fi

# Function to validate kong.yml locally
validate_local() {
    print_status "🔍 Validating kong.yml locally..."
    
    # Check if file exists
    if [[ ! -f "config/kong.yml" ]]; then
        print_error "config/kong.yml not found!"
        return 1
    fi
    
    # Validate YAML syntax
    if command -v python3 &> /dev/null; then
        if python3 -c "import yaml; yaml.safe_load(open('config/kong.yml'))" 2>&1; then
            print_success "YAML syntax is valid ✓"
        else
            print_error "YAML syntax error!"
            return 1
        fi
    else
        print_warning "Python3 not found, skipping YAML validation"
    fi
    
    # Count routes and services
    local route_count=$(grep -c "name:.*-route" config/kong.yml || echo "0")
    local service_count=$(grep -c "name:.*-service" config/kong.yml || echo "0")
    
    print_success "Found $service_count services and $route_count routes"
    echo ""
}

# Function to deploy kong.yml (local)
deploy() {
    print_status "📦 Deploying kong.yml to Instance $INSTANCE (local)..."
    echo ""
    
    # Step 1: Validate local file
    print_status "Step 1: Validating local kong.yml..."
    validate_local || return 1
    echo ""
    
    # Step 2: Check if container is running
    print_status "Step 2: Checking container status..."
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        print_warning "Container $CONTAINER_NAME is not running!"
        print_status "Starting container..."
        docker-compose -p $PROJECT_NAME -f $COMPOSE_FILE up -d
        sleep 10
    else
        print_success "Container $CONTAINER_NAME is running ✓"
    fi
    echo ""
    
    # Step 3: Try hot reload first (faster, no downtime)
    print_status "Step 3: Attempting hot reload (no restart needed)..."
    if curl -s -X POST "http://localhost:$ADMIN_PORT/config" \
        -F "config=@config/kong.yml" >/dev/null 2>&1; then
        print_success "Hot reload successful! ✓ (No restart needed)"
        sleep 2
    else
        print_warning "Hot reload failed, restarting container..."
        docker-compose -p $PROJECT_NAME -f $COMPOSE_FILE restart kong
        sleep 15
        print_success "Container restarted"
    fi
    echo ""
    
    # Step 4: Verify Kong is healthy
    print_status "Step 4: Verifying Kong health..."
    for i in {1..20}; do
        if curl -s "http://localhost:$ADMIN_PORT/status" >/dev/null 2>&1; then
            print_success "Kong is healthy! ✓"
            break
        fi
        echo -n "."
        sleep 2
    done
    echo ""
    echo ""
    
    # Step 5: Show current routes
    print_status "Step 5: Current routes:"
    local route_count=$(curl -s "http://localhost:$ADMIN_PORT/routes" | jq '.data | length' 2>/dev/null || echo "0")
    echo "Total routes: $route_count"
    echo ""
    
    print_success "✅ Deployment completed successfully!"
    echo ""
    echo "🧪 Test your routes:"
    echo "  curl -v http://localhost:$PROXY_PORT/api/your-endpoint"
}

# Function to show help
show_help() {
    echo "🚀 Deploy Kong Routes Script (Local)"
    echo "====================================="
    echo ""
    echo "Usage: $0 [instance]"
    echo ""
    echo "Arguments:"
    echo "  instance    - Instance number (1 or 2), default: 1"
    echo ""
    echo "Examples:"
    echo "  $0           # Deploy to Instance 1 (default)"
    echo "  $0 1         # Deploy to Instance 1"
    echo "  $0 2         # Deploy to Instance 2"
    echo ""
    echo "Workflow:"
    echo "  1. Edit config/kong.yml"
    echo "  2. Run: $0 [instance]"
    echo "  3. Script will try hot reload first (no restart)"
    echo "  4. If hot reload fails, will restart container"
    echo ""
}

# Main execution
main() {
    local command="${2:-deploy}"
    
    case "$command" in
        "deploy"|"")
            deploy
            ;;
        "validate")
            validate_local
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
