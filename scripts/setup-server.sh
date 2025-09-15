#!/bin/bash

# Script untuk setup Kong API Gateway di Server Internal
# Script ini akan membantu konfigurasi port dan firewall

set -e

echo "🖥️  Kong API Gateway - Server Internal Setup"
echo "=============================================="

# Cek apakah script dijalankan sebagai root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Script ini harus dijalankan sebagai root atau dengan sudo"
    echo "   Contoh: sudo ./scripts/setup-server.sh"
    exit 1
fi

echo ""
echo "📋 Port yang akan dikonfigurasi:"
echo "   - Port 9545: Kong Proxy (Public Access)"
echo "   - Port 9546: Kong Admin API (Internal Only)"
echo "   - Port 9547: Kong Admin GUI (Internal Only)"
echo "   - Port 5432: PostgreSQL Database (Internal Only)"
echo ""

# Function untuk setup firewall
setup_firewall() {
    echo "🔥 Setting up firewall rules..."
    
    # Cek apakah ufw tersedia
    if command -v ufw &> /dev/null; then
        echo "   Menggunakan UFW..."
        
        # Allow Kong Proxy (Public)
        ufw allow 9545/tcp comment "Kong Proxy - Public Access"
        
        # Allow Kong Admin API (Internal only - sesuaikan dengan network internal)
        ufw allow from 192.168.1.0/24 to any port 9546 comment "Kong Admin API - Internal"
        ufw allow from 10.0.0.0/8 to any port 9546 comment "Kong Admin API - Internal"
        
        # Allow Kong Admin GUI (Internal only)
        ufw allow from 192.168.1.0/24 to any port 9547 comment "Kong Admin GUI - Internal"
        ufw allow from 10.0.0.0/8 to any port 9547 comment "Kong Admin GUI - Internal"
        
        # Allow PostgreSQL (Internal only)
        ufw allow from 192.168.1.0/24 to any port 5432 comment "PostgreSQL - Internal"
        ufw allow from 10.0.0.0/8 to any port 5432 comment "PostgreSQL - Internal"
        
        echo "✅ UFW rules berhasil ditambahkan"
        
    elif command -v iptables &> /dev/null; then
        echo "   Menggunakan iptables..."
        
        # Allow Kong Proxy (Public)
        iptables -A INPUT -p tcp --dport 9545 -j ACCEPT
        
        # Allow Kong Admin API (Internal only)
        iptables -A INPUT -p tcp --dport 9546 -s 192.168.1.0/24 -j ACCEPT
        iptables -A INPUT -p tcp --dport 9546 -s 10.0.0.0/8 -j ACCEPT
        
        # Allow Kong Admin GUI (Internal only)
        iptables -A INPUT -p tcp --dport 9547 -s 192.168.1.0/24 -j ACCEPT
        iptables -A INPUT -p tcp --dport 9547 -s 10.0.0.0/8 -j ACCEPT
        
        # Allow PostgreSQL (Internal only)
        iptables -A INPUT -p tcp --dport 5432 -s 192.168.1.0/24 -j ACCEPT
        iptables -A INPUT -p tcp --dport 5432 -s 10.0.0.0/8 -j ACCEPT
        
        echo "✅ iptables rules berhasil ditambahkan"
        
    else
        echo "❌ Tidak ditemukan firewall tool (ufw atau iptables)"
        echo "   Silakan setup firewall secara manual"
    fi
}

# Function untuk cek port availability
check_ports() {
    echo ""
    echo "🔍 Checking port availability..."
    
    ports=(9545 9546 9547 5432)
    
    for port in "${ports[@]}"; do
        if netstat -tlnp | grep -q ":$port "; then
            echo "   ⚠️  Port $port sudah digunakan"
        else
            echo "   ✅ Port $port tersedia"
        fi
    done
}

# Function untuk generate konfigurasi network
generate_network_config() {
    echo ""
    echo "🌐 Network Configuration:"
    echo ""
    
    # Get server IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo "📋 Endpoints yang akan tersedia:"
    echo "   - Kong Proxy: http://$SERVER_IP:9545"
    echo "   - Kong Admin API: http://$SERVER_IP:9546 (Internal Only)"
    echo "   - Kong Admin GUI: http://$SERVER_IP:9547 (Internal Only)"
    echo ""
    
    echo "📋 Untuk akses dari client external:"
    echo "   curl http://$SERVER_IP:9545/"
    echo ""
    
    echo "📋 Untuk management dari internal:"
    echo "   curl http://$SERVER_IP:9546/"
    echo "   curl http://$SERVER_IP:9547/"
}

# Function untuk setup monitoring
setup_monitoring() {
    echo ""
    echo "📊 Setting up basic monitoring..."
    
    # Create monitoring script
    cat > /usr/local/bin/kong-monitor.sh << 'EOF'
#!/bin/bash
# Kong monitoring script

echo "Kong API Gateway Status Check"
echo "=============================="

# Check Kong Proxy
if curl -s http://localhost:9545/ > /dev/null; then
    echo "✅ Kong Proxy (9545): OK"
else
    echo "❌ Kong Proxy (9545): DOWN"
fi

# Check Kong Admin API
if curl -s http://localhost:9546/ > /dev/null; then
    echo "✅ Kong Admin API (9546): OK"
else
    echo "❌ Kong Admin API (9546): DOWN"
fi

# Check Kong Admin GUI
if curl -s http://localhost:9547/ > /dev/null; then
    echo "✅ Kong Admin GUI (9547): OK"
else
    echo "❌ Kong Admin GUI (9547): DOWN"
fi

# Check PostgreSQL
if pg_isready -h localhost -p 5432 > /dev/null 2>&1; then
    echo "✅ PostgreSQL (5432): OK"
else
    echo "❌ PostgreSQL (5432): DOWN"
fi
EOF
    
    chmod +x /usr/local/bin/kong-monitor.sh
    
    echo "✅ Monitoring script dibuat di /usr/local/bin/kong-monitor.sh"
    echo "   Jalankan: kong-monitor.sh"
}

# Main execution
echo "🚀 Starting server setup..."

# Check ports
check_ports

# Setup firewall
echo ""
read -p "Apakah Anda ingin setup firewall rules? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    setup_firewall
fi

# Generate network config
generate_network_config

# Setup monitoring
echo ""
read -p "Apakah Anda ingin setup monitoring? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    setup_monitoring
fi

echo ""
echo "✅ Server setup selesai!"
echo ""
echo "📋 Langkah selanjutnya:"
echo "   1. Jalankan Kong: ./scripts/start-kong-docker.sh"
echo "   2. Test connectivity: ./scripts/test-kong-docker.sh"
echo "   3. Monitor status: kong-monitor.sh"
echo ""
echo "🔒 Keamanan:"
echo "   - Port 9545: Public access (untuk client)"
echo "   - Port 9546, 9547, 5432: Internal access only"
echo ""
echo "📚 Dokumentasi lengkap: SERVER_SETUP.md"
