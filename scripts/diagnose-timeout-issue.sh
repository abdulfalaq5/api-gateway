#!/bin/bash

# Script untuk diagnose timeout issue di Kong DB-less
# Usage: ./diagnose-timeout-issue.sh

echo "================================================"
echo "🔍 KONG DB-LESS TIMEOUT DIAGNOSTIC TOOL"
echo "================================================"
echo "Date: $(date)"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Check if Kong container is running
echo "1️⃣  Checking Kong Container Status:"
echo "================================================"
KONG_RUNNING=$(docker ps --filter "name=kong-gateway" --format "{{.Names}}" 2>/dev/null)
if [ -z "$KONG_RUNNING" ]; then
    echo -e "${RED}❌ Kong container is NOT running!${NC}"
    echo "   Trying to find stopped containers..."
    docker ps -a --filter "name=kong-gateway" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo -e "${YELLOW}💡 SOLUTION: Start Kong container${NC}"
    echo "   docker-compose up -d"
    exit 1
else
    echo -e "${GREEN}✅ Kong container is running: $KONG_RUNNING${NC}"
    docker ps --filter "name=kong-gateway" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
fi
echo ""

# 2. Check Kong container logs for errors
echo "2️⃣  Checking Kong Logs (last 30 lines):"
echo "================================================"
echo "Looking for errors..."
ERRORS=$(docker logs kong-gateway 2>&1 | tail -30 | grep -i "error\|failed\|timeout" || echo "No recent errors found")
if [ "$ERRORS" != "No recent errors found" ]; then
    echo -e "${RED}Found errors:${NC}"
    echo "$ERRORS"
else
    echo -e "${GREEN}✅ No recent errors in logs${NC}"
fi
echo ""

# 3. Check Kong health
echo "3️⃣  Checking Kong Health Status:"
echo "================================================"
KONG_HEALTH=$(curl -s --max-time 5 http://localhost:9546/status 2>/dev/null)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Kong Admin API is responsive${NC}"
    echo "$KONG_HEALTH" | jq '.' 2>/dev/null || echo "$KONG_HEALTH"
else
    echo -e "${RED}❌ Kong Admin API is NOT responsive (timeout)${NC}"
fi
echo ""

# 4. Check if kong.yml is loaded
echo "4️⃣  Checking Kong Configuration:"
echo "================================================"
SERVICE_COUNT=$(curl -s --max-time 5 http://localhost:9546/services 2>/dev/null | jq '.data | length' 2>/dev/null)
ROUTE_COUNT=$(curl -s --max-time 5 http://localhost:9546/routes 2>/dev/null | jq '.data | length' 2>/dev/null)

if [ -z "$SERVICE_COUNT" ] || [ "$SERVICE_COUNT" = "0" ]; then
    echo -e "${RED}❌ No services loaded! Config might not be loaded.${NC}"
    echo -e "${YELLOW}💡 SOLUTION: Reload configuration${NC}"
    echo "   docker-compose restart kong"
else
    echo -e "${GREEN}✅ Services loaded: $SERVICE_COUNT${NC}"
    echo -e "${GREEN}✅ Routes loaded: $ROUTE_COUNT${NC}"
fi
echo ""

# 5. Test backend services connectivity
echo "5️⃣  Testing Backend Services Connectivity:"
echo "================================================"

BACKENDS=(
    "https://api-gate.motorsights.com|SSO Service"
    "https://api-report-management.motorsights.com|Power BI Service"
    "https://api-interview.motorsights.com|Interview Service"
    "https://api-ecatalogue.motorsights.com|E-Catalogue Service"
)

for backend in "${BACKENDS[@]}"; do
    IFS='|' read -r url name <<< "$backend"
    echo -n "Testing $name ($url) ... "
    
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}|%{time_total}" --max-time 10 "$url" 2>/dev/null)
    HTTP_CODE=$(echo "$RESPONSE" | cut -d'|' -f1)
    TIME=$(echo "$RESPONSE" | cut -d'|' -f2)
    
    if [ -z "$HTTP_CODE" ] || [ "$HTTP_CODE" = "000" ]; then
        echo -e "${RED}❌ TIMEOUT or UNREACHABLE${NC}"
    else
        if (( $(echo "$TIME > 5" | bc -l) )); then
            echo -e "${YELLOW}⚠️  SLOW (${TIME}s) - HTTP $HTTP_CODE${NC}"
        else
            echo -e "${GREEN}✅ OK (${TIME}s) - HTTP $HTTP_CODE${NC}"
        fi
    fi
done
echo ""

# 6. Test DNS resolution from Kong container
echo "6️⃣  Testing DNS Resolution from Kong Container:"
echo "================================================"
DOMAINS=(
    "api-gate.motorsights.com"
    "api-report-management.motorsights.com"
    "api-interview.motorsights.com"
    "api-ecatalogue.motorsights.com"
)

for domain in "${DOMAINS[@]}"; do
    echo -n "Resolving $domain ... "
    RESOLVED=$(docker exec kong-gateway nslookup "$domain" 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}')
    if [ -z "$RESOLVED" ]; then
        echo -e "${RED}❌ DNS RESOLUTION FAILED${NC}"
    else
        echo -e "${GREEN}✅ $RESOLVED${NC}"
    fi
done
echo ""

# 7. Check server resources
echo "7️⃣  Checking Server Resources:"
echo "================================================"
echo "Docker Stats (1 second sample):"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" kong-gateway 2>/dev/null || echo "Cannot get docker stats"
echo ""

# 8. Test Kong proxy with timeout
echo "8️⃣  Testing Kong Proxy Endpoints:"
echo "================================================"
TEST_ENDPOINTS=(
    "/api/auth/sso/login|POST"
    "/api/menus|POST"
    "/api/categories|POST"
)

for endpoint_method in "${TEST_ENDPOINTS[@]}"; do
    IFS='|' read -r endpoint method <<< "$endpoint_method"
    echo -n "Testing $method $endpoint ... "
    
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}|%{time_total}" \
        --max-time 10 \
        -X "$method" \
        -H "Content-Type: application/json" \
        -d '{}' \
        "http://localhost:9545$endpoint" 2>/dev/null)
    
    HTTP_CODE=$(echo "$RESPONSE" | cut -d'|' -f1)
    TIME=$(echo "$RESPONSE" | cut -d'|' -f2)
    
    if [ -z "$HTTP_CODE" ] || [ "$HTTP_CODE" = "000" ]; then
        echo -e "${RED}❌ TIMEOUT${NC}"
    elif [ "$HTTP_CODE" = "504" ]; then
        echo -e "${RED}❌ GATEWAY TIMEOUT (504) - Backend tidak respond${NC}"
    elif [ "$HTTP_CODE" = "404" ]; then
        echo -e "${YELLOW}⚠️  NOT FOUND (404) - Route tidak match${NC}"
    elif [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "400" ]; then
        echo -e "${GREEN}✅ OK (${TIME}s) - HTTP $HTTP_CODE${NC}"
    else
        echo -e "${YELLOW}⚠️  HTTP $HTTP_CODE (${TIME}s)${NC}"
    fi
done
echo ""

# 9. Summary and Recommendations
echo "9️⃣  SUMMARY & RECOMMENDATIONS:"
echo "================================================"

# Count issues
ISSUES=0

# Check if Kong is running
if [ -z "$KONG_RUNNING" ]; then
    echo -e "${RED}🔴 CRITICAL: Kong container not running${NC}"
    ((ISSUES++))
fi

# Check if services loaded
if [ -z "$SERVICE_COUNT" ] || [ "$SERVICE_COUNT" = "0" ]; then
    echo -e "${RED}🔴 CRITICAL: No services loaded in Kong${NC}"
    echo "   → Run: docker-compose restart kong"
    ((ISSUES++))
fi

# Provide generic recommendations
if [ $ISSUES -eq 0 ]; then
    echo ""
    echo -e "${YELLOW}Possible causes for timeout:${NC}"
    echo "1. Backend services sedang down atau lambat"
    echo "2. Network issue dari Kong server ke backend"
    echo "3. DNS resolution issue"
    echo "4. Firewall blocking outbound connections"
    echo ""
    echo -e "${GREEN}Quick fixes to try:${NC}"
    echo "1. Restart Kong: docker-compose restart kong"
    echo "2. Check backend services status"
    echo "3. Check Kong logs: docker logs kong-gateway -f"
    echo "4. Increase timeout values in kong.yml if needed"
fi

echo ""
echo "================================================"
echo "✅ Diagnostic Complete!"
echo "================================================"
echo ""
echo "📝 Additional Commands:"
echo "  View Kong logs:        docker logs kong-gateway -f"
echo "  Restart Kong:          docker-compose restart kong"
echo "  Full restart:          docker-compose down && docker-compose up -d"
echo "  Check config:          curl http://localhost:9546/services"
echo ""

