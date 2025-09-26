#!/bin/bash

# Script untuk export Kong configuration ke format declarative
# File: scripts/export-kong-config.sh

set -e

echo "📦 Exporting Kong Configuration to Declarative Format"
echo "====================================================="

# Backup directory
BACKUP_DIR="kong_export_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "📁 Creating backup directory: $BACKUP_DIR"

# Export services
echo "📋 Exporting services..."
curl -s http://localhost:9546/services/ > "$BACKUP_DIR/services.json"
echo "   ✅ Services exported"

# Export routes
echo "📋 Exporting routes..."
curl -s http://localhost:9546/routes/ > "$BACKUP_DIR/routes.json"
echo "   ✅ Routes exported"

# Export plugins
echo "📋 Exporting plugins..."
curl -s http://localhost:9546/plugins/ > "$BACKUP_DIR/plugins.json"
echo "   ✅ Plugins exported"

# Export full config
echo "📋 Exporting full configuration..."
curl -s http://localhost:9546/config > "$BACKUP_DIR/full_config.json"
echo "   ✅ Full configuration exported"

# Generate declarative YAML
echo "📋 Generating declarative YAML..."
cat > "$BACKUP_DIR/kong.yml" << 'EOF'
_format_version: "3.0"
_transform: true

services:
EOF

# Convert services to YAML format
echo "   Converting services to YAML..."
jq -r '.data[] | select(.name != null) | @base64' "$BACKUP_DIR/services.json" | while read service_b64; do
    service=$(echo "$service_b64" | base64 -d)
    name=$(echo "$service" | jq -r '.name')
    url=$(echo "$service" | jq -r '.url // empty')
    host=$(echo "$service" | jq -r '.host // empty')
    port=$(echo "$service" | jq -r '.port // empty')
    protocol=$(echo "$service" | jq -r '.protocol // empty')
    connect_timeout=$(echo "$service" | jq -r '.connect_timeout // empty')
    write_timeout=$(echo "$service" | jq -r '.write_timeout // empty')
    read_timeout=$(echo "$service" | jq -r '.read_timeout // empty')
    
    echo "  - name: $name" >> "$BACKUP_DIR/kong.yml"
    if [ ! -z "$url" ] && [ "$url" != "null" ]; then
        echo "    url: $url" >> "$BACKUP_DIR/kong.yml"
    else
        echo "    host: $host" >> "$BACKUP_DIR/kong.yml"
        echo "    port: $port" >> "$BACKUP_DIR/kong.yml"
        echo "    protocol: $protocol" >> "$BACKUP_DIR/kong.yml"
    fi
    
    if [ ! -z "$connect_timeout" ] && [ "$connect_timeout" != "null" ]; then
        echo "    connect_timeout: $connect_timeout" >> "$BACKUP_DIR/kong.yml"
    fi
    if [ ! -z "$write_timeout" ] && [ "$write_timeout" != "null" ]; then
        echo "    write_timeout: $write_timeout" >> "$BACKUP_DIR/kong.yml"
    fi
    if [ ! -z "$read_timeout" ] && [ "$read_timeout" != "null" ]; then
        echo "    read_timeout: $read_timeout" >> "$BACKUP_DIR/kong.yml"
    fi
    
    # Add routes for this service
    echo "    routes:" >> "$BACKUP_DIR/kong.yml"
    jq -r --arg service_id "$(echo "$service" | jq -r '.id')" '.data[] | select(.service.id == $service_id) | @base64' "$BACKUP_DIR/routes.json" | while read route_b64; do
        route=$(echo "$route_b64" | base64 -d)
        route_name=$(echo "$route" | jq -r '.name')
        paths=$(echo "$route" | jq -r '.paths[]? // empty')
        methods=$(echo "$route" | jq -r '.methods[]? // empty')
        strip_path=$(echo "$route" | jq -r '.strip_path // false')
        
        echo "      - name: $route_name" >> "$BACKUP_DIR/kong.yml"
        if [ ! -z "$paths" ]; then
            echo "        paths:" >> "$BACKUP_DIR/kong.yml"
            echo "$paths" | while read path; do
                echo "          - $path" >> "$BACKUP_DIR/kong.yml"
            done
        fi
        if [ ! -z "$methods" ]; then
            echo "        methods:" >> "$BACKUP_DIR/kong.yml"
            echo "$methods" | while read method; do
                echo "          - $method" >> "$BACKUP_DIR/kong.yml"
            done
        fi
        echo "        strip_path: $strip_path" >> "$BACKUP_DIR/kong.yml"
    done
    
    # Add plugins for this service
    echo "    plugins:" >> "$BACKUP_DIR/kong.yml"
    jq -r --arg service_id "$(echo "$service" | jq -r '.id')" '.data[] | select(.service.id == $service_id) | @base64' "$BACKUP_DIR/plugins.json" | while read plugin_b64; do
        plugin=$(echo "$plugin_b64" | base64 -d)
        plugin_name=$(echo "$plugin" | jq -r '.name')
        config=$(echo "$plugin" | jq -r '.config // empty')
        
        echo "      - name: $plugin_name" >> "$BACKUP_DIR/kong.yml"
        if [ ! -z "$config" ] && [ "$config" != "null" ]; then
            echo "        config:" >> "$BACKUP_DIR/kong.yml"
            echo "$config" | jq -r 'to_entries[] | "          \(.key): \(.value)"' >> "$BACKUP_DIR/kong.yml"
        fi
    done
    
    echo "" >> "$BACKUP_DIR/kong.yml"
done

# Add global plugins
echo "plugins:" >> "$BACKUP_DIR/kong.yml"
jq -r '.data[] | select(.service == null) | @base64' "$BACKUP_DIR/plugins.json" | while read plugin_b64; do
    plugin=$(echo "$plugin_b64" | base64 -d)
    plugin_name=$(echo "$plugin" | jq -r '.name')
    config=$(echo "$plugin" | jq -r '.config // empty')
    
    echo "  - name: $plugin_name" >> "$BACKUP_DIR/kong.yml"
    if [ ! -z "$config" ] && [ "$config" != "null" ]; then
        echo "    config:" >> "$BACKUP_DIR/kong.yml"
        echo "$config" | jq -r 'to_entries[] | "      \(.key): \(.value)"' >> "$BACKUP_DIR/kong.yml"
    fi
done

echo "   ✅ Declarative YAML generated"

# Create deployment script
echo "📋 Creating deployment script..."
cat > "$BACKUP_DIR/deploy-to-new-server.sh" << 'EOF'
#!/bin/bash

# Script untuk deploy Kong configuration ke server baru
# File: deploy-to-new-server.sh

set -e

echo "🚀 Deploying Kong Configuration to New Server"
echo "=============================================="

# Cek apakah Kong berjalan
if ! curl -s --connect-timeout 5 http://localhost:9546/ > /dev/null 2>&1; then
    echo "❌ Kong tidak berjalan. Silakan start Kong terlebih dahulu:"
    echo "   docker-compose up -d"
    exit 1
fi

echo "✅ Kong sedang berjalan"

# Backup konfigurasi saat ini
echo "📦 Creating backup..."
BACKUP_FILE="kong_backup_$(date +%Y%m%d_%H%M%S).json"
curl -s http://localhost:9546/config > "$BACKUP_FILE"
echo "   Backup tersimpan di: $BACKUP_FILE"

# Deploy konfigurasi baru
echo "🔄 Deploying new configuration..."
if [ -f "kong.yml" ]; then
    DEPLOY_RESPONSE=$(curl -s -w "%{http_code}" -X POST http://localhost:9546/config -F "config=@kong.yml")
    HTTP_CODE="${DEPLOY_RESPONSE: -3}"
    
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
        echo "   ✅ Deploy berhasil (HTTP $HTTP_CODE)"
    else
        echo "   ❌ Deploy gagal (HTTP $HTTP_CODE)"
        echo "   Response: ${DEPLOY_RESPONSE%???}"
        exit 1
    fi
else
    echo "   ❌ File kong.yml tidak ditemukan!"
    exit 1
fi

# Verifikasi deploy
echo "🔍 Verifying deployment..."
SERVICES_COUNT=$(curl -s http://localhost:9546/services/ | jq 'length' 2>/dev/null || echo "0")
ROUTES_COUNT=$(curl -s http://localhost:9546/routes/ | jq 'length' 2>/dev/null || echo "0")
PLUGINS_COUNT=$(curl -s http://localhost:9546/plugins/ | jq 'length' 2>/dev/null || echo "0")

echo "   Services deployed: $SERVICES_COUNT"
echo "   Routes deployed: $ROUTES_COUNT"
echo "   Plugins deployed: $PLUGINS_COUNT"

# Test endpoints
echo "🧪 Testing endpoints..."
if curl -s http://localhost:9545/ > /dev/null 2>&1; then
    echo "   ✅ Kong Proxy accessible"
else
    echo "   ❌ Kong Proxy tidak dapat diakses"
fi

echo ""
echo "✅ Deployment completed!"
echo ""
echo "📋 Next steps:"
echo "   - Test endpoints: curl http://localhost:9545/api/your-endpoint"
echo "   - Monitor logs: docker-compose logs -f kong"
echo "   - Cek services: curl http://localhost:9546/services/"
echo ""
echo "🔄 Jika ada masalah, rollback dengan:"
echo "   curl -X POST http://localhost:9546/config -F \"config=@$BACKUP_FILE\""
EOF

chmod +x "$BACKUP_DIR/deploy-to-new-server.sh"

echo "   ✅ Deployment script created"

# Create README
cat > "$BACKUP_DIR/README.md" << EOF
# Kong Configuration Export

Export dibuat pada: $(date)

## Files:
- \`kong.yml\` - Declarative configuration untuk Kong
- \`services.json\` - Services backup
- \`routes.json\` - Routes backup  
- \`plugins.json\` - Plugins backup
- \`full_config.json\` - Full Kong configuration
- \`deploy-to-new-server.sh\` - Script untuk deploy ke server baru

## Cara Deploy ke Server Baru:

1. Copy semua files ke server baru
2. Jalankan script deploy:
   \`\`\`bash
   ./deploy-to-new-server.sh
   \`\`\`

3. Atau deploy manual:
   \`\`\`bash
   curl -X POST http://localhost:9546/config -F "config=@kong.yml"
   \`\`\`

## Verifikasi:
\`\`\`bash
# Cek services
curl http://localhost:9546/services/ | jq

# Cek routes  
curl http://localhost:9546/routes/ | jq

# Test endpoint
curl http://localhost:9545/api/your-endpoint
\`\`\`
EOF

echo ""
echo "✅ Export completed!"
echo ""
echo "📁 Files exported to: $BACKUP_DIR"
echo "   - kong.yml (declarative configuration)"
echo "   - services.json, routes.json, plugins.json (backups)"
echo "   - deploy-to-new-server.sh (deployment script)"
echo "   - README.md (instructions)"
echo ""
echo "🚀 To deploy to new server:"
echo "   1. Copy $BACKUP_DIR to new server"
echo "   2. Run: ./$BACKUP_DIR/deploy-to-new-server.sh"
echo ""
echo "📋 Or deploy manually:"
echo "   curl -X POST http://localhost:9546/config -F \"config=@$BACKUP_DIR/kong.yml\""
