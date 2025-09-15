#!/bin/bash

# Script untuk rollback konfigurasi Kong ke backup sebelumnya
# File: scripts/rollback-kong-config.sh

set -e

echo "🔄 Rolling back Kong Configuration..."

# Cek apakah Kong sedang berjalan
if ! docker-compose ps | grep -q "kong-gateway.*Up"; then
    echo "❌ Kong tidak sedang berjalan. Silakan jalankan Kong terlebih dahulu:"
    echo "   ./scripts/start-kong-docker.sh"
    exit 1
fi

echo "✅ Kong sedang berjalan"

# Cari file backup terbaru
BACKUP_FILES=$(ls kong_backup_*.json 2>/dev/null | sort -r)
if [ -z "$BACKUP_FILES" ]; then
    echo "❌ Tidak ada file backup ditemukan!"
    echo "   Pastikan ada file kong_backup_*.json di direktori ini"
    exit 1
fi

# Ambil file backup terbaru
LATEST_BACKUP=$(echo "$BACKUP_FILES" | head -1)
echo "📦 Menggunakan backup: $LATEST_BACKUP"

# Backup konfigurasi saat ini sebelum rollback
CURRENT_BACKUP="kong_current_before_rollback_$(date +%Y%m%d_%H%M%S).json"
curl -s http://localhost:9546/config > "$CURRENT_BACKUP"
echo "   Backup konfigurasi saat ini: $CURRENT_BACKUP"

# Rollback ke konfigurasi sebelumnya
echo "🔄 Rolling back configuration..."
ROLLBACK_RESPONSE=$(curl -s -w "%{http_code}" -X POST http://localhost:9546/config -F "config=@$LATEST_BACKUP")
HTTP_CODE="${ROLLBACK_RESPONSE: -3}"

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo "   ✅ Rollback berhasil (HTTP $HTTP_CODE)"
else
    echo "   ❌ Rollback gagal (HTTP $HTTP_CODE)"
    echo "   Response: ${ROLLBACK_RESPONSE%???}"
    exit 1
fi

# Verifikasi rollback
echo "🔍 Verifying rollback..."

# Cek services
SERVICES_COUNT=$(curl -s http://localhost:9546/services/ | jq 'length' 2>/dev/null || echo "0")
echo "   Services restored: $SERVICES_COUNT"

# Cek routes
ROUTES_COUNT=$(curl -s http://localhost:9546/routes/ | jq 'length' 2>/dev/null || echo "0")
echo "   Routes restored: $ROUTES_COUNT"

# Cek plugins
PLUGINS_COUNT=$(curl -s http://localhost:9546/plugins/ | jq 'length' 2>/dev/null || echo "0")
echo "   Plugins restored: $PLUGINS_COUNT"

# Test endpoint
echo "🧪 Testing endpoints..."

# Test Kong Proxy
if curl -s http://localhost:9545/ > /dev/null 2>&1; then
    echo "   ✅ Kong Proxy accessible"
else
    echo "   ❌ Kong Proxy tidak dapat diakses"
fi

# Test Admin API
if curl -s http://localhost:9546/ > /dev/null 2>&1; then
    echo "   ✅ Kong Admin API accessible"
else
    echo "   ❌ Kong Admin API tidak dapat diakses"
fi

echo ""
echo "✅ Rollback completed!"
echo ""
echo "📋 Configuration restored from: $LATEST_BACKUP"
echo "📋 Current config backed up as: $CURRENT_BACKUP"
echo ""
echo "🧪 Test endpoints:"
echo "   - Kong Proxy: curl http://localhost:9545/"
echo "   - Admin API: curl http://localhost:9546/"
echo "   - Services: curl http://localhost:9546/services/"
echo "   - Routes: curl http://localhost:9546/routes/"
