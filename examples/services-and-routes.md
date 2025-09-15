# Contoh Konfigurasi Kong API Gateway

## 📋 Services dan Routes

### 1. Service untuk API User Management
```bash
# Tambahkan service
curl -i -X POST http://localhost:8001/services/ \
  --data "name=user-service" \
  --data "url=http://localhost:3001"

# Tambahkan route
curl -i -X POST http://localhost:8001/services/user-service/routes \
  --data "paths[]=/api/v1/users" \
  --data "strip_path=true"

# Test service
curl -i http://localhost:8000/api/v1/users
```

### 2. Service untuk API Product Management
```bash
# Tambahkan service
curl -i -X POST http://localhost:8001/services/ \
  --data "name=product-service" \
  --data "url=http://localhost:3002"

# Tambahkan route
curl -i -X POST http://localhost:8001/services/product-service/routes \
  --data "paths[]=/api/v1/products" \
  --data "strip_path=true"

# Test service
curl -i http://localhost:8000/api/v1/products
```

### 3. Service untuk API Order Management
```bash
# Tambahkan service
curl -i -X POST http://localhost:8001/services/ \
  --data "name=order-service" \
  --data "url=http://localhost:3003"

# Tambahkan route
curl -i -X POST http://localhost:8001/services/order-service/routes \
  --data "paths[]=/api/v1/orders" \
  --data "strip_path=true"

# Test service
curl -i http://localhost:8000/api/v1/orders
```

## 🔐 Authentication Examples

### 1. API Key Authentication
```bash
# Buat consumer
curl -i -X POST http://localhost:8001/consumers/ \
  --data "username=api-client" \
  --data "custom_id=client-001"

# Buat API key
curl -i -X POST http://localhost:8001/consumers/api-client/key-auth \
  --data "key=sk-1234567890abcdef"

# Enable key auth untuk service
curl -i -X POST http://localhost:8001/services/user-service/plugins \
  --data "name=key-auth"

# Test dengan API key
curl -i http://localhost:8000/api/v1/users \
  -H "apikey: sk-1234567890abcdef"
```

### 2. JWT Authentication
```bash
# Buat consumer
curl -i -X POST http://localhost:8001/consumers/ \
  --data "username=jwt-client"

# Buat JWT credential
curl -i -X POST http://localhost:8001/consumers/jwt-client/jwt \
  --data "key=jwt-key-123" \
  --data "secret=jwt-secret-456"

# Enable JWT plugin
curl -i -X POST http://localhost:8001/services/product-service/plugins \
  --data "name=jwt"

# Test dengan JWT token
curl -i http://localhost:8000/api/v1/products \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## 🛡️ Rate Limiting Examples

### 1. Rate Limiting per Consumer
```bash
# Enable rate limiting
curl -i -X POST http://localhost:8001/services/user-service/plugins \
  --data "name=rate-limiting" \
  --data "config.minute=100" \
  --data "config.hour=1000" \
  --data "config.policy=local"
```

### 2. Rate Limiting per IP
```bash
# Enable rate limiting per IP
curl -i -X POST http://localhost:8001/services/product-service/plugins \
  --data "name=rate-limiting" \
  --data "config.minute=50" \
  --data "config.hour=500" \
  --data "config.policy=local" \
  --data "config.limit_by=ip"
```

## 🌐 CORS Configuration

### Enable CORS untuk semua services
```bash
# Enable CORS
curl -i -X POST http://localhost:8001/services/user-service/plugins \
  --data "name=cors" \
  --data "config.origins=*" \
  --data "config.methods=GET,POST,PUT,DELETE,OPTIONS" \
  --data "config.headers=Accept,Accept-Version,Content-Length,Content-MD5,Content-Type,Date,X-Auth-Token" \
  --data "config.exposed_headers=X-Auth-Token" \
  --data "config.credentials=true" \
  --data "config.max_age=3600"
```

## 🔄 Request/Response Transformation

### 1. Request Transformation
```bash
# Add request transformer
curl -i -X POST http://localhost:8001/services/order-service/plugins \
  --data "name=request-transformer" \
  --data "config.add.headers=X-API-Version:1.0" \
  --data "config.add.querystring=source:kong"
```

### 2. Response Transformation
```bash
# Add response transformer
curl -i -X POST http://localhost:8001/services/product-service/plugins \
  --data "name=response-transformer" \
  --data "config.add.headers=X-Response-Time:$(date)" \
  --data "config.remove.headers=Server"
```

## 📊 Monitoring dan Logging

### 1. Enable Request Logging
```bash
# Add file log plugin
curl -i -X POST http://localhost:8001/services/user-service/plugins \
  --data "name=file-log" \
  --data "config.path=/Users/falaqmsi/Documents/GitHub/kong-api-gateway/logs/requests.log"
```

### 2. Enable Prometheus Metrics
```bash
# Add prometheus plugin
curl -i -X POST http://localhost:8001/services/product-service/plugins \
  --data "name=prometheus"
```

## 🧪 Testing Examples

### Test semua endpoints
```bash
#!/bin/bash

echo "Testing Kong API Gateway..."

# Test user service
echo "Testing user service..."
curl -i http://localhost:8000/api/v1/users \
  -H "apikey: sk-1234567890abcdef"

# Test product service
echo "Testing product service..."
curl -i http://localhost:8000/api/v1/products \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# Test order service
echo "Testing order service..."
curl -i http://localhost:8000/api/v1/orders \
  -H "apikey: sk-1234567890abcdef"

echo "Testing completed!"
```

## 📝 Declarative Configuration

### File kong.yml untuk multiple services
```yaml
_format_version: "3.0"
_transform: true

services:
  - name: user-service
    url: http://localhost:3001
    routes:
      - name: user-routes
        paths:
          - /api/v1/users
        methods:
          - GET
          - POST
          - PUT
          - DELETE
        strip_path: true
    plugins:
      - name: key-auth
      - name: cors
        config:
          origins: ["*"]
          methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
          headers: ["Accept", "Content-Type", "Authorization"]
          credentials: true

  - name: product-service
    url: http://localhost:3002
    routes:
      - name: product-routes
        paths:
          - /api/v1/products
        methods:
          - GET
          - POST
          - PUT
          - DELETE
        strip_path: true
    plugins:
      - name: jwt
      - name: rate-limiting
        config:
          minute: 100
          hour: 1000
          policy: local

consumers:
  - username: api-client
    custom_id: client-001
    keyauth_credentials:
      - key: sk-1234567890abcdef
  - username: jwt-client
    jwt_secrets:
      - key: jwt-key-123
        secret: jwt-secret-456
```

## 🚀 Deploy Configuration

### Deploy declarative configuration
```bash
# Deploy configuration
kong config db_import /Users/falaqmsi/Documents/GitHub/kong-api-gateway/config/kong.yml

# Verify configuration
curl http://localhost:8001/services/
```
