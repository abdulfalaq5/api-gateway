#!/bin/bash

# Deploy Kong Routes Script
# Script untuk deploy perubahan kong.yml ke server dengan mudah

set -e

echo "🚀 Deploy Kong Routes Script"
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
    
    # Check for host.docker.internal (should be localhost for host network mode)
    local has_docker_internal=$(grep -c "host\.docker\.internal" config/kong.yml || echo "0")
    if [[ "$has_docker_internal" -gt 0 ]]; then
        print_warning "Found 'host.docker.internal' in kong.yml"
        print_warning "With network_mode: host, you should use 'localhost' instead"
        echo ""
        print_status "Fixing automatically..."
        sed -i.tmp 's|http://host\.docker\.internal:|http://localhost:|g' config/kong.yml
        rm -f config/kong.yml.tmp
        print_success "Replaced host.docker.internal → localhost"
    fi
    
    # Count routes and services
    local route_count=$(grep -c "name:.*-route" config/kong.yml || echo "0")
    local service_count=$(grep -c "name:.*-service" config/kong.yml || echo "0")
    
    print_success "Found $service_count services and $route_count routes"
    echo ""
}

# Function to deploy kong.yml
deploy() {
    print_status "📦 Deploying kong.yml to server..."
    echo ""
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    
    # Step 1: Validate local file
    print_status "Step 1: Validating local kong.yml..."
    validate_local || return 1
    echo ""
    
    # Step 2: Backup remote file
    print_status "Step 2: Backing up remote kong.yml..."
    execute_remote "cp config/kong.yml config/kong.yml.backup.$timestamp"
    print_success "Backup saved: config/kong.yml.backup.$timestamp"
    echo ""
    
    # Step 3: Copy to server
    print_status "Step 3: Copying kong.yml to server..."
    copy_to_server "config/kong.yml" "$SERVER_DIR/config/kong.yml"
    print_success "File copied to server"
    echo ""
    
    # Step 4: Validate on server
    print_status "Step 4: Validating kong.yml on server..."
    if execute_remote "python3 -c 'import yaml; yaml.safe_load(open(\"config/kong.yml\"))' 2>&1"; then
        print_success "YAML is valid on server ✓"
    else
        print_error "YAML validation failed on server!"
        print_status "Rolling back..."
        execute_remote "cp config/kong.yml.backup.$timestamp config/kong.yml"
        return 1
    fi
    echo ""
    
    # Step 5: Reload Kong (declarative config hot reload)
    print_status "Step 5: Reloading Kong configuration..."
    
    # Try hot reload first (faster)
    print_status "Attempting hot reload..."
    if execute_remote "curl -s -X POST http://localhost:9546/config -F config=@config/kong.yml 2>&1"; then
        print_success "Hot reload successful! ✓"
        sleep 2
    else
        print_warning "Hot reload failed, restarting container..."
        execute_remote "docker restart kong-gateway"
        sleep 15
        print_success "Container restarted"
    fi
    echo ""
    
    # Step 6: Verify Kong is healthy
    print_status "Step 6: Verifying Kong health..."
    for i in {1..20}; do
        if execute_remote "curl -s http://localhost:9546/status >/dev/null 2>&1"; then
            print_success "Kong is healthy! ✓"
            break
        fi
        echo -n "."
        sleep 2
    done
    echo ""
    echo ""
    
    # Step 7: Show current routes
    print_status "Step 7: Current routes on server:"
    execute_remote "curl -s http://localhost:9546/routes | jq '.data | length' | xargs echo 'Total routes:'"
    echo ""
    
    execute_remote "curl -s http://localhost:9546/routes | jq -r '.data[] | \"  - \" + .name' | head -10"
    echo "  ..."
    echo ""
    
    print_success "✅ Deployment completed successfully!"
    echo ""
    echo "🧪 Test your routes:"
    echo "  curl -v http://localhost:9545/api/your-endpoint"
}

# Function to show diff
show_diff() {
    print_status "📊 Comparing local and remote kong.yml..."
    echo ""
    
    # Get remote file
    print_status "Fetching remote kong.yml..."
    sshpass -p "$SERVER_PASS" scp -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP:$SERVER_DIR/config/kong.yml" /tmp/kong.yml.remote
    
    # Show diff
    print_status "Differences (local vs remote):"
    echo ""
    diff -u /tmp/kong.yml.remote config/kong.yml || true
    
    # Cleanup
    rm -f /tmp/kong.yml.remote
    echo ""
}

# Function to pull from server
pull() {
    print_status "⬇️  Pulling kong.yml from server..."
    echo ""
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    
    # Backup local file
    if [[ -f "config/kong.yml" ]]; then
        cp config/kong.yml "config/kong.yml.backup.$timestamp"
        print_success "Local backup saved: config/kong.yml.backup.$timestamp"
    fi
    
    # Pull from server
    sshpass -p "$SERVER_PASS" scp -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP:$SERVER_DIR/config/kong.yml" config/kong.yml
    
    print_success "✅ kong.yml pulled from server"
    echo ""
    
    # Show info
    local route_count=$(grep -c "name:.*-route" config/kong.yml || echo "0")
    local service_count=$(grep -c "name:.*-service" config/kong.yml || echo "0")
    print_status "Downloaded config has $service_count services and $route_count routes"
}

# Function to check status
check_status() {
    print_status "📊 Checking Kong status on server..."
    echo ""
    
    # Kong health
    print_status "Kong Health:"
    execute_remote "curl -s http://localhost:9546/status | jq '.'"
    echo ""
    
    # Routes count
    print_status "Routes:"
    execute_remote "curl -s http://localhost:9546/routes | jq '.data | length' | xargs echo 'Total:'"
    echo ""
    
    # Services count
    print_status "Services:"
    execute_remote "curl -s http://localhost:9546/services | jq '.data | length' | xargs echo 'Total:'"
    echo ""
    
    # Container status
    print_status "Container Status:"
    execute_remote "docker ps --filter name=kong-gateway --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
    echo ""
}

# Function to test route
test_route() {
    local route_path="$1"
    
    if [[ -z "$route_path" ]]; then
        print_error "Please provide route path!"
        echo "Usage: $0 test <route-path>"
        echo "Example: $0 test /api/catalogs/categories/get"
        return 1
    fi
    
    print_status "🧪 Testing route: $route_path"
    echo ""
    
    execute_remote "curl -v http://localhost:9545$route_path -H 'Content-Type: application/json' -d '{}'"
}

# Function to show help
show_help() {
    echo "🚀 Deploy Kong Routes Script"
    echo "============================="
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  deploy              - Deploy local kong.yml to server"
    echo "  pull                - Pull kong.yml from server to local"
    echo "  diff                - Show differences between local and remote"
    echo "  status              - Check Kong status on server"
    echo "  test <path>         - Test a specific route"
    echo "  validate            - Validate local kong.yml"
    echo "  help                - Show this help"
    echo ""
    echo "Workflow Examples:"
    echo ""
    echo "  # Edit kong.yml locally, then deploy"
    echo "  vim config/kong.yml"
    echo "  $0 deploy"
    echo ""
    echo "  # Pull changes from server"
    echo "  $0 pull"
    echo ""
    echo "  # Check what changed before deploying"
    echo "  $0 diff"
    echo "  $0 deploy"
    echo ""
    echo "  # Test a route"
    echo "  $0 test /api/catalogs/categories/get"
    echo ""
}

# Main execution
main() {
    local command="$1"
    
    case "$command" in
        "deploy")
            deploy
            ;;
        "pull")
            pull
            ;;
        "diff")
            show_diff
            ;;
        "status")
            check_status
            ;;
        "test")
            test_route "$2"
            ;;
        "validate")
            validate_local
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

main "$@"

