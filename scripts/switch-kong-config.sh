#!/bin/bash

# Script untuk switch antara konfigurasi lokal dan server
# File: scripts/switch-kong-config.sh

set -e

ENV=${1:-"local"}

echo "🔄 Switching Kong configuration to: $ENV"

# Validasi parameter
if [ "$ENV" != "local" ] && [ "$ENV" != "server" ]; then
    echo "❌ Invalid environment. Use 'local' or 'server'"
    echo "Usage: $0 [local|server]"
    exit 1
fi

# Backup docker-compose.yml saat ini
if [ -f "docker-compose.yml" ]; then
    cp docker-compose.yml docker-compose.yml.backup
    echo "📦 Backed up current docker-compose.yml"
fi

# Copy konfigurasi yang sesuai
if [ "$ENV" = "local" ]; then
    echo "🏠 Setting up LOCAL configuration..."
    cp docker-compose.local.yml docker-compose.yml
    echo "✅ Local configuration activated"
    echo ""
    echo "📋 Local Database Config:"
    echo "   Host: host.docker.internal"
    echo "   User: falaqmsi"
    echo "   Database: kong"
    echo ""
    echo "🚀 To start Kong locally:"
    echo "   docker-compose up -d"
    
elif [ "$ENV" = "server" ]; then
    echo "🖥️  Setting up SERVER configuration..."
    cp docker-compose.server.yml docker-compose.yml
    echo "✅ Server configuration activated"
    echo ""
    echo "📋 Server Database Config:"
    echo "   Host: 162.11.0.232"
    echo "   User: sharedpg"
    echo "   Database: kong"
    echo ""
    echo "🚀 To start Kong on server:"
    echo "   docker-compose up -d"
fi

echo ""
echo "📝 Current configuration:"
echo "   Environment: $ENV"
echo "   Active file: docker-compose.yml"
echo ""
echo "🔄 To switch environment:"
echo "   $0 local    # Switch to local config"
echo "   $0 server   # Switch to server config"
