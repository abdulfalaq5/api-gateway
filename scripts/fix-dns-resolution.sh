#!/bin/bash

# Script untuk memperbaiki masalah DNS resolution host.docker.internal di Kong
# File: scripts/fix-dns-resolution.sh

set -e

echo "🔧 Memperbaiki masalah DNS resolution host.docker.internal di Kong..."

# 1. Cek apakah Kong sedang berjalan
echo "🔍 Checking Kong status..."
if docker ps | grep -q "kong-gateway.*Up"; then
    echo "⚠️  Kong sedang berjalan. Menghentikan terlebih dahulu..."
    docker-compose -f docker-compose.server.yml down
    sleep 5
fi

# 2. Backup konfigurasi saat ini
echo "💾 Membuat backup konfigurasi..."
cp docker-compose.server.yml docker-compose.server.yml.backup.$(date +%Y%m%d_%H%M%S)

# 3. Periksa apakah ada service yang menggunakan host.docker.internal
echo "🔍 Checking Kong services configuration..."
if curl -s http://localhost:9546/services 2>/dev/null | grep -q "host.docker.internal"; then
    echo "⚠️  Ditemukan service yang menggunakan host.docker.internal"
    echo "📋 Services yang perlu diperbaiki:"
    curl -s http://localhost:9546/services | jq '.data[] | select(.url | contains("host.docker.internal")) | {name: .name, url: .url}' 2>/dev/null || echo "   Tidak bisa mengakses Kong Admin API"
else
    echo "✅ Tidak ada service yang menggunakan host.docker.internal"
fi

# 4. Restart Kong dengan konfigurasi yang sudah diperbaiki
echo "🚀 Restarting Kong dengan DNS resolution fix..."
docker-compose -f docker-compose.server.yml up -d

# 5. Tunggu Kong start
echo "⏳ Waiting for Kong to start..."
sleep 15

# 6. Test Kong health
echo "🔍 Testing Kong health..."
if curl -s http://localhost:9546/status | grep -q "database"; then
    echo "✅ Kong berhasil dijalankan dengan DNS resolution fix!"
    echo ""
    echo "📋 Endpoints yang tersedia:"
    echo "   - Kong Proxy: http://localhost:9545"
    echo "   - Kong Admin API: http://localhost:9546"
    echo "   - Kong Admin GUI: http://localhost:9547"
    echo ""
    echo "🧪 Test Kong:"
    echo "   curl http://localhost:9545/"
    echo "   curl http://localhost:9546/"
else
    echo "❌ Kong gagal dijalankan. Cek log:"
    echo "   docker logs kong-gateway"
    exit 1
fi

# 7. Test DNS resolution
echo "🔍 Testing DNS resolution..."
if docker exec kong-gateway nslookup host.docker.internal >/dev/null 2>&1; then
    echo "✅ DNS resolution untuk host.docker.internal berhasil!"
else
    echo "⚠️  DNS resolution masih bermasalah. Coba solusi alternatif..."
    
    # Solusi alternatif: tambahkan IP host secara manual
    HOST_IP=$(ip route show default | awk '/default/ {print $3}')
    echo "🔧 Menambahkan host IP secara manual: $HOST_IP"
    
    # Update docker-compose dengan IP host yang spesifik
    sed -i "s/host.docker.internal:host-gateway/host.docker.internal:$HOST_IP/g" docker-compose.server.yml
    
    # Restart Kong lagi
    docker-compose -f docker-compose.server.yml down
    docker-compose -f docker-compose.server.yml up -d
    sleep 15
    
    # Test lagi
    if docker exec kong-gateway nslookup host.docker.internal >/dev/null 2>&1; then
        echo "✅ DNS resolution berhasil dengan IP host manual!"
    else
        echo "❌ DNS resolution masih bermasalah. Perlu investigasi lebih lanjut."
        echo "💡 Saran:"
        echo "   1. Pastikan Docker Desktop berjalan dengan benar"
        echo "   2. Cek network configuration Docker"
        echo "   3. Gunakan IP address langsung sebagai gantinya"
    fi
fi

echo ""
echo "🎉 Proses perbaikan DNS resolution selesai!"
echo "📝 Log Kong: docker logs kong-gateway -f"
