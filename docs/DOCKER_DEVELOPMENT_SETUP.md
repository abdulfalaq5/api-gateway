# Kong API Gateway - Docker Development Setup

## 📋 Overview

Panduan lengkap untuk setup Kong API Gateway menggunakan Docker di environment development. Setup ini menggunakan mode db-less (tanpa database) untuk kemudahan development dan testing.

## 🎯 Fitur Utama

- ✅ Kong 3.4 dengan mode db-less
- ✅ Konfigurasi declarative menggunakan `kong.yml`
- ✅ Port mapping yang aman untuk development
- ✅ Logging verbose untuk debugging
- ✅ Health checks dan monitoring
- ✅ Optional PostgreSQL untuk testing database mode
- ✅ CORS dan Rate Limiting plugins
- ✅ Admin GUI untuk management

## 🚀 Quick Start

### 1. Prerequisites

Pastikan tools berikut sudah terinstall:

```bash
# Docker & Docker Compose
docker --version
docker-compose --version

# curl untuk testing
curl --version

# jq untuk output yang lebih baik (optional)
jq --version
```

### 2. Setup Kong

```bash
# Clone repository (jika belum)
git clone <repository-url>
cd kong-api-gateway

# Jalankan setup script
./scripts/setup-kong-dev.sh
```

### 3. Verifikasi Setup

```bash
# Test Kong health
curl http://localhost:9546/status

# Test Kong proxy
curl http://localhost:9545/

# Test Admin GUI
curl http://localhost:9547/
```

## 📁 Struktur File

```
kong-api-gateway/
├── docker-compose.dev.yml          # Docker Compose untuk development
├── config/
│   └── kong.yml                    # Konfigurasi Kong (declarative)
├── scripts/
│   └── setup-kong-dev.sh          # Script setup development
├── logs/                           # Directory untuk logs
└── docs/
    └── DOCKER_DEVELOPMENT_SETUP.md # Dokumentasi ini
```

## 🔧 Konfigurasi

### Port Mapping

| Port | Service | Deskripsi | Akses |
|------|---------|-----------|-------|
| **9545** | Kong Proxy | Port utama untuk akses API | Public |
| **9546** | Kong Admin API | Management Kong via API | Local |
| **9547** | Kong Admin GUI | Interface web Kong | Local |
| **5432** | PostgreSQL | Database (optional) | Local |

### Environment Variables

```yaml
# Database mode
KONG_DATABASE: "off"                    # Mode db-less
KONG_DECLARATIVE_CONFIG: /kong/kong.yml # File konfigurasi

# Listen addresses
KONG_PROXY_LISTEN: 0.0.0.0:9545
KONG_ADMIN_LISTEN: 0.0.0.0:9546
KONG_ADMIN_GUI_LISTEN: 0.0.0.0:9547

# Logging
KONG_LOG_LEVEL: debug                   # Verbose logging untuk development
KONG_PROXY_ACCESS_LOG: /dev/stdout
KONG_ADMIN_ACCESS_LOG: /dev/stdout

# Timeout settings
KONG_PROXY_CONNECT_TIMEOUT: 60000
KONG_PROXY_SEND_TIMEOUT: 60000
KONG_PROXY_READ_TIMEOUT: 60000
```

## 🛠️ Management Commands

### Start Kong

```bash
# Start Kong dengan konfigurasi development
docker-compose -f docker-compose.dev.yml up -d

# Start dengan PostgreSQL (database mode)
docker-compose -f docker-compose.dev.yml --profile database up -d
```

### Stop Kong

```bash
# Stop Kong
docker-compose -f docker-compose.dev.yml down

# Stop dan hapus volumes
docker-compose -f docker-compose.dev.yml down -v
```

### Restart Kong

```bash
# Restart Kong
docker-compose -f docker-compose.dev.yml restart kong

# Restart dengan rebuild
docker-compose -f docker-compose.dev.yml up -d --force-recreate kong
```

### View Logs

```bash
# View logs real-time
docker-compose -f docker-compose.dev.yml logs -f kong

# View logs dengan timestamp
docker-compose -f docker-compose.dev.yml logs -f -t kong

# View last 100 lines
docker-compose -f docker-compose.dev.yml logs --tail 100 kong
```

## 🧪 Testing

### Basic Connectivity

```bash
# Test Kong health
curl http://localhost:9546/status

# Test Kong proxy
curl http://localhost:9545/

# Test Admin API
curl http://localhost:9546/

# Test Admin GUI
curl http://localhost:9547/
```

### API Endpoints

```bash
# List services
curl http://localhost:9546/services

# List routes
curl http://localhost:9546/routes

# List plugins
curl http://localhost:9546/plugins

# Get Kong configuration
curl http://localhost:9546/config
```

### Test SSO Endpoint

```bash
# Test SSO login
curl -X POST http://localhost:9545/api/auth/sso/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@sso-testing.com",
    "password": "admin123",
    "client_id": "string",
    "redirect_uri": "string"
  }'
```

### Test dengan jq (jika terinstall)

```bash
# Pretty print services
curl -s http://localhost:9546/services | jq '.'

# Count routes
curl -s http://localhost:9546/routes | jq '.data | length'

# List service names
curl -s http://localhost:9546/services | jq -r '.data[] | .name'
```

## 🔍 Monitoring & Debugging

### Container Status

```bash
# List running containers
docker ps | grep kong

# Container resource usage
docker stats kong-gateway-dev

# Container details
docker inspect kong-gateway-dev
```

### Kong Status

```bash
# Kong health check
curl http://localhost:9546/status

# Kong version
curl http://localhost:9546/

# Kong plugins
curl http://localhost:9546/plugins
```

### Network Debugging

```bash
# Test connectivity dari container
docker exec kong-gateway-dev curl http://localhost:9545/

# Test DNS resolution
docker exec kong-gateway-dev nslookup api-gate.motorsights.com

# Check network configuration
docker network ls
docker network inspect kong-api-gateway_default
```

## 🐛 Troubleshooting

### Common Issues

#### 1. Kong Container Tidak Start

```bash
# Cek logs
docker-compose -f docker-compose.dev.yml logs kong

# Cek konfigurasi
docker-compose -f docker-compose.dev.yml config

# Restart dengan verbose
docker-compose -f docker-compose.dev.yml up --force-recreate kong
```

#### 2. Port Already in Use

```bash
# Cek port yang digunakan
netstat -tlnp | grep :9545
netstat -tlnp | grep :9546
netstat -tlnp | grep :9547

# Kill process yang menggunakan port
sudo lsof -ti:9545 | xargs kill -9
sudo lsof -ti:9546 | xargs kill -9
sudo lsof -ti:9547 | xargs kill -9
```

#### 3. Kong Configuration Error

```bash
# Validasi konfigurasi
docker exec kong-gateway-dev kong config -c /kong/kong.yml parse

# Cek syntax kong.yml
yamllint config/kong.yml

# Test konfigurasi
docker exec kong-gateway-dev kong config -c /kong/kong.yml test
```

#### 4. Upstream Connection Issues

```bash
# Test connectivity ke upstream
curl -v https://api-gate.motorsights.com/

# Test dari container
docker exec kong-gateway-dev curl -v https://api-gate.motorsights.com/

# Cek DNS resolution
docker exec kong-gateway-dev nslookup api-gate.motorsights.com
```

### Debug Commands

```bash
# Enter container
docker exec -it kong-gateway-dev /bin/bash

# Cek Kong processes
docker exec kong-gateway-dev ps aux | grep kong

# Cek Kong configuration
docker exec kong-gateway-dev cat /kong/kong.yml

# Cek nginx configuration
docker exec kong-gateway-dev cat /usr/local/kong/nginx.conf
```

## 🔄 Development Workflow

### 1. Modify Configuration

```bash
# Edit kong.yml
vim config/kong.yml

# Restart Kong untuk apply changes
docker-compose -f docker-compose.dev.yml restart kong
```

### 2. Add New Service

```bash
# Edit config/kong.yml untuk menambah service
# Restart Kong
docker-compose -f docker-compose.dev.yml restart kong

# Test new service
curl http://localhost:9545/api/your-new-endpoint
```

### 3. Debug Issues

```bash
# Enable debug logging
# Edit docker-compose.dev.yml: KONG_LOG_LEVEL: debug
# Restart Kong
docker-compose -f docker-compose.dev.yml restart kong

# Monitor logs
docker-compose -f docker-compose.dev.yml logs -f kong
```

## 📊 Performance Tuning

### Resource Limits

```yaml
# Tambahkan di docker-compose.dev.yml
services:
  kong:
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
        reservations:
          memory: 256M
          cpus: '0.25'
```

### Nginx Tuning

```yaml
# Tambahkan environment variables
environment:
  KONG_NGINX_WORKER_PROCESSES: "auto"
  KONG_NGINX_WORKER_CONNECTIONS: "1024"
  KONG_NGINX_KEEPALIVE_REQUESTS: "100"
  KONG_NGINX_KEEPALIVE_TIMEOUT: "60s"
```

## 🔒 Security Considerations

### Development vs Production

- **Development**: Port 9546 dan 9547 terbuka untuk kemudahan debugging
- **Production**: Port admin harus di-restrict ke internal network saja

### Firewall Rules (Production)

```bash
# Allow Kong Proxy (Public)
iptables -A INPUT -p tcp --dport 9545 -j ACCEPT

# Restrict Admin API (Internal only)
iptables -A INPUT -p tcp --dport 9546 -s 192.168.1.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 9546 -s 10.0.0.0/8 -j ACCEPT

# Restrict Admin GUI (Internal only)
iptables -A INPUT -p tcp --dport 9547 -s 192.168.1.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 9547 -s 10.0.0.0/8 -j ACCEPT
```

## 📚 Additional Resources

### Kong Documentation

- [Kong Gateway Documentation](https://docs.konghq.com/gateway/)
- [Kong Configuration Reference](https://docs.konghq.com/gateway/latest/configuration/)
- [Kong Admin API](https://docs.konghq.com/gateway/latest/admin-api/)

### Docker Documentation

- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [Docker Networking](https://docs.docker.com/network/)

### Useful Commands

```bash
# Backup Kong configuration
curl http://localhost:9546/config > kong_backup_$(date +%Y%m%d_%H%M%S).json

# Export Kong configuration
docker exec kong-gateway-dev kong config -c /kong/kong.yml export

# Import Kong configuration
docker exec -i kong-gateway-dev kong config -c /kong/kong.yml import < config.json
```

## 🆘 Support

Jika mengalami masalah:

1. **Cek logs**: `docker-compose -f docker-compose.dev.yml logs -f kong`
2. **Cek status**: `curl http://localhost:9546/status`
3. **Restart Kong**: `docker-compose -f docker-compose.dev.yml restart kong`
4. **Clean restart**: `./scripts/setup-kong-dev.sh --skip-cleanup`

## 📝 Changelog

- **v1.0.0**: Initial setup dengan Kong 3.4 dan mode db-less
- **v1.1.0**: Tambah PostgreSQL optional untuk testing database mode
- **v1.2.0**: Tambah script setup otomatis dan dokumentasi lengkap
