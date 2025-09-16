#!/bin/bash

# Script untuk memperbaiki konversi Kong configuration ke kong.yml
# File: scripts/fix-kong-yml-conversion.sh

set -e

echo "🔧 Fixing Kong YAML Conversion"
echo "=============================="

# Backup file kong.yml yang ada
if [ -f "config/kong.yml" ]; then
    echo "📦 Backing up existing kong.yml..."
    cp config/kong.yml config/kong.yml.backup.$(date +%Y%m%d_%H%M%S)
fi

# Export konfigurasi saat ini
echo "📋 Exporting current Kong configuration..."
curl -s http://localhost:9546/services > backups/services.json
curl -s http://localhost:9546/routes > backups/routes.json
curl -s http://localhost:9546/plugins > backups/plugins.json

# Buat kong.yml yang benar
echo "📝 Creating correct kong.yml..."
cat > config/kong.yml << 'EOF'
_format_version: "3.0"
_transform: true

services:
EOF

# Convert services
echo "🔄 Converting services..."
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

echo "✅ kong.yml conversion fixed!"
echo ""
echo "📋 Next steps:"
echo "   1. Review config/kong.yml"
echo "   2. Restart Kong: docker-compose restart kong"
echo "   3. Test endpoints"
echo ""
echo "📊 Monitor logs:"
echo "   docker-compose logs -f kong"
