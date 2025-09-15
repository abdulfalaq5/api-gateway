#!/bin/bash

# Script untuk mendiagnosis masalah Kong di Server
# Script ini akan mengecek semua komponen dan memberikan rekomendasi

set -e

echo "🔍 Kong API Gateway - Server Diagnostic Tool"
echo "============================================="
echo ""

# Get server info
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "🖥️  Server IP: $SERVER_IP"
echo "📅 Time: $(date)"
echo ""

# Function untuk test port
test_port() {
    local port=$1
    local service=$2
    
    echo -n "🔍 Testing $service (Port $port)... "
    
    if timeout 3 bash -c "</dev/tcp/localhost/$port" 2>/dev/null; then
        echo "✅ OK"
        return 0
    else
        echo "❌ FAILED"
        return 1
    fi
}

# Function untuk test HTTP endpoint
test_http() {
    local url=$1
    local description=$2
    local expected_code=${3:-200}
    
    echo -n "🌐 Testing $description... "
    
    response_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" 2>/dev/null || echo "000")
    
    if [ "$response_code" = "$expected_code" ]; then
        echo "✅ OK (HTTP $response_code)"
        return 0
    else
        echo "❌ FAILED (HTTP $response_code)"
        return 1
    fi
}

# Function untuk test external access
test_external() {
    local url=$1
    local description=$2
    
    echo -n "🌍 Testing external $description... "
    
    if curl -s --connect-timeout 5 "$url" > /dev/null 2>&1; then
        echo "✅ OK"
        return 0
    else
        echo "❌ FAILED"
        return 1
    fi
}

echo "📋 1. DOCKER STATUS CHECK"
echo "========================"

# Check Docker
if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
        echo "✅ Docker is running"
    else
        echo "❌ Docker is not running"
        echo "   Solution: sudo systemctl start docker"
        exit 1
    fi
else
    echo "❌ Docker is not installed"
    exit 1
fi

# Check Docker Compose
if command -v docker-compose >/dev/null 2>&1; then
    echo "✅ Docker Compose is available"
else
    echo "❌ Docker Compose is not available"
    exit 1
fi

echo ""

echo "📋 2. DATABASE CONNECTIVITY CHECK"
echo "================================"

DB_HOST="162.11.0.232"
DB_PORT="5432"
DB_USER="sharedpg"

echo "🔍 Testing database connection to $DB_HOST:$DB_PORT..."

if timeout 5 bash -c "</dev/tcp/$DB_HOST/$DB_PORT" 2>/dev/null; then
    echo "✅ Database server is reachable"
else
    echo "❌ Database server is not reachable"
    echo "   Check network connectivity and firewall rules"
fi

# Test database with psql if available
if command -v psql >/dev/null 2>&1; then
    echo -n "🔍 Testing database authentication... "
    if PGPASSWORD="pgpass" timeout 5 psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d kong -c "SELECT 1;" >/dev/null 2>&1; then
        echo "✅ OK"
    else
        echo "❌ FAILED"
        echo "   Check database credentials and permissions"
    fi
fi

echo ""

echo "📋 3. DOCKER CONTAINERS STATUS"
echo "============================="

# Check if containers are running
if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q kong; then
    echo "✅ Kong containers found:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep kong
else
    echo "❌ No Kong containers running"
    echo "   Solution: docker-compose up -d"
fi

echo ""

echo "📋 4. PORT AVAILABILITY CHECK"
echo "============================"

# Test Kong ports
test_port 9545 "Kong Proxy"
test_port 9546 "Kong Admin API"
test_port 9547 "Kong Admin GUI"

echo ""

echo "📋 5. HTTP ENDPOINT TESTING"
echo "=========================="

# Test Kong endpoints
test_http "http://localhost:9545/" "Kong Proxy"
test_http "http://localhost:9546/" "Kong Admin API"
test_http "http://localhost:9547/" "Kong Admin GUI"

echo ""

echo "📋 6. EXTERNAL ACCESS TESTING"
echo "============================"

# Test external access
test_external "http://$SERVER_IP:9545/" "Kong Proxy"
test_external "http://$SERVER_IP:9546/" "Kong Admin API"
test_external "http://$SERVER_IP:9547/" "Kong Admin GUI"

echo ""

echo "📋 7. KONG SERVICES & ROUTES CHECK"
echo "================================="

# Check if Kong Admin API is working
if curl -s http://localhost:9546/ >/dev/null 2>&1; then
    echo "✅ Kong Admin API is accessible"
    
    # Check services
    echo "🔍 Checking Kong Services:"
    services=$(curl -s http://localhost:9546/services/ 2>/dev/null | jq -r '.data[]?.name // empty' 2>/dev/null || echo "")
    if [ -n "$services" ]; then
        echo "$services" | while read service; do
            echo "   ✅ Service: $service"
        done
    else
        echo "   ⚠️  No services configured"
    fi
    
    # Check routes
    echo "🔍 Checking Kong Routes:"
    routes=$(curl -s http://localhost:9546/routes/ 2>/dev/null | jq -r '.data[]?.name // empty' 2>/dev/null || echo "")
    if [ -n "$routes" ]; then
        echo "$routes" | while read route; do
            echo "   ✅ Route: $route"
        done
    else
        echo "   ⚠️  No routes configured"
    fi
    
    # Check consumers
    echo "🔍 Checking Kong Consumers:"
    consumers=$(curl -s http://localhost:9546/consumers/ 2>/dev/null | jq -r '.data[]?.username // empty' 2>/dev/null || echo "")
    if [ -n "$consumers" ]; then
        echo "$consumers" | while read consumer; do
            echo "   ✅ Consumer: $consumer"
        done
    else
        echo "   ⚠️  No consumers configured"
    fi
else
    echo "❌ Kong Admin API is not accessible"
fi

echo ""

echo "📋 8. NETWORK CONFIGURATION"
echo "==========================="

# Show listening ports
echo "🔍 Ports yang sedang listening:"
netstat -tlnp 2>/dev/null | grep -E ":(9545|9546|9547|5432) " | while read line; do
    port=$(echo $line | awk '{print $4}' | cut -d: -f2)
    service=$(echo $line | awk '{print $7}' | cut -d/ -f2)
    echo "   ✅ Port $port: $service"
done || echo "   ⚠️  netstat not available"

echo ""

# Show firewall status
if command -v ufw >/dev/null 2>&1; then
    echo "🔍 UFW Firewall Status:"
    ufw status | grep -E "(9545|9546|9547)" || echo "   ⚠️  No Kong ports in UFW rules"
elif command -v iptables >/dev/null 2>&1; then
    echo "🔍 iptables rules for Kong ports:"
    iptables -L | grep -E "(9545|9546|9547)" || echo "   ⚠️  No Kong ports in iptables rules"
fi

echo ""

echo "📋 9. LOG ANALYSIS"
echo "=================="

echo "🔍 Checking recent Kong logs:"
if docker logs kong-gateway 2>/dev/null | tail -n 10 | grep -E "(ERROR|WARN|error|warn)" || echo "   No recent errors found"; then
    echo ""
fi

echo ""

echo "📋 10. RECOMMENDATIONS"
echo "====================="

echo "🔧 Based on diagnostic results:"
echo ""

# Check if Kong Proxy is accessible
if ! test_port 9545 "Kong Proxy" >/dev/null 2>&1; then
    echo "❌ Kong Proxy (port 9545) is not accessible"
    echo "   Solutions:"
    echo "   1. Restart Kong: docker-compose down && docker-compose up -d"
    echo "   2. Check firewall: sudo ufw allow 9545"
    echo "   3. Check if port is bound: netstat -tlnp | grep 9545"
    echo ""
fi

# Check if Admin API is accessible
if ! test_port 9546 "Kong Admin API" >/dev/null 2>&1; then
    echo "❌ Kong Admin API (port 9546) is not accessible"
    echo "   Solutions:"
    echo "   1. Check Kong configuration"
    echo "   2. Check Docker logs: docker logs kong-gateway"
    echo "   3. Verify database connection"
    echo ""
fi

# Check external access
if ! test_external "http://$SERVER_IP:9545/" "Kong Proxy" >/dev/null 2>&1; then
    echo "❌ External access to Kong Proxy failed"
    echo "   Solutions:"
    echo "   1. Check firewall rules"
    echo "   2. Check if Kong is binding to 0.0.0.0 (not just 127.0.0.1)"
    echo "   3. Check network interface configuration"
    echo ""
fi

echo "📝 Test Commands:"
echo "=================="
echo "# Test Kong Proxy locally:"
echo "curl http://localhost:9545/"
echo ""
echo "# Test Kong Proxy externally:"
echo "curl http://$SERVER_IP:9545/"
echo ""
echo "# Test Kong Admin API:"
echo "curl http://localhost:9546/"
echo ""
echo "# View Kong logs:"
echo "docker logs kong-gateway"
echo ""
echo "# Restart Kong:"
echo "docker-compose down && docker-compose up -d"
echo ""

echo "✅ Diagnostic complete!"
