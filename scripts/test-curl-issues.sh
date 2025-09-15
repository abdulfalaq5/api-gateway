#!/bin/bash

# Script untuk mengecek dan mengatasi masalah curl di server Kong
# Script ini akan test berbagai skenario curl dan memberikan solusi

set -e

echo "🧪 Kong API Gateway - Curl Issues Diagnostic"
echo "============================================"
echo ""

# Get server info
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "🖥️  Server IP: $SERVER_IP"
echo ""

# Function untuk test curl dengan detail
test_curl_detailed() {
    local url=$1
    local description=$2
    local headers=${3:-""}
    
    echo "🔍 Testing: $description"
    echo "   URL: $url"
    if [ -n "$headers" ]; then
        echo "   Headers: $headers"
    fi
    
    # Test with verbose output
    echo "   Response:"
    if [ -n "$headers" ]; then
        curl_output=$(curl -v -H "$headers" --connect-timeout 10 --max-time 30 "$url" 2>&1 || echo "CURL_FAILED")
    else
        curl_output=$(curl -v --connect-timeout 10 --max-time 30 "$url" 2>&1 || echo "CURL_FAILED")
    fi
    
    if [ "$curl_output" = "CURL_FAILED" ]; then
        echo "   ❌ CURL FAILED"
        echo ""
        return 1
    else
        echo "   Response details:"
        echo "$curl_output" | head -n 20 | sed 's/^/     /'
        echo ""
        return 0
    fi
}

# Function untuk test basic connectivity
test_basic_connectivity() {
    local host=$1
    local port=$2
    local description=$3
    
    echo "🔍 Testing basic connectivity: $description"
    echo "   Host: $host, Port: $port"
    
    if timeout 5 bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
        echo "   ✅ Port is open and accessible"
        return 0
    else
        echo "   ❌ Port is not accessible"
        return 1
    fi
}

echo "📋 STEP 1: BASIC CONNECTIVITY TEST"
echo "=================================="

# Test basic port connectivity
test_basic_connectivity "localhost" "9545" "Kong Proxy"
test_basic_connectivity "localhost" "9546" "Kong Admin API"
test_basic_connectivity "localhost" "9547" "Kong Admin GUI"
test_basic_connectivity "$SERVER_IP" "9545" "Kong Proxy (External)"
test_basic_connectivity "$SERVER_IP" "9546" "Kong Admin API (External)"

echo ""

echo "📋 STEP 2: CURL CONFIGURATION CHECK"
echo "==================================="

# Check curl version and configuration
echo "🔍 Curl version and configuration:"
curl --version | head -n 1
echo ""

# Check if curl can resolve localhost
echo "🔍 Testing DNS resolution:"
if curl -s --connect-timeout 5 "http://localhost:9545/" >/dev/null 2>&1; then
    echo "   ✅ localhost resolution works"
else
    echo "   ❌ localhost resolution failed"
fi

if curl -s --connect-timeout 5 "http://127.0.0.1:9545/" >/dev/null 2>&1; then
    echo "   ✅ 127.0.0.1 resolution works"
else
    echo "   ❌ 127.0.0.1 resolution failed"
fi

echo ""

echo "📋 STEP 3: KONG PROXY CURL TESTS"
echo "================================"

# Test Kong Proxy with different methods
test_curl_detailed "http://localhost:9545/" "Kong Proxy - Basic GET"
test_curl_detailed "http://127.0.0.1:9545/" "Kong Proxy - IP GET"
test_curl_detailed "http://$SERVER_IP:9545/" "Kong Proxy - External GET"

# Test with different HTTP methods
echo "🔍 Testing different HTTP methods on Kong Proxy:"

echo "   GET request:"
curl -s -w "HTTP Status: %{http_code}, Time: %{time_total}s\n" -o /dev/null "http://localhost:9545/" 2>/dev/null || echo "   ❌ GET failed"

echo "   POST request:"
curl -s -w "HTTP Status: %{http_code}, Time: %{time_total}s\n" -o /dev/null -X POST "http://localhost:9545/" 2>/dev/null || echo "   ❌ POST failed"

echo "   HEAD request:"
curl -s -w "HTTP Status: %{http_code}, Time: %{time_total}s\n" -o /dev/null -I "http://localhost:9545/" 2>/dev/null || echo "   ❌ HEAD failed"

echo ""

echo "📋 STEP 4: KONG ADMIN API CURL TESTS"
echo "===================================="

# Test Kong Admin API
test_curl_detailed "http://localhost:9546/" "Kong Admin API - Basic GET"
test_curl_detailed "http://localhost:9546/services/" "Kong Admin API - Services"
test_curl_detailed "http://localhost:9546/routes/" "Kong Admin API - Routes"
test_curl_detailed "http://localhost:9546/consumers/" "Kong Admin API - Consumers"

echo ""

echo "📋 STEP 5: KONG ADMIN GUI CURL TESTS"
echo "===================================="

# Test Kong Admin GUI
test_curl_detailed "http://localhost:9547/" "Kong Admin GUI - Basic GET"

echo ""

echo "📋 STEP 6: ERROR ANALYSIS"
echo "========================"

echo "🔍 Analyzing common curl error scenarios..."

# Test with different timeout values
echo "   Testing with different timeouts:"
for timeout in 1 5 10 30; do
    echo -n "   Timeout ${timeout}s: "
    if curl -s --connect-timeout $timeout --max-time $timeout "http://localhost:9545/" >/dev/null 2>&1; then
        echo "✅ OK"
    else
        echo "❌ FAILED"
    fi
done

echo ""

# Test with different user agents
echo "   Testing with different user agents:"
user_agents=("curl/7.68.0" "Mozilla/5.0" "Kong-Test/1.0")
for ua in "${user_agents[@]}"; do
    echo -n "   User-Agent: $ua - "
    if curl -s -H "User-Agent: $ua" "http://localhost:9545/" >/dev/null 2>&1; then
        echo "✅ OK"
    else
        echo "❌ FAILED"
    fi
done

echo ""

# Test with different protocols
echo "   Testing protocol variations:"
echo -n "   HTTP/1.0: "
if curl -s --http1.0 "http://localhost:9545/" >/dev/null 2>&1; then
    echo "✅ OK"
else
    echo "❌ FAILED"
fi

echo -n "   HTTP/1.1: "
if curl -s --http1.1 "http://localhost:9545/" >/dev/null 2>&1; then
    echo "✅ OK"
else
    echo "❌ FAILED"
fi

echo ""

echo "📋 STEP 7: NETWORK DIAGNOSTICS"
echo "=============================="

# Check network interfaces
echo "🔍 Network interface configuration:"
ip addr show | grep -E "inet.*:" | head -n 5 || ifconfig | grep -E "inet.*:" | head -n 5

echo ""

# Check routing table
echo "🔍 Routing table (relevant entries):"
ip route | head -n 5 || route -n | head -n 5

echo ""

# Check DNS configuration
echo "🔍 DNS configuration:"
cat /etc/resolv.conf | head -n 3 2>/dev/null || echo "DNS config not accessible"

echo ""

echo "📋 STEP 8: KONG-SPECIFIC CURL TESTS"
echo "==================================="

# Test Kong-specific endpoints
echo "🔍 Testing Kong-specific scenarios:"

# Test with Host header
echo "   Testing with Host header:"
if curl -s -H "Host: api.example.com" "http://localhost:9545/" >/dev/null 2>&1; then
    echo "   ✅ Host header test OK"
else
    echo "   ❌ Host header test failed"
fi

# Test with API key (if configured)
echo "   Testing with API key header:"
if curl -s -H "apikey: test-key" "http://localhost:9545/" >/dev/null 2>&1; then
    echo "   ✅ API key test OK"
else
    echo "   ❌ API key test failed (expected if no API key configured)"
fi

# Test with Authorization header
echo "   Testing with Authorization header:"
if curl -s -H "Authorization: Bearer test-token" "http://localhost:9545/" >/dev/null 2>&1; then
    echo "   ✅ Authorization test OK"
else
    echo "   ❌ Authorization test failed (expected if no auth configured)"
fi

echo ""

echo "📋 STEP 9: TROUBLESHOOTING RECOMMENDATIONS"
echo "=========================================="

echo "🔧 Common curl issues and solutions:"
echo ""

# Check if Kong is responding to basic requests
if ! curl -s --connect-timeout 5 "http://localhost:9545/" >/dev/null 2>&1; then
    echo "❌ Kong Proxy is not responding to basic requests"
    echo "   Solutions:"
    echo "   1. Check if Kong is running: docker ps | grep kong"
    echo "   2. Check Kong logs: docker logs kong-gateway"
    echo "   3. Restart Kong: docker-compose restart"
    echo "   4. Check port binding: netstat -tlnp | grep 9545"
    echo ""
fi

# Check if external access works
if ! curl -s --connect-timeout 5 "http://$SERVER_IP:9545/" >/dev/null 2>&1; then
    echo "❌ External access to Kong Proxy is not working"
    echo "   Solutions:"
    echo "   1. Check firewall: sudo ufw status"
    echo "   2. Check if Kong binds to 0.0.0.0: docker exec kong-gateway netstat -tlnp"
    echo "   3. Check network interface: ip addr show"
    echo "   4. Test with different IP: curl http://127.0.0.1:9545/"
    echo ""
fi

# Check if Admin API works
if ! curl -s --connect-timeout 5 "http://localhost:9546/" >/dev/null 2>&1; then
    echo "❌ Kong Admin API is not responding"
    echo "   Solutions:"
    echo "   1. Check Kong configuration"
    echo "   2. Check database connection"
    echo "   3. Check Kong logs for errors"
    echo "   4. Verify Kong is fully started"
    echo ""
fi

echo "📝 Manual Test Commands:"
echo "========================"
echo "# Test Kong Proxy:"
echo "curl -v http://localhost:9545/"
echo "curl -v http://$SERVER_IP:9545/"
echo ""
echo "# Test Kong Admin API:"
echo "curl -v http://localhost:9546/"
echo "curl -v http://localhost:9546/services/"
echo ""
echo "# Test with different options:"
echo "curl -v --connect-timeout 30 --max-time 60 http://localhost:9545/"
echo "curl -v -H 'User-Agent: Test-Client' http://localhost:9545/"
echo ""

echo "✅ Curl diagnostic completed!"
