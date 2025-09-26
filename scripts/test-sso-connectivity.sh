#!/bin/bash

# Script untuk test connectivity ke SSO service
# File: scripts/test-sso-connectivity.sh

set -e

echo "🧪 Testing SSO Service Connectivity..."

# Fungsi untuk test endpoint
test_endpoint() {
    local url=$1
    local name=$2
    local timeout=${3:-10}
    
    echo "   Testing $name: $url"
    
    if curl -s --connect-timeout $timeout --max-time $timeout "$url" > /dev/null 2>&1; then
        echo "     ✅ Accessible"
        return 0
    else
        echo "     ❌ Not accessible"
        return 1
    fi
}

# Test endpoints yang mungkin
echo "🔍 Testing possible SSO endpoints..."

endpoints=(
    "https://api-gate.motorsights.com/api/auth/sso/login|Direct API Gateway"
    "http://localhost:9588/api/auth/sso/login|Localhost:9588"
    "http://host.docker.internal:9588/api/auth/sso/login|Docker Host Internal:9588"
    "http://172.17.0.1:9588/api/auth/sso/login|Docker Bridge:9588"
    "http://localhost:3000/api/auth/sso/login|Localhost:3000"
    "http://localhost:8080/api/auth/sso/login|Localhost:8080"
)

accessible_endpoints=()

for endpoint_info in "${endpoints[@]}"; do
    IFS='|' read -r url name <<< "$endpoint_info"
    if test_endpoint "$url" "$name"; then
        accessible_endpoints+=("$url|$name")
    fi
done

echo ""
echo "📊 Connectivity Test Results:"
echo "   Total endpoints tested: ${#endpoints[@]}"
echo "   Accessible endpoints: ${#accessible_endpoints[@]}"

if [ ${#accessible_endpoints[@]} -eq 0 ]; then
    echo ""
    echo "❌ Tidak ada endpoint SSO yang accessible!"
    echo ""
    echo "💡 Troubleshooting steps:"
    echo "   1. Pastikan SSO service sedang berjalan"
    echo "   2. Cek firewall dan network configuration"
    echo "   3. Verifikasi port yang digunakan SSO service"
    echo "   4. Cek apakah SSO service menggunakan HTTPS atau HTTP"
    echo ""
    echo "🔧 Manual testing:"
    echo "   curl -v https://api-gate.motorsights.com/api/auth/sso/login"
    echo "   curl -v http://localhost:9588/api/auth/sso/login"
    echo "   curl -v http://host.docker.internal:9588/api/auth/sso/login"
    exit 1
else
    echo ""
    echo "✅ Found accessible endpoints:"
    for endpoint_info in "${accessible_endpoints[@]}"; do
        IFS='|' read -r url name <<< "$endpoint_info"
        echo "   - $name: $url"
    done
    
    # Rekomendasikan endpoint terbaik
    best_endpoint=$(echo "${accessible_endpoints[0]}" | cut -d'|' -f1)
    best_name=$(echo "${accessible_endpoints[0]}" | cut -d'|' -f2)
    
    echo ""
    echo "💡 Recommended upstream URL: $best_endpoint ($best_name)"
    echo ""
    echo "🔧 To use this endpoint, update config/env.sh:"
    echo "   SSO_UPSTREAM_URL=\"$best_endpoint\""
    echo ""
    echo "🔄 Then run:"
    echo "   ./scripts/fix-sso-upstream.sh"
fi

# Test Kong proxy jika Kong sedang berjalan
echo ""
echo "🧪 Testing Kong Proxy (if Kong is running)..."

if docker-compose ps | grep -q "kong-gateway.*Up"; then
    echo "   Kong is running, testing proxy endpoint..."
    
    # Test Kong proxy
    if curl -s --connect-timeout 5 http://localhost:9545/ > /dev/null 2>&1; then
        echo "   ✅ Kong proxy accessible at http://localhost:9545"
        
        # Test SSO endpoint melalui Kong
        echo "   Testing SSO endpoint through Kong..."
        if curl -s --connect-timeout 10 -X POST http://localhost:9545/api/auth/sso/login \
          -H "Content-Type: application/json" \
          -d '{"email":"test@test.com","password":"test","client_id":"test","redirect_uri":"test"}' > /dev/null 2>&1; then
            echo "   ✅ SSO endpoint accessible through Kong"
        else
            echo "   ⚠️  SSO endpoint timeout through Kong (check upstream configuration)"
        fi
    else
        echo "   ❌ Kong proxy not accessible"
    fi
else
    echo "   Kong is not running"
fi

echo ""
echo "✅ Connectivity test completed!"