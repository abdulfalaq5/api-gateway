#!/bin/bash

echo "🚀 Quick Fix untuk masalah Docker network di server development"
echo "=============================================================="

# Quick fix 1: Disable IPv6 untuk Docker
echo "1. Disabling IPv6 untuk Docker..."
sudo mkdir -p /etc/docker
cat << EOF | sudo tee /etc/docker/daemon.json
{
    "ipv6": false,
    "dns": ["8.8.8.8", "8.8.4.4", "1.1.1.1"]
}
EOF

# Quick fix 2: Restart Docker
echo "2. Restarting Docker service..."
sudo systemctl restart docker
sleep 3

# Quick fix 3: Test connectivity
echo "3. Testing Docker registry connectivity..."
if curl -I https://registry-1.docker.io/v2/ > /dev/null 2>&1; then
    echo "✅ Koneksi ke Docker registry OK"
else
    echo "❌ Masih ada masalah, mencoba solusi alternatif..."
    
    # Alternative: Use different registry
    echo "Mencoba menggunakan registry alternatif..."
    docker pull gcr.io/kong-docker/kong:3.4 || echo "Registry alternatif juga gagal"
fi

# Quick fix 4: Clear Docker cache
echo "4. Clearing Docker cache..."
docker system prune -f

echo ""
echo "🎯 Quick fix selesai! Coba jalankan:"
echo "docker compose -f docker-compose.dev.yml up -d"
