#!/bin/bash

# Script untuk membersihkan database Kong dari konfigurasi duplikat
# File: scripts/clean-kong-database.sh

set -e

echo "🧹 Cleaning Kong Database from Duplicate Configurations..."

# Cek apakah Kong sedang berjalan
if ! docker-compose ps | grep -q "kong-gateway.*Up"; then
    echo "❌ Kong tidak sedang berjalan. Silakan jalankan Kong terlebih dahulu:"
    echo "   ./scripts/start-kong-docker.sh"
    exit 1
fi

echo "✅ Kong sedang berjalan"

# Backup konfigurasi saat ini
echo "📦 Creating backup..."
BACKUP_FILE="kong_backup_$(date +%Y%m%d_%H%M%S).json"
curl -s http://localhost:9546/config > "$BACKUP_FILE"
echo "   Backup tersimpan di: $BACKUP_FILE"

# Fungsi untuk menghapus dengan error handling
delete_resource() {
    local resource_type=$1
    local resource_name=$2
    local url="http://localhost:9546/$resource_type/$resource_name"
    
    echo "   Removing $resource_type: $resource_name"
    response=$(curl -s -w "%{http_code}" -X DELETE "$url")
    http_code="${response: -3}"
    
    if [ "$http_code" = "204" ]; then
        echo "     ✅ Berhasil dihapus"
    elif [ "$http_code" = "404" ]; then
        echo "     ⚠️  Tidak ditemukan (sudah dihapus)"
    else
        echo "     ❌ Gagal dihapus (HTTP $http_code)"
    fi
}

# 1. Hapus semua plugins yang terkait dengan SSO
echo "🗑️  Removing SSO-related plugins..."

# Hapus plugins dari service sso-service
echo "   Removing plugins from sso-service..."
curl -s http://localhost:9546/services/sso-service/plugins/ | jq -r '.data[].id' 2>/dev/null | while read plugin_id; do
    if [ ! -z "$plugin_id" ]; then
        delete_resource "services/sso-service/plugins" "$plugin_id"
    fi
done

# Hapus global plugins yang duplikat
echo "   Removing global plugins..."
curl -s http://localhost:9546/plugins/ | jq -r '.data[] | select(.name == "cors" or .name == "rate-limiting") | .id' 2>/dev/null | while read plugin_id; do
    if [ ! -z "$plugin_id" ]; then
        delete_resource "plugins" "$plugin_id"
    fi
done

# 2. Hapus semua routes yang terkait dengan SSO
echo "🗑️  Removing SSO routes..."

routes=("sso-login-routes" "sso-userinfo-routes" "sso-menus-routes")
for route in "${routes[@]}"; do
    delete_resource "routes" "$route"
done

# 3. Hapus service sso-service
echo "🗑️  Removing SSO service..."
delete_resource "services" "sso-service"

# 4. Hapus service example-service jika ada
echo "🗑️  Removing example service..."
delete_resource "services" "example-service"

# 5. Verifikasi pembersihan
echo "🔍 Verifying cleanup..."

# Cek services
services_count=$(curl -s http://localhost:9546/services/ | jq 'length' 2>/dev/null || echo "0")
echo "   Services remaining: $services_count"

# Cek routes
routes_count=$(curl -s http://localhost:9546/routes/ | jq 'length' 2>/dev/null || echo "0")
echo "   Routes remaining: $routes_count"

# Cek plugins
plugins_count=$(curl -s http://localhost:9546/plugins/ | jq 'length' 2>/dev/null || echo "0")
echo "   Plugins remaining: $plugins_count"

# 6. Reset Kong configuration
echo "🔄 Resetting Kong configuration..."

# Reload Kong untuk memastikan perubahan diterapkan
echo "   Reloading Kong..."
curl -s -X POST http://localhost:9546/config?check_hash=1 > /dev/null

echo ""
echo "✅ Database cleanup completed!"
echo ""
echo "📋 Summary:"
echo "   - Backup created: $BACKUP_FILE"
echo "   - Services removed: SSO and example services"
echo "   - Routes removed: All SSO routes"
echo "   - Plugins removed: All SSO-related plugins"
echo ""
echo "🔄 Next steps:"
echo "   1. Deploy fresh configuration:"
echo "      ./scripts/deploy-kong-config.sh"
echo "   2. Or fix SSO upstream specifically:"
echo "      ./scripts/fix-sso-upstream.sh"
echo ""
echo "🔄 Jika ada masalah, rollback dengan:"
echo "   curl -X POST http://localhost:9546/config -F \"config=@$BACKUP_FILE\""
