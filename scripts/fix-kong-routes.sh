#!/bin/bash

# Script untuk memperbaiki konfigurasi Kong routes
# File: scripts/fix-kong-routes.sh

set -e

echo "🔧 Fixing Kong Routes Configuration..."

# Hapus semua routes yang salah
echo "🗑️  Removing incorrect routes..."
curl -s -X DELETE http://localhost:9546/routes/sso-userinfo-routes 2>/dev/null || echo "   Route sso-userinfo-routes tidak ada"
curl -s -X DELETE http://localhost:9546/routes/sso-login-routes 2>/dev/null || echo "   Route sso-login-routes tidak ada"
curl -s -X DELETE http://localhost:9546/routes/sso-menus-routes 2>/dev/null || echo "   Route sso-menus-routes tidak ada"

# Tambahkan routes yang benar sesuai kong.yml
echo "📝 Adding correct SSO routes..."

# SSO Login Route
echo "   Adding sso-login-routes..."
curl -s -X POST http://localhost:9546/services/sso-service/routes \
  -d "name=sso-login-routes" \
  -d "paths[]=/api/auth/sso/login" \
  -d "methods[]=POST" \
  -d "methods[]=OPTIONS" \
  -d "strip_path=false"

# SSO Userinfo Route
echo "   Adding sso-userinfo-routes..."
curl -s -X POST http://localhost:9546/services/sso-service/routes \
  -d "name=sso-userinfo-routes" \
  -d "paths[]=/api/auth/sso/userinfo" \
  -d "methods[]=GET" \
  -d "methods[]=OPTIONS" \
  -d "strip_path=true"

# SSO Menus Route
echo "   Adding sso-menus-routes..."
curl -s -X POST http://localhost:9546/services/sso-service/routes \
  -d "name=sso-menus-routes" \
  -d "paths[]=/api/menus" \
  -d "methods[]=GET" \
  -d "methods[]=POST" \
  -d "methods[]=PUT" \
  -d "methods[]=DELETE" \
  -d "methods[]=OPTIONS" \
  -d "strip_path=true"

# Verifikasi routes
echo "🔍 Verifying routes..."
curl -s http://localhost:9546/routes/ | jq '.data[] | {name: .name, paths: .paths, methods: .methods}'

echo ""
echo "✅ Routes fixed!"
echo ""
echo "🧪 Test endpoints:"
echo "   - SSO Login: curl -X POST http://localhost:9545/api/auth/sso/login"
echo "   - SSO Userinfo: curl http://localhost:9545/api/auth/sso/userinfo"
echo "   - SSO Menus: curl http://localhost:9545/api/menus"
echo "   - Example: curl http://localhost:9545/api/v1/example"
