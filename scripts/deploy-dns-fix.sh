#!/bin/bash

# Quick deployment script untuk DNS fix
# Usage: ./deploy-dns-fix.sh

echo "================================================"
echo "🚀 DEPLOY DNS FIX FOR KONG GATEWAY"
echo "================================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect which docker-compose file to use
COMPOSE_FILE="docker-compose.server.yml"
if [ ! -f "$COMPOSE_FILE" ]; then
    COMPOSE_FILE="docker-compose.yml"
fi

echo -e "${BLUE}Using compose file: $COMPOSE_FILE${NC}"
echo ""

# Step 1: Backup
echo "1️⃣  Creating Backup..."
echo "================================================"
BACKUP_FILE="${COMPOSE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$COMPOSE_FILE" "$BACKUP_FILE"
echo -e "${GREEN}✅ Backup created: $BACKUP_FILE${NC}"
echo ""

# Step 2: Show changes
echo "2️⃣  Checking Current Configuration..."
echo "================================================"
if grep -q "dns:" "$COMPOSE_FILE"; then
    echo -e "${GREEN}✅ DNS configuration already present${NC}"
    echo ""
    echo "Current DNS servers:"
    grep -A 3 "dns:" "$COMPOSE_FILE" | grep -v "^--$"
else
    echo -e "${RED}❌ DNS configuration NOT found${NC}"
    echo -e "${YELLOW}Please update $COMPOSE_FILE manually or use the updated version${NC}"
    exit 1
fi
echo ""

# Step 3: Confirm restart
echo "3️⃣  Ready to Deploy..."
echo "================================================"
echo -e "${YELLOW}This will restart Kong container with DNS fix${NC}"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi
echo ""

# Step 4: Restart Kong
echo "4️⃣  Stopping Kong..."
echo "================================================"
docker-compose -f "$COMPOSE_FILE" down
echo -e "${GREEN}✅ Kong stopped${NC}"
echo ""

echo "5️⃣  Starting Kong with DNS Fix..."
echo "================================================"
docker-compose -f "$COMPOSE_FILE" up -d
echo -e "${GREEN}✅ Kong started${NC}"
echo ""

# Step 5: Wait for Kong to be ready
echo "6️⃣  Waiting for Kong to be ready..."
echo "================================================"
echo -n "Waiting"
for i in {1..15}; do
    echo -n "."
    sleep 1
done
echo " Done!"
echo ""

# Step 6: Verify
echo "7️⃣  Verifying Deployment..."
echo "================================================"

# Check container status
CONTAINER_STATUS=$(docker ps --filter "name=kong-gateway" --format "{{.Status}}")
if [ -n "$CONTAINER_STATUS" ]; then
    echo -e "${GREEN}✅ Container Status: $CONTAINER_STATUS${NC}"
else
    echo -e "${RED}❌ Container not running!${NC}"
    exit 1
fi

# Check Kong health
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9546/status 2>/dev/null)
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✅ Kong Admin API: Healthy (HTTP 200)${NC}"
else
    echo -e "${RED}❌ Kong Admin API: Not responding (HTTP $HTTP_CODE)${NC}"
fi

# Check DNS resolution
echo ""
echo "Testing DNS Resolution from Kong:"
DNS_TEST=$(docker exec kong-gateway nslookup api-gate.motorsights.com 2>/dev/null | grep "Address:" | tail -1)
if [ -n "$DNS_TEST" ]; then
    echo -e "${GREEN}✅ DNS Resolution: Working${NC}"
    echo "   $DNS_TEST"
else
    echo -e "${RED}❌ DNS Resolution: Failed${NC}"
fi

# Check backend connectivity
echo ""
echo "Testing Backend Connectivity from Kong:"
BACKEND_TEST=$(docker exec kong-gateway curl -s -o /dev/null -w "%{http_code}" --max-time 5 https://api-gate.motorsights.com 2>/dev/null)
if [ -n "$BACKEND_TEST" ] && [ "$BACKEND_TEST" != "000" ]; then
    echo -e "${GREEN}✅ Backend Connectivity: OK (HTTP $BACKEND_TEST)${NC}"
else
    echo -e "${RED}❌ Backend Connectivity: Timeout${NC}"
    echo -e "${YELLOW}   Note: Masalah mungkin bukan DNS, cek firewall atau backend status${NC}"
fi

echo ""
echo "================================================"
echo "✅ DEPLOYMENT COMPLETE!"
echo "================================================"
echo ""
echo "📋 Summary:"
echo "  - Backup: $BACKUP_FILE"
echo "  - Config: $COMPOSE_FILE (with DNS fix)"
echo "  - Container: Running"
echo "  - Admin API: http://localhost:9546"
echo "  - Proxy API: http://localhost:9545"
echo ""
echo "📝 Next Steps:"
echo "  1. Test your endpoints"
echo "  2. Monitor Kong logs: docker logs kong-gateway -f"
echo "  3. Run full diagnostic: ./scripts/diagnose-timeout-issue.sh"
echo ""

# Show Kong logs preview
echo "📄 Kong Logs (last 10 lines):"
echo "================================================"
docker logs kong-gateway --tail 10 2>&1 | grep -v "^$"
echo ""

echo -e "${GREEN}🎉 Deployment successful!${NC}"
echo ""

