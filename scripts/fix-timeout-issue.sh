#!/bin/bash

# Script untuk fix common timeout issues di Kong DB-less
# Usage: ./fix-timeout-issue.sh

echo "================================================"
echo "🔧 KONG TIMEOUT QUICK FIX"
echo "================================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}This script will try common fixes for Kong timeout issues${NC}"
echo ""

# Fix 1: Restart Kong
echo "1️⃣  Restarting Kong Container:"
echo "================================================"
echo "This will restart Kong and reload the configuration..."
docker-compose restart kong

echo "Waiting for Kong to start (15 seconds)..."
sleep 15

# Check if Kong is up
KONG_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9546/status 2>/dev/null)
if [ "$KONG_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ Kong restarted successfully${NC}"
else
    echo -e "${RED}❌ Kong may not be fully started yet. Check with: docker logs kong-gateway${NC}"
fi
echo ""

# Fix 2: Check loaded services
echo "2️⃣  Verifying Configuration Loaded:"
echo "================================================"
SERVICE_COUNT=$(curl -s http://localhost:9546/services 2>/dev/null | jq '.data | length' 2>/dev/null)
ROUTE_COUNT=$(curl -s http://localhost:9546/routes 2>/dev/null | jq '.data | length' 2>/dev/null)

if [ -z "$SERVICE_COUNT" ] || [ "$SERVICE_COUNT" = "0" ]; then
    echo -e "${RED}❌ No services loaded!${NC}"
    echo "   Config file might have issues or not mounted properly."
    echo ""
    echo -e "${YELLOW}💡 Try:${NC}"
    echo "   1. Check kong.yml syntax: docker-compose config"
    echo "   2. Verify volume mount in docker-compose.yml"
    echo "   3. Full restart: docker-compose down && docker-compose up -d"
else
    echo -e "${GREEN}✅ Configuration loaded:${NC}"
    echo "   Services: $SERVICE_COUNT"
    echo "   Routes: $ROUTE_COUNT"
fi
echo ""

# Fix 3: Test connectivity to backends
echo "3️⃣  Testing Backend Connectivity:"
echo "================================================"
echo "Testing if Kong can reach backend services..."

# Test SSO backend
echo -n "SSO Service (api-gate.motorsights.com) ... "
BACKEND_TEST=$(docker exec kong-gateway curl -s -o /dev/null -w "%{http_code}" --max-time 5 https://api-gate.motorsights.com 2>/dev/null)
if [ -z "$BACKEND_TEST" ] || [ "$BACKEND_TEST" = "000" ]; then
    echo -e "${RED}❌ UNREACHABLE${NC}"
    echo "   This is likely the issue! Kong cannot reach backend."
    echo ""
    echo -e "${YELLOW}💡 Possible solutions:${NC}"
    echo "   1. Check if backend service is up"
    echo "   2. Check firewall rules on server"
    echo "   3. Check DNS resolution: docker exec kong-gateway nslookup api-gate.motorsights.com"
    echo "   4. Try ping from Kong container: docker exec kong-gateway ping -c 3 api-gate.motorsights.com"
else
    echo -e "${GREEN}✅ Reachable (HTTP $BACKEND_TEST)${NC}"
fi
echo ""

# Fix 4: Test a sample endpoint
echo "4️⃣  Testing Sample Endpoint:"
echo "================================================"
echo "Testing: POST /api/menus"
ENDPOINT_TEST=$(curl -s -o /dev/null -w "%{http_code}|%{time_total}" \
    --max-time 10 \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{}' \
    http://localhost:9545/api/menus 2>/dev/null)

HTTP_CODE=$(echo "$ENDPOINT_TEST" | cut -d'|' -f1)
TIME=$(echo "$ENDPOINT_TEST" | cut -d'|' -f2)

if [ -z "$HTTP_CODE" ] || [ "$HTTP_CODE" = "000" ]; then
    echo -e "${RED}❌ TIMEOUT - Endpoint not responding${NC}"
    echo ""
    echo -e "${YELLOW}💡 Next steps:${NC}"
    echo "   1. Check Kong logs: docker logs kong-gateway --tail 50"
    echo "   2. Check if backend service is down"
    echo "   3. Try increasing timeout in kong.yml (currently 60 seconds)"
elif [ "$HTTP_CODE" = "504" ]; then
    echo -e "${RED}❌ Gateway Timeout (504) - Backend tidak respond dalam waktu yang ditentukan${NC}"
    echo ""
    echo -e "${YELLOW}💡 Solutions:${NC}"
    echo "   1. Backend service mungkin down atau lambat"
    echo "   2. Increase timeout values in kong.yml"
    echo "   3. Check backend service logs"
elif [ "$HTTP_CODE" = "404" ]; then
    echo -e "${YELLOW}⚠️  Not Found (404) - Route mungkin belum di-load${NC}"
    echo "   Try reloading: docker-compose restart kong"
elif [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "400" ]; then
    echo -e "${GREEN}✅ OK - Endpoint responding (${TIME}s) - HTTP $HTTP_CODE${NC}"
    echo "   (401/400 is expected without proper auth/data)"
else
    echo -e "${GREEN}✅ OK - HTTP $HTTP_CODE (${TIME}s)${NC}"
fi
echo ""

# Fix 5: DNS Fix (if needed)
echo "5️⃣  DNS Resolution Check:"
echo "================================================"
echo "Checking if Kong can resolve backend domains..."

DNS_ISSUE=0
DOMAINS=("api-gate.motorsights.com" "api-report-management.motorsights.com")

for domain in "${DOMAINS[@]}"; do
    echo -n "Resolving $domain ... "
    RESOLVED=$(docker exec kong-gateway nslookup "$domain" 2>/dev/null | grep "Address:" | tail -1)
    if [ -z "$RESOLVED" ]; then
        echo -e "${RED}❌ FAILED${NC}"
        DNS_ISSUE=1
    else
        echo -e "${GREEN}✅ OK${NC}"
    fi
done

if [ $DNS_ISSUE -eq 1 ]; then
    echo ""
    echo -e "${YELLOW}💡 DNS Issue detected! Try:${NC}"
    echo "   1. Add DNS server to Kong container:"
    echo "      Edit docker-compose.yml and add:"
    echo "      dns:"
    echo "        - 8.8.8.8"
    echo "        - 8.8.4.4"
    echo ""
    echo "   2. Or restart with clean network:"
    echo "      docker-compose down"
    echo "      docker network prune"
    echo "      docker-compose up -d"
fi
echo ""

# Summary
echo "================================================"
echo "📋 SUMMARY"
echo "================================================"
echo ""
echo -e "${GREEN}✅ Steps completed:${NC}"
echo "  1. Kong container restarted"
echo "  2. Configuration verified"
echo "  3. Backend connectivity tested"
echo "  4. Endpoint tested"
echo "  5. DNS resolution checked"
echo ""
echo -e "${BLUE}📝 If issue persists:${NC}"
echo "  1. Check Kong logs:     docker logs kong-gateway -f"
echo "  2. Check backend status manually"
echo "  3. Run full diagnostic: ./scripts/diagnose-timeout-issue.sh"
echo "  4. Check server resources: docker stats"
echo ""
echo -e "${YELLOW}Common timeout causes in DB-less mode:${NC}"
echo "  • Backend services down or very slow"
echo "  • Network/firewall blocking Kong → Backend"
echo "  • DNS resolution issues"
echo "  • Server resources exhausted (CPU/RAM)"
echo "  • Configuration not loaded properly"
echo ""

