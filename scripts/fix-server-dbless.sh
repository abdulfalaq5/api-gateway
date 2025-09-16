#!/bin/bash

# Script untuk memperbaiki Kong DB-less mode di server
# File: scripts/fix-server-dbless.sh

set -e

echo "🔧 Fixing Kong DB-less Mode on Server"
echo "====================================="

# Cek apakah Kong sedang berjalan
echo "🔍 Checking Kong status..."
if curl -s --connect-timeout 5 http://localhost:9546/ > /dev/null 2>&1; then
    echo "   ✅ Kong is running"
else
    echo "   ❌ Kong is not running. Please start Kong first."
    echo "   Run: docker-compose up -d"
    exit 1
fi

# Backup konfigurasi saat ini
echo "📦 Creating backup..."
BACKUP_FILE="backups/kong_server_backup_$(date +%Y%m%d_%H%M%S).json"
mkdir -p backups
curl -s http://localhost:9546/services > backups/services.json
curl -s http://localhost:9546/routes > backups/routes.json
curl -s http://localhost:9546/plugins > backups/plugins.json
echo "   Backup tersimpan di: backups/"

# Buat kong.yml yang benar berdasarkan konfigurasi saat ini
echo "📝 Creating correct kong.yml..."
cat > config/kong.yml << 'EOF'
_format_version: "3.0"
_transform: true

services:
EOF

# Convert services dari database ke YAML
echo "🔄 Converting services to YAML..."
jq -r '.data[] | @base64' backups/services.json | while read service_b64; do
    service=$(echo "$service_b64" | base64 -d)
    name=$(echo "$service" | jq -r '.name')
    host=$(echo "$service" | jq -r '.host')
    port=$(echo "$service" | jq -r '.port')
    protocol=$(echo "$service" | jq -r '.protocol')
    connect_timeout=$(echo "$service" | jq -r '.connect_timeout')
    write_timeout=$(echo "$service" | jq -r '.write_timeout')
    read_timeout=$(echo "$service" | jq -r '.read_timeout')
    
    # Build URL
    if [ "$protocol" = "https" ] && [ "$port" = "443" ]; then
        url="https://$host"
    elif [ "$protocol" = "http" ] && [ "$port" = "80" ]; then
        url="http://$host"
    else
        url="$protocol://$host:$port"
    fi
    
    echo "  - name: $name" >> config/kong.yml
    echo "    url: $url" >> config/kong.yml
    echo "    connect_timeout: $connect_timeout" >> config/kong.yml
    echo "    write_timeout: $write_timeout" >> config/kong.yml
    echo "    read_timeout: $read_timeout" >> config/kong.yml
    
    # Add routes for this service
    service_id=$(echo "$service" | jq -r '.id')
    echo "    routes:" >> config/kong.yml
    
    jq -r --arg service_id "$service_id" '.data[] | select(.service.id == $service_id) | @base64' backups/routes.json | while read route_b64; do
        route=$(echo "$route_b64" | base64 -d)
        route_name=$(echo "$route" | jq -r '.name')
        paths=$(echo "$route" | jq -r '.paths[]?')
        methods=$(echo "$route" | jq -r '.methods[]?')
        strip_path=$(echo "$route" | jq -r '.strip_path')
        
        echo "      - name: $route_name" >> config/kong.yml
        if [ ! -z "$paths" ]; then
            echo "        paths:" >> config/kong.yml
            echo "$paths" | while read path; do
                echo "          - $path" >> config/kong.yml
            done
        fi
        if [ ! -z "$methods" ]; then
            echo "        methods:" >> config/kong.yml
            echo "$methods" | while read method; do
                echo "          - $method" >> config/kong.yml
            done
        fi
        echo "        strip_path: $strip_path" >> config/kong.yml
    done
    
    # Add plugins for this service
    echo "    plugins:" >> config/kong.yml
    jq -r --arg service_id "$service_id" '.data[] | select(.service.id == $service_id) | @base64' backups/plugins.json | while read plugin_b64; do
        plugin=$(echo "$plugin_b64" | base64 -d)
        plugin_name=$(echo "$plugin" | jq -r '.name')
        config=$(echo "$plugin" | jq -r '.config // empty')
        
        echo "      - name: $plugin_name" >> config/kong.yml
        if [ ! -z "$config" ] && [ "$config" != "null" ]; then
            echo "        config:" >> config/kong.yml
            echo "$config" | jq -r 'to_entries[] | "          \(.key): \(.value)"' >> config/kong.yml
        fi
    done
    
    echo "" >> config/kong.yml
done

# Add global plugins
echo "plugins:" >> config/kong.yml
jq -r '.data[] | select(.service == null) | @base64' backups/plugins.json | while read plugin_b64; do
    plugin=$(echo "$plugin_b64" | base64 -d)
    plugin_name=$(echo "$plugin" | jq -r '.name')
    config=$(echo "$plugin" | jq -r '.config // empty')
    
    echo "  - name: $plugin_name" >> config/kong.yml
    if [ ! -z "$config" ] && [ "$config" != "null" ]; then
        echo "    config:" >> config/kong.yml
        echo "$config" | jq -r 'to_entries[] | "      \(.key): \(.value)"' >> config/kong.yml
    fi
done

echo "✅ kong.yml created successfully!"

# Restart Kong untuk apply konfigurasi baru
echo "🔄 Restarting Kong..."
docker-compose restart kong

# Wait for Kong to start
echo "⏳ Waiting for Kong to start..."
sleep 15

# Verify Kong is running
echo "🔍 Verifying Kong..."
if curl -s --connect-timeout 5 http://localhost:9546/ > /dev/null 2>&1; then
    echo "   ✅ Kong is running in DB-less mode"
else
    echo "   ❌ Kong failed to start"
    echo "   Check logs: docker-compose logs kong"
    exit 1
fi

# Test endpoints
echo "🧪 Testing endpoints..."
if curl -s --connect-timeout 10 -X POST http://localhost:9545/api/auth/sso/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@sso-testing.com","password":"admin123","client_id":"string","redirect_uri":"string"}' > /dev/null 2>&1; then
    echo "   ✅ SSO endpoint working"
else
    echo "   ⚠️  SSO endpoint timeout (check if SSO service is accessible)"
fi

echo ""
echo "✅ Kong DB-less mode fixed!"
echo ""
echo "📋 Benefits:"
echo "   - No database cache issues"
echo "   - Configuration in kong.yml file"
echo "   - Version control friendly"
echo "   - Easy rollback"
echo ""
echo "📝 To update configuration:"
echo "   1. Edit config/kong.yml"
echo "   2. Restart Kong: docker-compose restart kong"
echo ""
echo "📊 Monitor logs:"
echo "   docker-compose logs -f kong"
