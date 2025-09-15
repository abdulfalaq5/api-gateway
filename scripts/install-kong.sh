#!/bin/bash

# Kong API Gateway Setup Script
# Script ini akan menginstall Kong dan PostgreSQL di macOS

set -e

echo "🚀 Memulai instalasi Kong API Gateway..."

# Cek apakah Homebrew sudah terinstall
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew tidak ditemukan. Silakan install Homebrew terlebih dahulu:"
    echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi

echo "✅ Homebrew ditemukan"

# Update Homebrew
echo "🔄 Mengupdate Homebrew..."
brew update

# Install PostgreSQL
echo "🐘 Menginstall PostgreSQL..."
if ! command -v psql &> /dev/null; then
    brew install postgresql@15
    brew services start postgresql@15
    echo "✅ PostgreSQL berhasil diinstall dan dijalankan"
else
    echo "✅ PostgreSQL sudah terinstall"
fi

# Install Kong
echo "🦍 Menginstall Kong..."
if ! command -v kong &> /dev/null; then
    brew tap kong/kong
    brew install kong
    echo "✅ Kong berhasil diinstall"
else
    echo "✅ Kong sudah terinstall"
fi

# Setup PostgreSQL database untuk Kong
echo "🗄️ Setup database Kong..."
DB_HOST="localhost"
DB_PORT="5432"
DB_USER="falaqmsi"
DB_PASS="Rubysa179596"
DB_NAME="kong"

# Buat database kong jika belum ada
PGPASSWORD=$DB_PASS psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d postgres -c "CREATE DATABASE kong;" 2>/dev/null || echo "Database kong sudah ada"

# Migrasi database Kong
echo "🔄 Menjalankan migrasi database Kong..."
kong migrations bootstrap --conf /Users/falaqmsi/Documents/GitHub/kong-api-gateway/config/kong.conf

echo "✅ Setup Kong selesai!"
echo ""
echo "📋 Informasi penting:"
echo "   - Kong Admin API: http://localhost:9546"
echo "   - Kong Admin GUI: http://localhost:9547"
echo "   - Kong Proxy: http://localhost:9545"
echo "   - Database: PostgreSQL di localhost:5432"
echo ""
echo "🚀 Untuk menjalankan Kong, gunakan:"
echo "   ./scripts/start-kong.sh"
echo ""
echo "🛑 Untuk menghentikan Kong, gunakan:"
echo "   ./scripts/stop-kong.sh"
