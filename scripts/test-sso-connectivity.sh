#!/bin/bash

# Script untuk testing connectivity ke SSO service
# Author: Kong API Gateway Team
# Description: Test konektivitas ke SSO service dari Kong container

echo "=== Testing SSO Service Connectivity ==="
echo "Timestamp: $(date)"
echo

# Test dari host machine
echo "1. Testing dari host machine ke SSO service..."
echo "   Target: http://172.17.0.1:9588/api/auth/sso/login"
echo

# Test dengan curl
echo "   Testing dengan curl:"
curl -v --connect-timeout 10 --max-time 30 \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"test": "connectivity"}' \
  http://172.17.0.1:9588/api/auth/sso/login 2>&1 | head -20

echo
echo "   Testing dengan telnet:"
timeout 10 telnet 172.17.0.1 9588 2>&1 | head -5

echo
echo "2. Testing dari Kong container..."
echo "   Executing test dari dalam Kong container..."

# Test dari dalam Kong container
docker exec kong-gateway sh -c "
  echo '   Testing dengan curl dari Kong container:'
  curl -v --connect-timeout 10 --max-time 30 \
    -X POST \
    -H 'Content-Type: application/json' \
    -d '{\"test\": \"connectivity\"}' \
    http://172.17.0.1:9588/api/auth/sso/login 2>&1 | head -20
  
  echo
  echo '   Testing dengan telnet dari Kong container:'
  timeout 10 telnet 172.17.0.1 9588 2>&1 | head -5
"

echo
echo "3. Checking Kong service configuration..."
echo "   Checking Kong services:"
docker exec kong-gateway kong config db_export 2>/dev/null | grep -A 10 -B 5 "sso-service" || echo "   Service tidak ditemukan dalam database"

echo
echo "4. Checking Kong routes..."
echo "   Checking Kong routes:"
docker exec kong-gateway kong config db_export 2>/dev/null | grep -A 10 -B 5 "sso-login-routes" || echo "   Route tidak ditemukan dalam database"

echo
echo "=== Test Complete ==="
echo "Jika semua test gagal, kemungkinan masalah:"
echo "1. SSO service tidak berjalan di 172.17.0.1:9588"
echo "2. Firewall memblokir koneksi"
echo "3. Network configuration tidak benar"
echo "4. SSO service tidak merespons dengan benar"
