#!/bin/bash

# Script untuk fix backend connectivity issues
# Usage: ./fix-backend-connectivity.sh

echo "================================================"
echo "🔧 BACKEND CONNECTIVITY FIX TOOL"
echo "================================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BACKENDS=(
    "api-gate.motorsights.com"
    "api-report-management.motorsights.com"
    "api-interview.motorsights.com"
    "api-ecatalogue.motorsights.com"
)

echo -e "${BLUE}Diagnosing backend connectivity issues...${NC}"
echo ""

# 1. Test from host machine
echo "1️⃣  Testing from Host Machine:"
echo "================================================"
for backend in "${BACKENDS[@]}"; do
    echo -n "Testing $backend ... "
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "https://$backend" 2>/dev/null)
    if [ -z "$RESPONSE" ] || [ "$RESPONSE" = "000" ]; then
        echo -e "${RED}❌ TIMEOUT${NC}"
    else
        echo -e "${GREEN}✅ OK (HTTP $RESPONSE)${NC}"
    fi
done
echo ""

# 2. Test DNS resolution from host
echo "2️⃣  Testing DNS Resolution from Host:"
echo "================================================"
for backend in "${BACKENDS[@]}"; do
    echo -n "Resolving $backend ... "
    IP=$(nslookup "$backend" 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}')
    if [ -z "$IP" ]; then
        echo -e "${RED}❌ FAILED${NC}"
    else
        echo -e "${GREEN}✅ $IP${NC}"
    fi
done
echo ""

# 3. Test from Kong container
echo "3️⃣  Testing from Kong Container:"
echo "================================================"
for backend in "${BACKENDS[@]}"; do
    echo -n "Testing $backend from Kong ... "
    RESPONSE=$(docker exec kong-gateway curl -s -o /dev/null -w "%{http_code}" --max-time 5 "https://$backend" 2>/dev/null)
    if [ -z "$RESPONSE" ] || [ "$RESPONSE" = "000" ]; then
        echo -e "${RED}❌ TIMEOUT (This is the problem!)${NC}"
    else
        echo -e "${GREEN}✅ OK (HTTP $RESPONSE)${NC}"
    fi
done
echo ""

# 4. Test DNS from Kong container
echo "4️⃣  Testing DNS from Kong Container:"
echo "================================================"
for backend in "${BACKENDS[@]}"; do
    echo -n "Resolving $backend from Kong ... "
    RESOLVED=$(docker exec kong-gateway nslookup "$backend" 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}')
    if [ -z "$RESOLVED" ]; then
        echo -e "${RED}❌ DNS FAILED (This is the problem!)${NC}"
    else
        echo -e "${GREEN}✅ $RESOLVED${NC}"
    fi
done
echo ""

# 5. Test ping
echo "5️⃣  Testing Ping from Kong Container:"
echo "================================================"
for backend in "${BACKENDS[@]}"; do
    echo -n "Ping $backend ... "
    PING_RESULT=$(docker exec kong-gateway ping -c 2 "$backend" 2>/dev/null | grep "packets transmitted")
    if echo "$PING_RESULT" | grep -q "0 received"; then
        echo -e "${RED}❌ NO RESPONSE${NC}"
    elif [ -z "$PING_RESULT" ]; then
        echo -e "${RED}❌ FAILED${NC}"
    else
        echo -e "${GREEN}✅ OK${NC}"
    fi
done
echo ""

# 6. Diagnosis and Solutions
echo "================================================"
echo "📊 DIAGNOSIS & SOLUTIONS"
echo "================================================"
echo ""

echo -e "${YELLOW}Kemungkinan masalah:${NC}"
echo ""
echo "1. 🔥 FIREWALL BLOCKING OUTBOUND"
echo "   Server firewall memblock koneksi dari Kong ke backend"
echo "   ${GREEN}Solution:${NC}"
echo "   sudo ufw status"
echo "   sudo ufw allow out to any"
echo ""

echo "2. 🌐 DNS RESOLUTION ISSUE"
echo "   Kong container tidak bisa resolve domain backend"
echo "   ${GREEN}Solution:${NC}"
echo "   Edit docker-compose.yml, tambahkan:"
echo "   services:"
echo "     kong:"
echo "       dns:"
echo "         - 8.8.8.8"
echo "         - 8.8.4.4"
echo "         - 1.1.1.1"
echo ""

echo "3. 🔒 SSL/TLS CERTIFICATE ISSUE"
echo "   Kong tidak trust SSL certificate backend"
echo "   ${GREEN}Solution:${NC}"
echo "   Test dengan HTTP dulu (jika ada):"
echo "   docker exec kong-gateway curl -I http://api-gate.motorsights.com"
echo ""

echo "4. 📡 NETWORK CONFIGURATION"
echo "   Docker network issue atau routing problem"
echo "   ${GREEN}Solution:${NC}"
echo "   docker-compose down"
echo "   docker network prune"
echo "   docker-compose up -d"
echo ""

echo "5. 🚫 BACKEND SERVICE DOWN"
echo "   Backend service benar-benar down"
echo "   ${GREEN}Solution:${NC}"
echo "   Cek status backend service"
echo "   Contact backend team"
echo ""

# 7. Quick fixes to try
echo "================================================"
echo "🔧 QUICK FIXES TO TRY NOW"
echo "================================================"
echo ""

read -p "Try adding DNS servers to Kong? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Creating backup of docker-compose.yml..."
    cp docker-compose.yml docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)
    
    echo ""
    echo "Add these lines to your docker-compose.yml under kong service:"
    echo ""
    echo "    dns:"
    echo "      - 8.8.8.8"
    echo "      - 8.8.4.4"
    echo "      - 1.1.1.1"
    echo ""
    echo "Then run:"
    echo "  docker-compose down"
    echo "  docker-compose up -d"
    echo ""
fi

echo ""
echo "================================================"
echo "✅ Diagnostic Complete!"
echo "================================================"
echo ""
echo "📝 Manual tests you can run:"
echo ""
echo "# Test from Kong container:"
echo "docker exec kong-gateway curl -v https://api-gate.motorsights.com"
echo ""
echo "# Test DNS from Kong:"
echo "docker exec kong-gateway nslookup api-gate.motorsights.com"
echo ""
echo "# Check Kong network:"
echo "docker network inspect \$(docker inspect kong-gateway -f '{{range \$k, \$v := .NetworkSettings.Networks}}{{\$k}}{{end}}')"
echo ""
echo "# Test with different DNS:"
echo "docker exec kong-gateway sh -c 'echo \"nameserver 8.8.8.8\" > /etc/resolv.conf && curl https://api-gate.motorsights.com'"
echo ""

