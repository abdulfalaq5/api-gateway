#!/bin/bash

# Script untuk mengatasi masalah DNS resolution di Kong dengan solusi alternatif
# File: scripts/fix-kong-dns-alternative.sh

set -e

echo "🔧 Mengatasi masalah DNS resolution Kong dengan solusi alternatif..."

# 1. Cek apakah Kong sedang berjalan
echo "🔍 Checking Kong status..."
if docker ps | grep -q "kong-gateway.*Up"; then
    echo "⚠️  Kong sedang berjalan. Menghentikan terlebih dahulu..."
    docker-compose -f docker-compose.server.yml down
    sleep 5
fi

# 2. Backup konfigurasi
echo "💾 Membuat backup konfigurasi..."
cp docker-compose.server.yml docker-compose.server.yml.backup.$(date +%Y%m%d_%H%M%S)

# 3. Solusi 1: Tambahkan DNS server secara eksplisit
echo "🔧 Solusi 1: Menambahkan DNS server secara eksplisit..."
cat > docker-compose.server.yml.tmp << 'EOF'
version: '3.8'

services:
  kong-migrations:
    image: kong:3.4
    container_name: kong-migrations
    environment:
      KONG_DATABASE: postgres
      KONG_PG_HOST: 162.11.0.232
      KONG_PG_PORT: 5432
      KONG_PG_USER: sharedpg
      KONG_PG_PASSWORD: pgpass
      KONG_PG_DATABASE: kong
    command: kong migrations bootstrap
    restart: "no"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    dns:
      - 8.8.8.8
      - 8.8.4.4

  kong:
    image: kong:3.4
    container_name: kong-gateway
    environment:
      KONG_DATABASE: postgres
      KONG_PG_HOST: 162.11.0.232
      KONG_PG_PORT: 5432
      KONG_PG_USER: sharedpg
      KONG_PG_PASSWORD: pgpass
      KONG_PG_DATABASE: kong
      KONG_PROXY_LISTEN: 0.0.0.0:9545
      KONG_ADMIN_LISTEN: 0.0.0.0:9546
      KONG_ADMIN_GUI_LISTEN: 0.0.0.0:9547
      KONG_PROXY_ACCESS_LOG: /dev/stdout
      KONG_ADMIN_ACCESS_LOG: /dev/stdout
      KONG_PROXY_ERROR_LOG: /dev/stderr
      KONG_ADMIN_ERROR_LOG: /dev/stderr
      KONG_ADMIN_GUI_ERROR_LOG: /dev/stderr
    depends_on:
      kong-migrations:
        condition: service_completed_successfully
    ports:
      - "9545:9545"
      - "9546:9546"
      - "9547:9547"
    healthcheck:
      test: ["CMD", "kong", "health"]
      interval: 10s
      timeout: 10s
      retries: 10
    restart: unless-stopped
    extra_hosts:
      - "host.docker.internal:host-gateway"
    dns:
      - 8.8.8.8
      - 8.8.4.4
EOF

# 4. Ganti konfigurasi
mv docker-compose.server.yml.tmp docker-compose.server.yml

# 5. Restart Kong
echo "🚀 Restarting Kong dengan DNS server eksplisit..."
docker-compose -f docker-compose.server.yml up -d

# 6. Tunggu Kong start
echo "⏳ Waiting for Kong to start..."
sleep 15

# 7. Test Kong health
echo "🔍 Testing Kong health..."
if curl -s http://localhost:9546/status | grep -q "database"; then
    echo "✅ Kong berhasil dijalankan dengan DNS server eksplisit!"
else
    echo "❌ Kong gagal dijalankan. Mencoba solusi alternatif..."
    
    # Solusi 2: Gunakan network mode host
    echo "🔧 Solusi 2: Menggunakan network mode host..."
    docker-compose -f docker-compose.server.yml down
    
    # Update konfigurasi dengan network mode host
    sed -i 's/extra_hosts:/# extra_hosts:/g' docker-compose.server.yml
    sed -i 's/dns:/# dns:/g' docker-compose.server.yml
    sed -i 's/- "host.docker.internal:host-gateway"/# - "host.docker.internal:host-gateway"/g' docker-compose.server.yml
    sed -i 's/- 8.8.8.8/# - 8.8.8.8/g' docker-compose.server.yml
    sed -i 's/- 8.8.4.4/# - 8.8.4.4/g' docker-compose.server.yml
    
    # Tambahkan network mode host
    sed -i '/restart: unless-stopped/a\    network_mode: host' docker-compose.server.yml
    
    # Restart Kong dengan network mode host
    docker-compose -f docker-compose.server.yml up -d
    sleep 15
    
    # Test lagi
    if curl -s http://localhost:9546/status | grep -q "database"; then
        echo "✅ Kong berhasil dijalankan dengan network mode host!"
    else
        echo "❌ Kong masih gagal. Perlu investigasi lebih lanjut."
        echo "💡 Saran:"
        echo "   1. Cek log Kong: docker logs kong-gateway"
        echo "   2. Pastikan port 9545, 9546, 9547 tidak digunakan aplikasi lain"
        echo "   3. Cek firewall settings"
        exit 1
    fi
fi

echo ""
echo "🎉 Proses perbaikan DNS resolution selesai!"
echo "📝 Log Kong: docker logs kong-gateway -f"
echo "🔍 Test Kong: curl http://localhost:9545/"
