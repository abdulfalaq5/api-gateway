#!/bin/bash

# Script untuk mengubah Kong ke DB-less mode menggunakan kong.yml
# File: scripts/switch-to-dbless.sh

set -e

echo "🔄 Switching Kong to DB-less Mode"
echo "================================="

# Backup konfigurasi saat ini
echo "📦 Creating backup..."
BACKUP_FILE="backups/kong_db_backup_$(date +%Y%m%d_%H%M%S).json"
curl -s http://localhost:9546/config > "$BACKUP_FILE"
echo "   Backup tersimpan di: $BACKUP_FILE"

# Export konfigurasi ke kong.yml
echo "📋 Exporting current configuration to kong.yml..."
curl -s http://localhost:9546/config > backups/kong_current_config.json

# Convert JSON to YAML format
echo "   Converting JSON to YAML..."
cat > config/kong.yml << 'EOF'
_format_version: "3.0"
_transform: true

services:
EOF

# Convert services to YAML
jq -r '.services[] | @base64' backups/kong_current_config.json | while read service_b64; do
    service=$(echo "$service_b64" | base64 -d)
    name=$(echo "$service" | jq -r '.name')
    url=$(echo "$service" | jq -r '.url // empty')
    host=$(echo "$service" | jq -r '.host // empty')
    port=$(echo "$service" | jq -r '.port // empty')
    protocol=$(echo "$service" | jq -r '.protocol // empty')
    connect_timeout=$(echo "$service" | jq -r '.connect_timeout // empty')
    write_timeout=$(echo "$service" | jq -r '.write_timeout // empty')
    read_timeout=$(echo "$service" | jq -r '.read_timeout // empty')
    
        echo "  - name: $name" >> config/kong.yml
    if [ ! -z "$url" ] && [ "$url" != "null" ]; then
        echo "    url: $url" >> config/kong.yml
    else
        echo "    host: $host" >> config/kong.yml
        echo "    port: $port" >> config/kong.yml
        echo "    protocol: $protocol" >> config/kong.yml
    fi
    
    if [ ! -z "$connect_timeout" ] && [ "$connect_timeout" != "null" ]; then
        echo "    connect_timeout: $connect_timeout" >> config/kong.yml
    fi
    if [ ! -z "$write_timeout" ] && [ "$write_timeout" != "null" ]; then
        echo "    write_timeout: $write_timeout" >> config/kong.yml
    fi
    if [ ! -z "$read_timeout" ] && [ "$read_timeout" != "null" ]; then
        echo "    read_timeout: $read_timeout" >> config/kong.yml
    fi
    
    # Add routes
    echo "    routes:" >> config/kong.yml
    jq -r --arg service_id "$(echo "$service" | jq -r '.id')" '.routes[] | select(.service.id == $service_id) | @base64' backups/kong_current_config.json | while read route_b64; do
        route=$(echo "$route_b64" | base64 -d)
        route_name=$(echo "$route" | jq -r '.name')
        paths=$(echo "$route" | jq -r '.paths[]? // empty')
        methods=$(echo "$route" | jq -r '.methods[]? // empty')
        strip_path=$(echo "$route" | jq -r '.strip_path // false')
        
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
    
    # Add plugins
    echo "    plugins:" >> config/kong.yml
    jq -r --arg service_id "$(echo "$service" | jq -r '.id')" '.plugins[] | select(.service.id == $service_id) | @base64' backups/kong_current_config.json | while read plugin_b64; do
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
jq -r '.plugins[] | select(.service == null) | @base64' backups/kong_current_config.json | while read plugin_b64; do
    plugin=$(echo "$plugin_b64" | base64 -d)
    plugin_name=$(echo "$plugin" | jq -r '.name')
    config=$(echo "$plugin" | jq -r '.config // empty')
    
    echo "  - name: $plugin_name" >> config/kong.yml
    if [ ! -z "$config" ] && [ "$config" != "null" ]; then
        echo "    config:" >> config/kong.yml
        echo "$config" | jq -r 'to_entries[] | "      \(.key): \(.value)"' >> config/kong.yml
    fi
done

echo "   ✅ config/kong.yml created"

# Update docker-compose.yml untuk DB-less mode
echo "📋 Updating docker-compose.yml for DB-less mode..."
cp docker-compose.yml docker-compose.yml.backup

# Create new docker-compose.yml for DB-less
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  kong:
    image: kong:3.4
    container_name: kong-gateway
    environment:
      KONG_DATABASE: "off"
      KONG_DECLARATIVE_CONFIG: /kong/kong.yml
      KONG_PROXY_LISTEN: 0.0.0.0:9545
      KONG_ADMIN_LISTEN: 0.0.0.0:9546
      KONG_ADMIN_GUI_LISTEN: 0.0.0.0:9547
      KONG_PROXY_ACCESS_LOG: /dev/stdout
      KONG_ADMIN_ACCESS_LOG: /dev/stdout
      KONG_PROXY_ERROR_LOG: /dev/stderr
      KONG_ADMIN_ERROR_LOG: /dev/stderr
      KONG_ADMIN_GUI_ERROR_LOG: /dev/stderr
    volumes:
      - ./config/kong.yml:/kong/kong.yml:ro
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
EOF

echo "   ✅ docker-compose.yml updated for DB-less mode"

# Stop Kong
echo "🛑 Stopping Kong..."
docker-compose down

# Start Kong in DB-less mode
echo "🚀 Starting Kong in DB-less mode..."
docker-compose up -d

# Wait for Kong to start
echo "⏳ Waiting for Kong to start..."
sleep 15

# Verify Kong is running
echo "🔍 Verifying Kong..."
if curl -s --connect-timeout 5 http://localhost:9546/ > /dev/null 2>&1; then
    echo "   ✅ Kong is running in DB-less mode"
else
    echo "   ❌ Kong failed to start"
    echo "   Rolling back to database mode..."
    cp docker-compose.yml.backup docker-compose.yml
    docker-compose up -d
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
echo "✅ Kong switched to DB-less mode!"
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
echo "🔄 To rollback to database mode:"
echo "   cp docker-compose.yml.backup docker-compose.yml"
echo "   docker-compose up -d"
echo ""
echo "📊 Monitor logs:"
echo "   docker-compose logs -f kong"
