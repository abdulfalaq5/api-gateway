# Kong API Gateway - Quick Start Guide

## 🚀 Quick Start

### 1. Install Kong
```bash
./scripts/install-kong.sh
```

### 2. Start Kong
```bash
./scripts/start-kong.sh
```

### 3. Test Kong
```bash
# Test Admin API
curl http://localhost:8001/

# Test Kong Proxy
curl http://localhost:9545/
```

## 🌐 Endpoints
- **Kong Proxy**: http://localhost:9545
- **Kong Admin API**: http://localhost:8001
- **Kong Admin GUI**: http://localhost:8002

## 🛠️ Management Commands
```bash
# Start Kong
./scripts/start-kong.sh

# Stop Kong
./scripts/stop-kong.sh

# Check Status
./scripts/status-kong.sh
```

## 📝 Adding Services

### Add a Service
```bash
curl -i -X POST http://localhost:8001/services/ \
  --data "name=my-service" \
  --data "url=http://httpbin.org"
```

### Add a Route
```bash
curl -i -X POST http://localhost:8001/services/my-service/routes \
  --data "paths[]=/my-api"
```

### Test the Route
```bash
curl -i http://localhost:9545/my-api
```

## 🔐 Authentication

### Add API Key Authentication
```bash
# Create Consumer
curl -i -X POST http://localhost:8001/consumers/ \
  --data "username=my-consumer"

# Create API Key
curl -i -X POST http://localhost:8001/consumers/my-consumer/key-auth \
  --data "key=my-secret-key"

# Enable Key Auth Plugin
curl -i -X POST http://localhost:8001/services/my-service/plugins \
  --data "name=key-auth"
```

### Test with API Key
```bash
curl -i http://localhost:9545/my-api \
  -H "apikey: my-secret-key"
```

## 🔧 Configuration Files
- `config/kong.conf` - Main Kong configuration
- `config/kong.yml` - Declarative configuration

## 📚 More Information
Lihat `README.md` untuk dokumentasi lengkap.
