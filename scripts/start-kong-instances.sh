#!/bin/bash

# Script untuk start/stop kedua Kong instance secara bersamaan
# Menggunakan project name berbeda untuk menghindari konflik

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Project names untuk menghindari konflik
PROJECT_NAME_1="kong-instance1"
PROJECT_NAME_2="kong-instance2"

case "$1" in
    "start"|"up")
        print_status "🚀 Starting both Kong instances..."
        echo ""
        
        # Cleanup existing containers if any (to avoid conflicts)
        print_status "Cleaning up existing containers..."
        docker rm -f kong-gateway kong-gateway2 2>/dev/null || true
        echo ""
        
        # Start Instance 1
        print_status "Starting Instance 1 (kong-gateway)..."
        docker-compose -p $PROJECT_NAME_1 -f docker-compose.server.yml up -d
        
        # Start Instance 2
        print_status "Starting Instance 2 (kong-gateway2)..."
        docker-compose -p $PROJECT_NAME_2 -f docker-compose.server2.yml up -d
        
        echo ""
        print_success "✅ Both instances started!"
        echo ""
        
        # Show status
        print_status "Container Status:"
        docker ps | grep kong-gateway
        ;;
        
    "stop"|"down")
        print_status "🛑 Stopping both Kong instances..."
        echo ""
        
        # Stop Instance 1
        print_status "Stopping Instance 1..."
        docker-compose -p $PROJECT_NAME_1 -f docker-compose.server.yml down
        
        # Stop Instance 2
        print_status "Stopping Instance 2..."
        docker-compose -p $PROJECT_NAME_2 -f docker-compose.server2.yml down
        
        echo ""
        print_success "✅ Both instances stopped!"
        ;;
        
    "restart")
        print_status "🔄 Restarting both Kong instances..."
        $0 stop
        sleep 2
        $0 start
        ;;
        
    "status"|"ps")
        print_status "📊 Kong Instances Status:"
        echo ""
        
        echo "Instance 1 (kong-gateway):"
        docker-compose -p $PROJECT_NAME_1 -f docker-compose.server.yml ps
        echo ""
        
        echo "Instance 2 (kong-gateway2):"
        docker-compose -p $PROJECT_NAME_2 -f docker-compose.server2.yml ps
        echo ""
        
        echo "All Kong containers:"
        docker ps | grep kong-gateway
        ;;
        
    "logs")
        if [ -z "$2" ]; then
            print_error "Please specify instance number (1 or 2)"
            echo "Usage: $0 logs <1|2>"
            exit 1
        fi
        
        if [ "$2" = "1" ]; then
            print_status "📋 Instance 1 logs:"
            docker logs kong-gateway --tail 50 -f
        elif [ "$2" = "2" ]; then
            print_status "📋 Instance 2 logs:"
            docker logs kong-gateway2 --tail 50 -f
        else
            print_error "Invalid instance number. Use 1 or 2"
            exit 1
        fi
        ;;
        
    "test")
        print_status "🧪 Testing both instances..."
        echo ""
        
        echo "Testing Instance 1 (port 9546):"
        curl -s http://localhost:9546/status | jq '.' || echo "❌ Instance 1 not responding"
        echo ""
        
        echo "Testing Instance 2 (port 9589):"
        curl -s http://localhost:9589/status | jq '.' || echo "❌ Instance 2 not responding"
        ;;
        
    "help"|"")
        echo "🚀 Kong Instances Manager"
        echo "========================="
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  start     - Start both Kong instances"
        echo "  stop      - Stop both Kong instances"
        echo "  restart   - Restart both Kong instances"
        echo "  status    - Show status of both instances"
        echo "  logs <1|2> - Show logs for instance 1 or 2"
        echo "  test      - Test both instances"
        echo "  help      - Show this help"
        echo ""
        echo "Examples:"
        echo "  $0 start"
        echo "  $0 status"
        echo "  $0 logs 1"
        echo "  $0 test"
        ;;
        
    *)
        print_error "Unknown command: $1"
        echo ""
        $0 help
        exit 1
        ;;
esac
