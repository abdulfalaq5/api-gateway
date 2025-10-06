#!/bin/bash

echo "🔍 Mencari dan menggunakan image Kong lokal"
echo "=========================================="

# Cek apakah ada image Kong lokal
echo "1. Mencari image Kong yang sudah ada..."
if docker images | grep -q kong; then
    echo "✅ Ditemukan image Kong lokal:"
    docker images | grep kong
    
    # Gunakan image yang ada
    KONG_IMAGE=$(docker images | grep kong | head -1 | awk '{print $1":"$2}')
    echo "Menggunakan image: $KONG_IMAGE"
    
    # Update docker-compose.dev.yml untuk menggunakan image lokal
    sed -i "s|image: kong:3.4|image: $KONG_IMAGE|g" docker-compose.dev.yml
    echo "✅ docker-compose.dev.yml telah diupdate untuk menggunakan image lokal"
    
else
    echo "❌ Tidak ada image Kong lokal ditemukan"
    
    # Cek apakah ada file kong.tar.gz
    if [ -f "kong.tar.gz" ]; then
        echo "✅ Ditemukan kong.tar.gz, loading image..."
        docker load < kong.tar.gz
        echo "✅ Image Kong berhasil di-load"
        
        # Update docker-compose.dev.yml
        KONG_IMAGE=$(docker images | grep kong | head -1 | awk '{print $1":"$2}')
        sed -i "s|image: kong:3.4|image: $KONG_IMAGE|g" docker-compose.dev.yml
        echo "✅ docker-compose.dev.yml telah diupdate"
    else
        echo "❌ Tidak ada kong.tar.gz ditemukan"
        echo "Mencoba build Kong dari source..."
        
        # Alternative: Build dari Dockerfile jika ada
        if [ -f "Dockerfile" ]; then
            echo "Building Kong dari Dockerfile..."
            docker build -t kong:local .
            sed -i "s|image: kong:3.4|image: kong:local|g" docker-compose.dev.yml
        else
            echo "❌ Tidak ada Dockerfile ditemukan"
            echo "Silakan download image Kong secara manual atau gunakan script fix network"
        fi
    fi
fi

echo ""
echo "🎯 Selesai! Coba jalankan:"
echo "docker compose -f docker-compose.dev.yml up -d"
