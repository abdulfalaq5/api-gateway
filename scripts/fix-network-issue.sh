#!/bin/bash

# Fix Docker Network Issue for Kong
echo "🔧 Fixing Docker Network Issue..."

# Stop everything
echo "🛑 Stopping all containers..."
docker-compose -f docker-compose.server.yml down 2>/dev/null || true
docker-compose -f docker-compose.yml down 2>/dev/null || true

# Remove containers
echo "🗑️  Removing containers..."
docker rm -f kong-gateway kong-migrations 2>/dev/null || true

# Clean networks
echo "🧹 Cleaning networks..."
docker network prune -f

# Remove specific problematic networks
echo "🗑️  Removing problematic networks..."
docker network ls -q | xargs -r docker network rm 2>/dev/null || true

# Create fresh network
echo "🆕 Creating fresh network..."
docker network create kong-network 2>/dev/null || true

# Start only Kong (skip migrations for now)
echo "🚀 Starting Kong only..."
docker-compose -f docker-compose.server.yml up -d kong

# Wait
echo "⏳ Waiting for Kong..."
sleep 15

# Check status
echo "📋 Checking Kong status..."
if docker ps | grep -q kong-gateway; then
    echo "✅ Kong is running"
    
    # Check if Kong is healthy
    if curl -s http://localhost:9546/status > /dev/null 2>&1; then
        echo "✅ Kong is healthy"
        
        # Check routes
        echo "📋 Checking routes..."
        routes=$(curl -s http://localhost:9546/routes 2>/dev/null)
        route_count=$(echo "$routes" | jq '.data | length' 2>/dev/null || echo "0")
        
        if [[ "$route_count" -gt 0 ]]; then
            echo "✅ Found $route_count routes"
        else
            echo "⚠️  No routes found (normal for fresh start)"
        fi
        
        echo ""
        echo "🎉 Kong is ready!"
        echo "📍 Test with: curl http://localhost:9545/"
        
    else
        echo "❌ Kong is not healthy"
        echo "📋 Kong logs:"
        docker logs kong-gateway --tail 10
    fi
else
    echo "❌ Kong failed to start"
    echo "📋 Docker logs:"
    docker-compose -f docker-compose.server.yml logs kong
fi
