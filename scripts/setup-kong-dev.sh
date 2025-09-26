#!/bin/bash

# Script untuk setup Kong API Gateway di environment develop dengan Docker
# File: scripts/setup-kong-dev.sh

set -e

# Colors untuk output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Helper functions
print_header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}================================${NC}"
}

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

# Function untuk cek prerequisites
check_prerequisites() {
    print_header "🔍 Checking Prerequisites"
    
    # Cek Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker tidak terinstall. Silakan install Docker terlebih dahulu."
        exit 1
    fi
    print_success "Docker terinstall"
    
    # Cek Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose tidak terinstall. Silakan install Docker Compose terlebih dahulu."
        exit 1
    fi
    print_success "Docker Compose terinstall"
    
    # Cek apakah Docker daemon berjalan
    if ! docker info &> /dev/null; then
        print_error "Docker daemon tidak berjalan. Silakan jalankan Docker Desktop terlebih dahulu."
        echo "   Atau jalankan: sudo systemctl start docker (Linux)"
        echo "   Atau jalankan: open -a Docker (macOS)"
        exit 1
    fi
    print_success "Docker daemon berjalan"
    
    # Cek curl
    if ! command -v curl &> /dev/null; then
        print_error "curl tidak terinstall. Silakan install curl terlebih dahulu."
        exit 1
    fi
    print_success "curl terinstall"
    
    # Cek jq (optional)
    if ! command -v jq &> /dev/null; then
        print_warning "jq tidak terinstall. Install untuk output yang lebih baik:"
        echo "   - Ubuntu/Debian: sudo apt-get install jq"
        echo "   - macOS: brew install jq"
        echo "   - CentOS/RHEL: sudo yum install jq"
    else
        print_success "jq terinstall"
    fi
}

# Function untuk cleanup existing containers
cleanup_existing() {
    print_header "🧹 Cleaning Up Existing Containers"
    
    print_status "Stopping existing Kong containers..."
    docker-compose -f docker-compose.dev.yml down 2>/dev/null || true
    docker-compose -f docker-compose.yml down 2>/dev/null || true
    docker-compose -f docker-compose.server.yml down 2>/dev/null || true
    
    print_status "Removing existing Kong containers..."
    docker rm -f kong-gateway kong-gateway-dev kong-postgres-dev 2>/dev/null || true
    
    print_status "Cleaning Docker networks..."
    docker network prune -f
    
    print_success "Cleanup completed"
}

# Function untuk setup environment
setup_environment() {
    print_header "⚙️  Setting Up Environment"
    
    # Buat direktori logs jika belum ada
    if [ ! -d "logs" ]; then
        print_status "Creating logs directory..."
        mkdir -p logs
        print_success "Logs directory created"
    else
        print_success "Logs directory already exists"
    fi
    
    # Cek konfigurasi Kong
    if [ ! -f "config/kong.yml" ]; then
        print_error "File config/kong.yml tidak ditemukan!"
        print_status "Pastikan file konfigurasi Kong ada di config/kong.yml"
        exit 1
    fi
    print_success "Kong configuration file found"
    
    # Validasi syntax kong.yml
    print_status "Validating Kong configuration syntax..."
    if command -v kong &> /dev/null; then
        if kong config -c config/kong.yml parse 2>/dev/null; then
            print_success "Kong configuration syntax is valid"
        else
            print_warning "Cannot validate Kong configuration syntax (kong binary not available)"
        fi
    else
        print_warning "Kong binary not available for syntax validation"
    fi
}

# Function untuk start Kong
start_kong() {
    print_header "🚀 Starting Kong API Gateway"
    
    print_status "Starting Kong with development configuration..."
    docker-compose -f docker-compose.dev.yml up -d kong
    
    print_status "Waiting for Kong to start..."
    sleep 15
    
    # Cek apakah container berjalan
    if ! docker ps | grep -q kong-gateway-dev; then
        print_error "Kong container failed to start"
        print_status "Docker Compose logs:"
        docker-compose -f docker-compose.dev.yml logs kong
        exit 1
    fi
    print_success "Kong container is running"
}

# Function untuk health check
health_check() {
    print_header "🏥 Health Check"
    
    # Tunggu Kong siap
    print_status "Waiting for Kong to become healthy..."
    health_attempts=0
    max_attempts=30
    
    while [[ $health_attempts -lt $max_attempts ]]; do
        if curl -s http://localhost:9546/status > /dev/null 2>&1; then
            print_success "Kong is healthy and responding"
            break
        fi
        
        print_status "Waiting for Kong health check... (attempt $((health_attempts + 1))/$max_attempts)"
        sleep 2
        ((health_attempts++))
    done
    
    if [[ $health_attempts -eq $max_attempts ]]; then
        print_error "Kong failed to become healthy"
        print_status "Kong logs:"
        docker logs kong-gateway-dev --tail 20
        exit 1
    fi
    
    # Test endpoints
    print_status "Testing Kong endpoints..."
    
    # Test Admin API
    if curl -s http://localhost:9546/ > /dev/null 2>&1; then
        print_success "Admin API is accessible"
    else
        print_warning "Admin API test failed"
    fi
    
    # Test Proxy
    if curl -s http://localhost:9545/ > /dev/null 2>&1; then
        print_success "Proxy is accessible"
    else
        print_warning "Proxy test failed"
    fi
    
    # Test Admin GUI
    if curl -s http://localhost:9547/ > /dev/null 2>&1; then
        print_success "Admin GUI is accessible"
    else
        print_warning "Admin GUI test failed"
    fi
}

# Function untuk show configuration
show_configuration() {
    print_header "📋 Configuration Summary"
    
    print_status "Kong Services:"
    if command -v jq &> /dev/null; then
        services=$(curl -s http://localhost:9546/services 2>/dev/null)
        if [ $? -eq 0 ]; then
            service_count=$(echo "$services" | jq '.data | length' 2>/dev/null || echo "0")
            if [ "$service_count" -gt 0 ]; then
                echo "$services" | jq -r '.data[] | "  - \(.name): \(.host):\(.port)"' 2>/dev/null
            else
                print_warning "No services configured"
            fi
        else
            print_warning "Cannot retrieve services"
        fi
    else
        print_warning "jq not available for pretty output"
        curl -s http://localhost:9546/services 2>/dev/null || print_warning "Cannot retrieve services"
    fi
    
    print_status "Kong Routes:"
    if command -v jq &> /dev/null; then
        routes=$(curl -s http://localhost:9546/routes 2>/dev/null)
        if [ $? -eq 0 ]; then
            route_count=$(echo "$routes" | jq '.data | length' 2>/dev/null || echo "0")
            if [ "$route_count" -gt 0 ]; then
                echo "$routes" | jq -r '.data[] | "  - \(.name): \(.paths[] // "N/A")"' 2>/dev/null
            else
                print_warning "No routes configured"
            fi
        else
            print_warning "Cannot retrieve routes"
        fi
    else
        print_warning "jq not available for pretty output"
        curl -s http://localhost:9546/routes 2>/dev/null || print_warning "Cannot retrieve routes"
    fi
    
    print_status "Kong Plugins:"
    if command -v jq &> /dev/null; then
        plugins=$(curl -s http://localhost:9546/plugins 2>/dev/null)
        if [ $? -eq 0 ]; then
            plugin_count=$(echo "$plugins" | jq '.data | length' 2>/dev/null || echo "0")
            if [ "$plugin_count" -gt 0 ]; then
                echo "$plugins" | jq -r '.data[] | "  - \(.name)"' 2>/dev/null
            else
                print_warning "No plugins configured"
            fi
        else
            print_warning "Cannot retrieve plugins"
        fi
    else
        print_warning "jq not available for pretty output"
        curl -s http://localhost:9546/plugins 2>/dev/null || print_warning "Cannot retrieve plugins"
    fi
}

# Function untuk show usage information
show_usage() {
    print_header "📖 Usage Information"
    
    echo -e "${GREEN}Kong API Gateway is now running in development mode!${NC}"
    echo ""
    echo "📍 Endpoints:"
    echo "   - Kong Proxy:     http://localhost:9545"
    echo "   - Kong Admin API: http://localhost:9546"
    echo "   - Kong Admin GUI: http://localhost:9547"
    echo ""
    echo "🧪 Test Commands:"
    echo "   # Test Kong health"
    echo "   curl http://localhost:9546/status"
    echo ""
    echo "   # Test SSO endpoint (jika dikonfigurasi)"
    echo "   curl -X POST http://localhost:9545/api/auth/sso/login \\"
    echo "     -H \"Content-Type: application/json\" \\"
    echo "     -d '{\"email\": \"admin@sso-testing.com\", \"password\": \"admin123\", \"client_id\": \"string\", \"redirect_uri\": \"string\"}'"
    echo ""
    echo "   # List all services"
    echo "   curl http://localhost:9546/services"
    echo ""
    echo "   # List all routes"
    echo "   curl http://localhost:9546/routes"
    echo ""
    echo "🔧 Management Commands:"
    echo "   # View logs"
    echo "   docker-compose -f docker-compose.dev.yml logs -f kong"
    echo ""
    echo "   # Stop Kong"
    echo "   docker-compose -f docker-compose.dev.yml down"
    echo ""
    echo "   # Restart Kong"
    echo "   docker-compose -f docker-compose.dev.yml restart kong"
    echo ""
    echo "   # Start with database (PostgreSQL)"
    echo "   docker-compose -f docker-compose.dev.yml --profile database up -d"
    echo ""
    echo "📊 Monitoring:"
    echo "   # Container status"
    echo "   docker ps | grep kong"
    echo ""
    echo "   # Resource usage"
    echo "   docker stats kong-gateway-dev"
    echo ""
    echo "📁 Configuration:"
    echo "   - Kong config: config/kong.yml"
    echo "   - Docker config: docker-compose.dev.yml"
    echo "   - Logs: logs/ directory"
    echo ""
}

# Function untuk test endpoints
test_endpoints() {
    print_header "🧪 Testing Endpoints"
    
    # Test basic connectivity
    print_status "Testing basic connectivity..."
    
    # Test Kong proxy
    if curl -s --connect-timeout 5 http://localhost:9545/ > /dev/null 2>&1; then
        print_success "Kong proxy is responding"
    else
        print_warning "Kong proxy test failed"
    fi
    
    # Test Admin API
    if curl -s --connect-timeout 5 http://localhost:9546/ > /dev/null 2>&1; then
        print_success "Admin API is responding"
    else
        print_warning "Admin API test failed"
    fi
    
    # Test specific endpoints jika ada
    print_status "Testing configured endpoints..."
    
    # Test SSO endpoint jika ada
    if curl -s --connect-timeout 10 -X POST http://localhost:9545/api/auth/sso/login \
      -H "Content-Type: application/json" \
      -d '{"email":"admin@sso-testing.com","password":"admin123","client_id":"string","redirect_uri":"string"}' > /dev/null 2>&1; then
        print_success "SSO endpoint is working"
    else
        print_warning "SSO endpoint timeout (check if SSO service is accessible)"
    fi
}

# Main execution
main() {
    print_header "🚀 Kong API Gateway - Development Setup"
    
    # Parse command line arguments
    SKIP_CLEANUP=false
    SKIP_TESTS=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-cleanup)
                SKIP_CLEANUP=true
                shift
                ;;
            --skip-tests)
                SKIP_TESTS=true
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --skip-cleanup    Skip cleanup of existing containers"
                echo "  --skip-tests      Skip endpoint testing"
                echo "  --help           Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Execute setup steps
    check_prerequisites
    
    if [ "$SKIP_CLEANUP" = false ]; then
        cleanup_existing
    fi
    
    setup_environment
    start_kong
    health_check
    
    if [ "$SKIP_TESTS" = false ]; then
        test_endpoints
    fi
    
    show_configuration
    show_usage
    
    print_success "✅ Kong API Gateway development setup completed successfully!"
}

# Run main function
main "$@"
