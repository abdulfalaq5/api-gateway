#!/bin/bash

# Script cepat untuk mengecek status Kong di server
# Script ini akan memberikan gambaran cepat tentang masalah yang ada

set -e

echo "⚡ Kong API Gateway - Quick Server Check"
echo "========================================"
echo ""

# Get server info
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "🖥️  Server IP: $SERVER_IP"
echo "📅 Time: $(date)"
echo ""

# Function untuk quick test
quick_test() {
    local url=$1
    local description=$2
    
    echo -n "🔍 $description... "
    if curl -s --connect-timeout 3 --max-time 5 "$url" >/dev/null 2>&1; then
        echo "✅ OK"
        return 0
    else
        echo "❌ FAILED"
        return 1
    fi
}

echo "📋 QUICK STATUS CHECK"
echo "====================="

# Check Docker
echo -n "🔍 Docker status... "
if docker info >/dev/null 2>&1; then
    echo "✅ Running"
else
    echo "❌ Not running"
    echo "   Fix: sudo systemctl start docker"
    exit 1
fi

# Check Kong containers
echo -n "🔍 Kong containers... "
if docker ps | grep -q kong-gateway; then
    echo "✅ Running"
else
    echo "❌ Not running"
    echo "   Fix: docker-compose up -d"
    exit 1
fi

echo ""

echo "📋 QUICK CONNECTIVITY TEST"
echo "=========================="

# Test all Kong endpoints
quick_test "http://localhost:9545/" "Kong Proxy (localhost)"
quick_test "http://localhost:9546/" "Kong Admin API (localhost)"
quick_test "http://localhost:9547/" "Kong Admin GUI (localhost)"
quick_test "http://$SERVER_IP:9545/" "Kong Proxy (external)"
quick_test "http://$SERVER_IP:9546/" "Kong Admin API (external)"
quick_test "http://$SERVER_IP:9547/" "Kong Admin GUI (external)"

echo ""

echo "📋 QUICK TROUBLESHOOTING"
echo "======================="

# Check what's failing
localhost_proxy_ok=false
external_proxy_ok=false
admin_api_ok=false

if curl -s --connect-timeout 3 "http://localhost:9545/" >/dev/null 2>&1; then
    localhost_proxy_ok=true
fi

if curl -s --connect-timeout 3 "http://$SERVER_IP:9545/" >/dev/null 2>&1; then
    external_proxy_ok=true
fi

if curl -s --connect-timeout 3 "http://localhost:9546/" >/dev/null 2>&1; then
    admin_api_ok=true
fi

echo "🔧 Issues found:"

if [ "$localhost_proxy_ok" = false ]; then
    echo "❌ Kong Proxy tidak dapat diakses dari localhost"
    echo "   → Kong mungkin tidak berjalan dengan benar"
    echo "   → Solusi: docker-compose restart"
fi

if [ "$external_proxy_ok" = false ] && [ "$localhost_proxy_ok" = true ]; then
    echo "❌ Kong Proxy tidak dapat diakses dari external"
    echo "   → Masalah firewall atau network binding"
    echo "   → Solusi: sudo ufw allow 9545"
fi

if [ "$admin_api_ok" = false ]; then
    echo "❌ Kong Admin API tidak dapat diakses"
    echo "   → Kong mungkin belum fully started"
    echo "   → Solusi: tunggu beberapa menit atau restart"
fi

echo ""

if [ "$localhost_proxy_ok" = true ] && [ "$external_proxy_ok" = true ] && [ "$admin_api_ok" = true ]; then
    echo "🎉 SEMUA TEST BERHASIL!"
    echo ""
    echo "✅ Kong API Gateway berfungsi dengan baik"
    echo ""
    echo "📋 Endpoints yang tersedia:"
    echo "   - Kong Proxy: http://$SERVER_IP:9545"
    echo "   - Kong Admin API: http://$SERVER_IP:9546"
    echo "   - Kong Admin GUI: http://$SERVER_IP:9547"
    echo ""
    echo "🧪 Test curl:"
    echo "   curl http://$SERVER_IP:9545/"
else
    echo "⚠️  ADA MASALAH YANG PERLU DIPERBAIKI"
    echo ""
    echo "🔧 Script untuk memperbaiki masalah:"
    echo "   ./scripts/fix-kong-server-issues.sh"
    echo ""
    echo "🔍 Script untuk diagnosa detail:"
    echo "   ./scripts/diagnose-kong-server.sh"
    echo ""
    echo "🧪 Script untuk test curl detail:"
    echo "   ./scripts/test-curl-issues.sh"
fi

echo ""
echo "✅ Quick check completed!"
