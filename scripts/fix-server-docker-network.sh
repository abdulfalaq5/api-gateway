#!/bin/bash

echo "🔧 Memperbaiki masalah network Docker di server development..."
echo "=================================================="

# 1. Cek konektivitas internet
echo "1. Mengecek konektivitas internet..."
if ping -c 3 8.8.8.8 > /dev/null 2>&1; then
    echo "✅ Koneksi internet OK"
else
    echo "❌ Tidak ada koneksi internet"
    exit 1
fi

# 2. Cek DNS resolution
echo "2. Mengecek DNS resolution..."
if nslookup registry-1.docker.io > /dev/null 2>&1; then
    echo "✅ DNS resolution OK"
else
    echo "❌ DNS resolution bermasalah"
    echo "Mencoba menggunakan DNS alternatif..."
    
    # Backup DNS config
    sudo cp /etc/resolv.conf /etc/resolv.conf.backup
    
    # Set DNS alternatif
    echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
    echo "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf
    echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf
    
    echo "✅ DNS alternatif telah diset"
fi

# 3. Cek IPv6 (sering menyebabkan masalah)
echo "3. Mengecek konfigurasi IPv6..."
if ip -6 addr show | grep -q "inet6"; then
    echo "⚠️  IPv6 terdeteksi, mungkin menyebabkan masalah"
    echo "Mencoba disable IPv6 untuk Docker..."
    
    # Disable IPv6 untuk Docker
    sudo mkdir -p /etc/docker
    echo '{"ipv6": false, "fixed-cidr-v6": ""}' | sudo tee /etc/docker/daemon.json
    
    echo "✅ IPv6 disabled untuk Docker"
    echo "Restart Docker service diperlukan..."
    sudo systemctl restart docker
    sleep 5
fi

# 4. Cek proxy settings
echo "4. Mengecek proxy settings..."
if [ ! -z "$HTTP_PROXY" ] || [ ! -z "$HTTPS_PROXY" ]; then
    echo "⚠️  Proxy terdeteksi:"
    echo "HTTP_PROXY: $HTTP_PROXY"
    echo "HTTPS_PROXY: $HTTPS_PROXY"
    
    # Configure Docker untuk proxy
    sudo mkdir -p /etc/systemd/system/docker.service.d
    cat << EOF | sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=$HTTP_PROXY"
Environment="HTTPS_PROXY=$HTTPS_PROXY"
Environment="NO_PROXY=localhost,127.0.0.1"
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl restart docker
    echo "✅ Docker proxy configuration updated"
fi

# 5. Test Docker registry connectivity
echo "5. Menguji konektivitas ke Docker registry..."
if curl -I https://registry-1.docker.io/v2/ > /dev/null 2>&1; then
    echo "✅ Koneksi ke Docker registry OK"
else
    echo "❌ Masih ada masalah koneksi ke Docker registry"
    echo "Mencoba menggunakan registry mirror..."
    
    # Configure registry mirror
    sudo mkdir -p /etc/docker
    cat << EOF | sudo tee /etc/docker/daemon.json
{
    "registry-mirrors": [
        "https://mirror.gcr.io",
        "https://registry-1.docker.io"
    ],
    "ipv6": false
}
EOF
    
    sudo systemctl restart docker
    echo "✅ Registry mirror configured"
fi

# 6. Test pull image
echo "6. Menguji pull image Kong..."
if docker pull kong:3.4 > /dev/null 2>&1; then
    echo "✅ Berhasil pull image Kong"
else
    echo "❌ Gagal pull image Kong"
    echo "Mencoba solusi alternatif..."
    
    # Alternative: Use local image atau build dari source
    echo "Menggunakan image Kong yang sudah ada atau build lokal..."
fi

echo ""
echo "🎯 Selesai! Coba jalankan lagi:"
echo "docker compose -f docker-compose.dev.yml up -d"
echo ""
echo "Jika masih bermasalah, coba:"
echo "1. Restart Docker: sudo systemctl restart docker"
echo "2. Clear Docker cache: docker system prune -f"
echo "3. Gunakan image lokal jika ada"
