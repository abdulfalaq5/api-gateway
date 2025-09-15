#!/bin/bash

# Script untuk memperbaiki masalah umum Kong di Server
# Script ini akan mencoba berbagai solusi untuk masalah yang umum terjadi

set -e

echo "🔧 Kong API Gateway - Server Issue Fixer"
echo "========================================"
echo ""

# Get server info
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "🖥️  Server IP: $SERVER_IP"
echo ""

# Function untuk test port
test_port() {
    local port=$1
    timeout 3 bash -c "</dev/tcp/localhost/$port" 2>/dev/null
}

# Function untuk test HTTP
test_http() {
    local url=$1
    curl -s --connect-timeout 5 "$url" > /dev/null 2>&1
}

echo "📋 STEP 1: PRE-FIX DIAGNOSTIC"
echo "============================="

# Check current status
echo "🔍 Current Kong status:"
if docker ps | grep -q kong-gateway; then
    echo "✅ Kong container is running"
else
    echo "❌ Kong container is not running"
fi

echo ""

echo "📋 STEP 2: DOCKER ENVIRONMENT FIX"
echo "================================"

# Ensure Docker is running
echo "🔧 Ensuring Docker is running..."
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running, starting Docker..."
    sudo systemctl start docker
    sleep 5
    if docker info >/dev/null 2>&1; then
        echo "✅ Docker started successfully"
    else
        echo "❌ Failed to start Docker"
        exit 1
    fi
else
    echo "✅ Docker is already running"
fi

echo ""

echo "📋 STEP 3: CLEANUP EXISTING CONTAINERS"
echo "======================================"

# Stop and remove existing containers
echo "🧹 Cleaning up existing Kong containers..."
docker-compose down 2>/dev/null || true
docker container prune -f >/dev/null 2>&1 || true
echo "✅ Cleanup completed"

echo ""

echo "📋 STEP 4: DATABASE CONNECTION VERIFICATION"
echo "==========================================="

# Test database connection
DB_HOST="162.11.0.232"
DB_PORT="5432"
DB_USER="sharedpg"

echo "🔍 Testing database connection to $DB_HOST:$DB_PORT..."
if timeout 5 bash -c "</dev/tcp/$DB_HOST/$DB_PORT" 2>/dev/null; then
    echo "✅ Database server is reachable"
else
    echo "❌ Database server is not reachable"
    echo "   This might be a network or firewall issue"
    echo "   Continuing with Kong startup anyway..."
fi

echo ""

echo "📋 STEP 5: START KONG WITH PROPER CONFIGURATION"
echo "==============================================="

# Switch to server configuration
echo "🔧 Switching to server configuration..."
if [ -f "./scripts/switch-kong-config.sh" ]; then
    ./scripts/switch-kong-config.sh server
    echo "✅ Configuration switched to server"
else
    echo "⚠️  switch-kong-config.sh not found, using default"
fi

echo ""

# Start Kong
echo "🚀 Starting Kong with Docker Compose..."
docker-compose up -d

echo "⏳ Waiting for Kong to initialize..."
sleep 20

echo ""

echo "📋 STEP 6: VERIFY KONG STARTUP"
echo "=============================="

# Check if Kong is running
echo "🔍 Checking Kong container status..."
if docker ps | grep -q kong-gateway; then
    echo "✅ Kong container is running"
    
    # Check container health
    echo "🔍 Checking container health..."
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep kong-gateway | grep -q "Up"; then
        echo "✅ Kong container is healthy"
    else
        echo "⚠️  Kong container might have issues"
    fi
else
    echo "❌ Kong container failed to start"
    echo "🔍 Checking logs..."
    docker-compose logs kong 2>/dev/null | tail -n 20 || echo "No logs available"
    exit 1
fi

echo ""

echo "📋 STEP 7: PORT BINDING VERIFICATION"
echo "===================================="

# Check if ports are bound
echo "🔍 Checking port bindings..."
for port in 9545 9546 9547; do
    if test_port $port; then
        echo "✅ Port $port is accessible"
    else
        echo "❌ Port $port is not accessible"
    fi
done

echo ""

echo "📋 STEP 8: HTTP ENDPOINT TESTING"
echo "==============================="

# Test HTTP endpoints
echo "🔍 Testing HTTP endpoints..."
if test_http "http://localhost:9545/"; then
    echo "✅ Kong Proxy (9545) is responding"
else
    echo "❌ Kong Proxy (9545) is not responding"
fi

if test_http "http://localhost:9546/"; then
    echo "✅ Kong Admin API (9546) is responding"
else
    echo "❌ Kong Admin API (9546) is not responding"
fi

if test_http "http://localhost:9547/"; then
    echo "✅ Kong Admin GUI (9547) is responding"
else
    echo "❌ Kong Admin GUI (9547) is not responding"
fi

echo ""

echo "📋 STEP 9: EXTERNAL ACCESS CONFIGURATION"
echo "======================================="

# Check external access
echo "🔍 Testing external access..."
if test_http "http://$SERVER_IP:9545/"; then
    echo "✅ External access to Kong Proxy works"
else
    echo "❌ External access to Kong Proxy failed"
    echo "🔧 Attempting to fix external access..."
    
    # Check if Kong is binding to all interfaces
    echo "🔍 Checking Kong binding configuration..."
    if docker exec kong-gateway netstat -tlnp 2>/dev/null | grep -q ":9545.*0.0.0.0"; then
        echo "✅ Kong is binding to all interfaces (0.0.0.0)"
    else
        echo "⚠️  Kong might not be binding to all interfaces"
    fi
    
    # Check firewall
    echo "🔍 Checking firewall configuration..."
    if command -v ufw >/dev/null 2>&1; then
        echo "🔧 Configuring UFW firewall..."
        sudo ufw allow 9545/tcp >/dev/null 2>&1 || true
        sudo ufw allow 9546/tcp >/dev/null 2>&1 || true
        sudo ufw allow 9547/tcp >/dev/null 2>&1 || true
        echo "✅ UFW rules added for Kong ports"
    fi
    
    # Test again
    if test_http "http://$SERVER_IP:9545/"; then
        echo "✅ External access now works!"
    else
        echo "❌ External access still failing"
        echo "   Manual intervention required"
    fi
fi

echo ""

echo "📋 STEP 10: DEPLOY KONG CONFIGURATION"
echo "===================================="

# Deploy Kong configuration if available
if [ -f "./scripts/deploy-kong-config-db.sh" ]; then
    echo "🔧 Deploying Kong configuration..."
    ./scripts/deploy-kong-config-db.sh
    echo "✅ Configuration deployment completed"
else
    echo "⚠️  deploy-kong-config-db.sh not found"
    echo "   You may need to manually configure Kong services and routes"
fi

echo ""

echo "📋 STEP 11: FINAL VERIFICATION"
echo "============================="

echo "🔍 Final system check..."

# Test all endpoints
all_working=true

if ! test_port 9545; then
    echo "❌ Kong Proxy port 9545 is not accessible"
    all_working=false
fi

if ! test_port 9546; then
    echo "❌ Kong Admin API port 9546 is not accessible"
    all_working=false
fi

if ! test_port 9547; then
    echo "❌ Kong Admin GUI port 9547 is not accessible"
    all_working=false
fi

if ! test_http "http://localhost:9545/"; then
    echo "❌ Kong Proxy HTTP endpoint is not responding"
    all_working=false
fi

if ! test_http "http://localhost:9546/"; then
    echo "❌ Kong Admin API HTTP endpoint is not responding"
    all_working=false
fi

echo ""

if [ "$all_working" = true ]; then
    echo "🎉 SUCCESS! Kong API Gateway is working properly"
    echo ""
    echo "📋 Available Endpoints:"
    echo "   - Kong Proxy: http://$SERVER_IP:9545"
    echo "   - Kong Admin API: http://$SERVER_IP:9546"
    echo "   - Kong Admin GUI: http://$SERVER_IP:9547"
    echo ""
    echo "🧪 Test Commands:"
    echo "   curl http://$SERVER_IP:9545/"
    echo "   curl http://$SERVER_IP:9546/"
    echo "   curl http://$SERVER_IP:9547/"
else
    echo "⚠️  Some issues remain. Manual intervention may be required."
    echo ""
    echo "🔍 Troubleshooting steps:"
    echo "   1. Check Kong logs: docker logs kong-gateway"
    echo "   2. Check Docker logs: docker-compose logs"
    echo "   3. Verify database connectivity"
    echo "   4. Check firewall settings"
    echo "   5. Verify network configuration"
fi

echo ""
echo "✅ Fix process completed!"
