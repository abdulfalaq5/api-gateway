#!/bin/bash

# Script untuk test connectivity Kong API Gateway di Server Internal

set -e

echo "🧪 Kong API Gateway - Server Connectivity Test"
echo "================================================"

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

echo "🖥️  Server IP: $SERVER_IP"
echo ""

# Function untuk test port
test_port() {
    local port=$1
    local service=$2
    local description=$3
    
    echo -n "🔍 Testing $service (Port $port)... "
    
    if timeout 5 bash -c "</dev/tcp/localhost/$port" 2>/dev/null; then
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
    
    echo -n "🌐 Testing $description... "
    
    if curl -s --connect-timeout 5 "$url" > /dev/null 2>&1; then
        echo "✅ OK"
        return 0
    else
        echo "❌ FAILED"
        return 1
    fi
}

echo "📋 Testing Kong Services:"
echo ""

# Test Kong Proxy
test_port 9545 "Kong Proxy" "Public API Access"
test_http "http://localhost:9545/" "Kong Proxy HTTP"

echo ""

# Test Kong Admin API
test_port 9546 "Kong Admin API" "Management API"
test_http "http://localhost:9546/" "Kong Admin API HTTP"

echo ""

# Test Kong Admin GUI
test_port 9547 "Kong Admin GUI" "Web Interface"
test_http "http://localhost:9547/" "Kong Admin GUI HTTP"

echo ""

# Test PostgreSQL
test_port 5432 "PostgreSQL" "Database"

echo ""
echo "🌍 External Connectivity Test:"
echo ""

# Test external access to Kong Proxy
echo -n "🔍 Testing external access to Kong Proxy... "
if curl -s --connect-timeout 5 "http://$SERVER_IP:9545/" > /dev/null 2>&1; then
    echo "✅ OK"
    echo "   ✅ Kong Proxy dapat diakses dari external: http://$SERVER_IP:9545"
else
    echo "❌ FAILED"
    echo "   ❌ Kong Proxy tidak dapat diakses dari external"
fi

echo ""

# Test internal access to Admin API
echo -n "🔍 Testing internal access to Admin API... "
if curl -s --connect-timeout 5 "http://$SERVER_IP:9546/" > /dev/null 2>&1; then
    echo "✅ OK"
    echo "   ✅ Kong Admin API dapat diakses dari internal: http://$SERVER_IP:9546"
else
    echo "❌ FAILED"
    echo "   ❌ Kong Admin API tidak dapat diakses dari internal"
fi

echo ""

# Test internal access to Admin GUI
echo -n "🔍 Testing internal access to Admin GUI... "
if curl -s --connect-timeout 5 "http://$SERVER_IP:9547/" > /dev/null 2>&1; then
    echo "✅ OK"
    echo "   ✅ Kong Admin GUI dapat diakses dari internal: http://$SERVER_IP:9547"
else
    echo "❌ FAILED"
    echo "   ❌ Kong Admin GUI tidak dapat diakses dari internal"
fi

echo ""
echo "📊 Port Status Summary:"
echo "======================"

# Show listening ports
echo "🔍 Ports yang sedang listening:"
netstat -tlnp | grep -E ":(9545|9546|9547|5432) " | while read line; do
    port=$(echo $line | awk '{print $4}' | cut -d: -f2)
    service=$(echo $line | awk '{print $7}' | cut -d/ -f2)
    echo "   ✅ Port $port: $service"
done

echo ""
echo "🌐 Network Configuration:"
echo "========================"
echo "📋 Endpoints yang tersedia:"
echo "   - Kong Proxy (Public): http://$SERVER_IP:9545"
echo "   - Kong Admin API (Internal): http://$SERVER_IP:9546"
echo "   - Kong Admin GUI (Internal): http://$SERVER_IP:9547"
echo ""

echo "📋 Test Commands:"
echo "   # Test Kong Proxy dari external"
echo "   curl http://$SERVER_IP:9545/"
echo ""
echo "   # Test Kong Admin API dari internal"
echo "   curl http://$SERVER_IP:9546/"
echo ""
echo "   # Test Kong Admin GUI dari internal"
echo "   curl http://$SERVER_IP:9547/"
echo ""

echo "🔒 Security Notes:"
echo "   - Port 9545: Public access (untuk client)"
echo "   - Port 9546, 9547, 5432: Internal access only"
echo "   - Pastikan firewall dikonfigurasi dengan benar"
echo ""

echo "✅ Connectivity test selesai!"
