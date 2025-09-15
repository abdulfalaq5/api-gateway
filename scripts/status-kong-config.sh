#!/bin/bash

# Script untuk melihat status konfigurasi Kong
# File: scripts/status-kong-config.sh

set -e

echo "📊 Kong Configuration Status"
echo "=============================="

# Cek apakah Kong sedang berjalan
if ! docker-compose ps | grep -q "kong-gateway.*Up"; then
    echo "❌ Kong tidak sedang berjalan!"
    echo "   Jalankan: ./scripts/start-kong-docker.sh"
    exit 1
fi

echo "✅ Kong sedang berjalan"
echo ""

# Cek Kong status
echo "🏥 Kong Health Status:"
curl -s http://localhost:9546/status | jq '.' 2>/dev/null || echo "   Tidak dapat mengakses status Kong"
echo ""

# Cek services
echo "🔧 Services:"
SERVICES=$(curl -s http://localhost:9546/services/ 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "$SERVICES" | jq -r '.[] | "   - \(.name): \(.url)"' 2>/dev/null || echo "   Tidak ada services atau error parsing"
else
    echo "   ❌ Tidak dapat mengakses services"
fi
echo ""

# Cek routes
echo "🛣️  Routes:"
ROUTES=$(curl -s http://localhost:9546/routes/ 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "$ROUTES" | jq -r '.[] | "   - \(.name): \(.paths | join(", ")) (\(.methods | join(", ")))"' 2>/dev/null || echo "   Tidak ada routes atau error parsing"
else
    echo "   ❌ Tidak dapat mengakses routes"
fi
echo ""

# Cek plugins
echo "🔌 Plugins:"
PLUGINS=$(curl -s http://localhost:9546/plugins/ 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "$PLUGINS" | jq -r '.[] | "   - \(.name) (Service: \(.service.name // "Global"))"' 2>/dev/null || echo "   Tidak ada plugins atau error parsing"
else
    echo "   ❌ Tidak dapat mengakses plugins"
fi
echo ""

# Cek consumers
echo "👥 Consumers:"
CONSUMERS=$(curl -s http://localhost:9546/consumers/ 2>/dev/null)
if [ $? -eq 0 ]; then
    CONSUMER_COUNT=$(echo "$CONSUMERS" | jq 'length' 2>/dev/null || echo "0")
    echo "   Total consumers: $CONSUMER_COUNT"
    if [ "$CONSUMER_COUNT" -gt 0 ]; then
        echo "$CONSUMERS" | jq -r '.[] | "   - \(.username // .id)"' 2>/dev/null || echo "   Error parsing consumers"
    fi
else
    echo "   ❌ Tidak dapat mengakses consumers"
fi
echo ""

# Test endpoint connectivity
echo "🧪 Endpoint Tests:"
echo "   Kong Proxy (9545): $(curl -s -o /dev/null -w "%{http_code}" http://localhost:9545/ || echo "ERROR")"
echo "   Admin API (9546): $(curl -s -o /dev/null -w "%{http_code}" http://localhost:9546/ || echo "ERROR")"
echo "   Admin GUI (9547): $(curl -s -o /dev/null -w "%{http_code}" http://localhost:9547/ || echo "ERROR")"
echo ""

# Cek backup files
echo "💾 Backup Files:"
BACKUP_FILES=$(ls kong_backup_*.json 2>/dev/null | wc -l)
if [ "$BACKUP_FILES" -gt 0 ]; then
    echo "   Total backup files: $BACKUP_FILES"
    echo "   Latest backup: $(ls kong_backup_*.json 2>/dev/null | sort -r | head -1)"
else
    echo "   Tidak ada file backup"
fi
echo ""

# Cek log errors
echo "📝 Recent Log Errors:"
docker-compose logs --tail=20 kong 2>/dev/null | grep -i error | tail -5 || echo "   Tidak ada error dalam log terakhir"
echo ""

echo "✅ Status check completed!"
echo ""
echo "📋 Quick Commands:"
echo "   - Deploy config: ./scripts/deploy-kong-config.sh"
echo "   - Rollback config: ./scripts/rollback-kong-config.sh"
echo "   - View logs: docker-compose logs -f kong"
echo "   - Restart Kong: docker-compose restart kong"
