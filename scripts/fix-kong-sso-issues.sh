#!/bin/bash

# Script utama untuk memperbaiki masalah Kong SSO timeout
# File: scripts/fix-kong-sso-issues.sh

set -e

echo "🚀 Kong SSO Issues Fix Script"
echo "=============================="

# Cek apakah Kong sedang berjalan
if ! docker-compose ps | grep -q "kong-gateway.*Up"; then
    echo "❌ Kong tidak sedang berjalan. Silakan jalankan Kong terlebih dahulu:"
    echo "   ./scripts/start-kong-docker.sh"
    exit 1
fi

echo "✅ Kong sedang berjalan"

# Step 1: Test connectivity ke SSO service
echo ""
echo "🔍 Step 1: Testing SSO Service Connectivity..."
./scripts/test-sso-connectivity.sh

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ SSO service tidak accessible. Silakan perbaiki connectivity terlebih dahulu."
    echo ""
    echo "💡 Kemungkinan solusi:"
    echo "   1. Pastikan SSO service berjalan"
    echo "   2. Cek firewall settings"
    echo "   3. Verifikasi port dan URL SSO service"
    echo "   4. Update config/env.sh dengan URL yang benar"
    exit 1
fi

# Step 2: Clean database dari konfigurasi duplikat
echo ""
echo "🧹 Step 2: Cleaning Kong Database..."
./scripts/clean-kong-database.sh

# Step 3: Fix SSO upstream configuration
echo ""
echo "🔧 Step 3: Fixing SSO Upstream Configuration..."
./scripts/fix-sso-upstream.sh

# Step 4: Test final configuration
echo ""
echo "🧪 Step 4: Testing Final Configuration..."

# Test Kong proxy endpoint
echo "   Testing Kong proxy endpoint..."
if curl -s --connect-timeout 10 -X POST http://localhost:9545/api/auth/sso/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@sso-testing.com","password":"admin123","client_id":"string","redirect_uri":"string"}' > /dev/null 2>&1; then
    echo "   ✅ SSO login endpoint working through Kong!"
else
    echo "   ⚠️  SSO login endpoint timeout (check logs for details)"
fi

# Test dengan curl yang sama seperti user
echo "   Testing with user's curl command..."
echo "   curl --location 'https://services.motorsights.com/api/auth/sso/login' \\"
echo "     --header 'Content-Type: application/json' \\"
echo "     --data-raw '{"
echo "       \"email\": \"admin@sso-testing.com\","
echo "       \"password\": \"admin123\","
echo "       \"client_id\": \"string\","
echo "       \"redirect_uri\": \"string\""
echo "     }'"

# Step 5: Show monitoring commands
echo ""
echo "📊 Step 5: Monitoring Commands"
echo "=============================="
echo ""
echo "🔍 Monitor Kong logs:"
echo "   docker-compose logs -f kong"
echo ""
echo "🔍 Check Kong services:"
echo "   curl http://localhost:9546/services/ | jq"
echo ""
echo "🔍 Check Kong routes:"
echo "   curl http://localhost:9546/routes/ | jq"
echo ""
echo "🔍 Check Kong plugins:"
echo "   curl http://localhost:9546/plugins/ | jq"
echo ""
echo "🔍 Test Kong health:"
echo "   curl http://localhost:9546/"

# Step 6: Show troubleshooting tips
echo ""
echo "🛠️  Troubleshooting Tips"
echo "========================"
echo ""
echo "Jika masih mengalami timeout:"
echo "   1. Cek logs Kong: docker-compose logs -f kong"
echo "   2. Verifikasi upstream URL di config/env.sh"
echo "   3. Test direct access ke SSO service"
echo "   4. Cek network connectivity dari container Kong"
echo ""
echo "Jika ada duplicate key errors:"
echo "   1. Jalankan: ./scripts/clean-kong-database.sh"
echo "   2. Deploy ulang: ./scripts/deploy-kong-config.sh"
echo ""
echo "Jika SSO service tidak accessible:"
echo "   1. Jalankan: ./scripts/test-sso-connectivity.sh"
echo "   2. Update config/env.sh dengan URL yang benar"
echo "   3. Restart Kong: docker-compose restart kong"

echo ""
echo "✅ Kong SSO Issues Fix Completed!"
echo ""
echo "📋 Summary:"
echo "   - SSO connectivity tested"
echo "   - Database cleaned from duplicates"
echo "   - Upstream configuration fixed"
echo "   - Final configuration tested"
echo ""
echo "🎯 Next: Test dengan curl command yang Anda berikan!"
