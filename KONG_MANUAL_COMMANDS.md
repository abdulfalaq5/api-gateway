# Kong API Gateway - Manual Commands Documentation

## 🎯 **Overview**
Dokumentasi lengkap untuk mengelola Kong services, routes, dan plugins menggunakan manual curl commands. Berguna untuk maintenance, troubleshooting, dan deployment.

## 📋 **Table of Contents**
1. [Service Management](#service-management)
2. [Route Management](#route-management)
3. [Plugin Management](#plugin-management)
4. [Status & Monitoring](#status--monitoring)
5. [Troubleshooting](#troubleshooting)
6. [Common Operations](#common-operations)

---

## 🔧 **Service Management**

### **1. Melihat Semua Services**
```bash
# List semua services
curl http://localhost:9546/services/ | jq

# List services dengan format yang lebih readable
curl http://localhost:9546/services/ | jq '.data[] | {name: .name, host: .host, port: .port, protocol: .protocol, url: .url}'

# Count jumlah services
curl http://localhost:9546/services/ | jq '.data | length'
```

### **2. Melihat Service Spesifik**
```bash
# Lihat service berdasarkan nama
curl http://localhost:9546/services/sso-service | jq

# Lihat service berdasarkan ID
curl http://localhost:9546/services/03a9704b-5a35-5f27-a7a4-95d5988ead8e | jq

# Lihat hanya informasi penting
curl http://localhost:9546/services/sso-service | jq '{name: .name, host: .host, port: .port, protocol: .protocol, url: .url, connect_timeout: .connect_timeout}'
```

### **3. Membuat Service Baru**
```bash
# Membuat service dengan URL lengkap
curl -X POST http://localhost:9546/services/ \
  -d "name=my-new-service" \
  -d "url=https://api.example.com" \
  -d "connect_timeout=60000" \
  -d "write_timeout=60000" \
  -d "read_timeout=60000"

# Membuat service dengan host dan port terpisah
curl -X POST http://localhost:9546/services/ \
  -d "name=my-service" \
  -d "host=api.example.com" \
  -d "port=443" \
  -d "protocol=https" \
  -d "path=/api/v1" \
  -d "connect_timeout=60000" \
  -d "write_timeout=60000" \
  -d "read_timeout=60000"

# Membuat service dengan retries
curl -X POST http://localhost:9546/services/ \
  -d "name=retry-service" \
  -d "url=https://api.example.com" \
  -d "retries=5" \
  -d "connect_timeout=60000"
```

### **4. Update Service**
```bash
# Update URL service
curl -X PATCH http://localhost:9546/services/sso-service \
  -d "url=https://new-api.example.com"

# Update timeout settings
curl -X PATCH http://localhost:9546/services/sso-service \
  -d "connect_timeout=30000" \
  -d "write_timeout=30000" \
  -d "read_timeout=30000"

# Update host dan port
curl -X PATCH http://localhost:9546/services/sso-service \
  -d "host=new-host.example.com" \
  -d "port=8080" \
  -d "protocol=http"

# Update multiple settings sekaligus
curl -X PATCH http://localhost:9546/services/sso-service \
  -d "url=https://api-gate.motorsights.com" \
  -d "connect_timeout=60000" \
  -d "write_timeout=60000" \
  -d "read_timeout=60000" \
  -d "retries=3"
```

### **5. Hapus Service**
```bash
# Hapus service berdasarkan nama
curl -X DELETE http://localhost:9546/services/sso-service

# Hapus service berdasarkan ID
curl -X DELETE http://localhost:9546/services/03a9704b-5a35-5f27-a7a4-95d5988ead8e

# Hapus multiple services
curl -X DELETE http://localhost:9546/services/wrong-service-1
curl -X DELETE http://localhost:9546/services/wrong-service-2
curl -X DELETE http://localhost:9546/services/old-service
```

---

## 🛣️ **Route Management**

### **1. Melihat Semua Routes**
```bash
# List semua routes
curl http://localhost:9546/routes/ | jq

# List routes dengan format yang lebih readable
curl http://localhost:9546/routes/ | jq '.data[] | {name: .name, paths: .paths, methods: .methods, service: .service.name}'

# List routes untuk service tertentu
curl http://localhost:9546/services/sso-service/routes | jq

# Count jumlah routes
curl http://localhost:9546/routes/ | jq '.data | length'
```

### **2. Melihat Route Spesifik**
```bash
# Lihat route berdasarkan nama
curl http://localhost:9546/routes/sso-login-routes | jq

# Lihat route berdasarkan ID
curl http://localhost:9546/routes/bb07e3e8-9864-401a-a5c2-a6647328fc1c | jq

# Lihat hanya informasi penting
curl http://localhost:9546/routes/sso-login-routes | jq '{name: .name, paths: .paths, methods: .methods, strip_path: .strip_path, service: .service.name}'
```

### **3. Membuat Route Baru**
```bash
# Membuat route untuk service tertentu
curl -X POST http://localhost:9546/services/sso-service/routes \
  -d "name=my-new-route" \
  -d "paths[]=/api/v1/my-endpoint" \
  -d "methods[]=GET" \
  -d "methods[]=POST" \
  -d "strip_path=false"

# Membuat route dengan multiple paths
curl -X POST http://localhost:9546/services/sso-service/routes \
  -d "name=multi-path-route" \
  -d "paths[]=/api/v1/users" \
  -d "paths[]=/api/v1/profiles" \
  -d "methods[]=GET" \
  -d "methods[]=POST" \
  -d "methods[]=PUT" \
  -d "strip_path=true"

# Membuat route dengan hosts
curl -X POST http://localhost:9546/services/sso-service/routes \
  -d "name=host-specific-route" \
  -d "hosts[]=api.example.com" \
  -d "paths[]=/api/v1/data" \
  -d "methods[]=GET"

# Membuat route dengan headers
curl -X POST http://localhost:9546/services/sso-service/routes \
  -d "name=header-route" \
  -d "paths[]=/api/v1/admin" \
  -d "methods[]=GET" \
  -d "headers[Authorization]=Bearer.*"
```

### **4. Update Route**
```bash
# Update paths route
curl -X PATCH http://localhost:9546/routes/sso-login-routes \
  -d "paths[]=/api/auth/sso/login" \
  -d "paths[]=/api/v2/auth/sso/login"

# Update methods route
curl -X PATCH http://localhost:9546/routes/sso-login-routes \
  -d "methods[]=POST" \
  -d "methods[]=OPTIONS" \
  -d "methods[]=GET"

# Update strip_path
curl -X PATCH http://localhost:9546/routes/sso-login-routes \
  -d "strip_path=true"

# Update multiple settings
curl -X PATCH http://localhost:9546/routes/sso-login-routes \
  -d "paths[]=/api/auth/sso/login" \
  -d "methods[]=POST" \
  -d "methods[]=OPTIONS" \
  -d "strip_path=false"
```

### **5. Hapus Route**
```bash
# Hapus route berdasarkan nama
curl -X DELETE http://localhost:9546/routes/sso-login-routes

# Hapus route berdasarkan ID
curl -X DELETE http://localhost:9546/routes/bb07e3e8-9864-401a-a5c2-a6647328fc1c

# Hapus multiple routes
curl -X DELETE http://localhost:9546/routes/old-route-1
curl -X DELETE http://localhost:9546/routes/old-route-2
curl -X DELETE http://localhost:9546/routes/wrong-route

# Hapus semua routes untuk service tertentu
curl http://localhost:9546/services/sso-service/routes | jq -r '.data[].id' | xargs -I {} curl -X DELETE http://localhost:9546/routes/{}
```

---

## 🔌 **Plugin Management**

### **1. Melihat Semua Plugins**
```bash
# List semua plugins
curl http://localhost:9546/plugins/ | jq

# List plugins dengan format yang lebih readable
curl http://localhost:9546/plugins/ | jq '.data[] | {name: .name, service: .service.name, route: .route.name, enabled: .enabled}'

# List plugins untuk service tertentu
curl http://localhost:9546/services/sso-service/plugins | jq

# List plugins untuk route tertentu
curl http://localhost:9546/routes/sso-login-routes/plugins | jq
```

### **2. Membuat Plugin Baru**
```bash
# Rate limiting untuk service
curl -X POST http://localhost:9546/services/sso-service/plugins \
  -d "name=rate-limiting" \
  -d "config.minute=100" \
  -d "config.hour=1000" \
  -d "config.policy=local"

# CORS untuk service
curl -X POST http://localhost:9546/services/sso-service/plugins \
  -d "name=cors" \
  -d "config.origins=*" \
  -d "config.methods=GET,POST,PUT,DELETE,OPTIONS" \
  -d "config.headers=Accept,Content-Type,Authorization"

# Request transformer
curl -X POST http://localhost:9546/services/sso-service/plugins \
  -d "name=request-transformer" \
  -d "config.add.headers=X-Forwarded-By:Kong" \
  -d "config.add.querystring=version=v1"

# Response transformer
curl -X POST http://localhost:9546/services/sso-service/plugins \
  -d "name=response-transformer" \
  -d "config.add.headers=X-Response-Time:$(date)" \
  -d "config.remove.headers=Server"
```

### **3. Update Plugin**
```bash
# Update rate limiting config
curl -X PATCH http://localhost:9546/plugins/PLUGIN_ID \
  -d "config.minute=200" \
  -d "config.hour=2000"

# Enable/disable plugin
curl -X PATCH http://localhost:9546/plugins/PLUGIN_ID \
  -d "enabled=false"
```

### **4. Hapus Plugin**
```bash
# Hapus plugin berdasarkan ID
curl -X DELETE http://localhost:9546/plugins/PLUGIN_ID

# Hapus semua plugins untuk service
curl http://localhost:9546/services/sso-service/plugins | jq -r '.data[].id' | xargs -I {} curl -X DELETE http://localhost:9546/plugins/{}
```

---

## 📊 **Status & Monitoring**

### **1. Kong Status**
```bash
# Kong health check
curl http://localhost:9546/status | jq

# Kong configuration
curl http://localhost:9546/ | jq

# Kong version
curl http://localhost:9546/ | jq '.version'
```

### **2. Service Status**
```bash
# Cek service health
curl http://localhost:9546/services/sso-service/health | jq

# Cek semua services health
curl http://localhost:9546/services/ | jq '.data[] | {name: .name, url: .url, enabled: .enabled}'
```

### **3. Route Status**
```bash
# Cek route status
curl http://localhost:9546/routes/ | jq '.data[] | {name: .name, paths: .paths, service: .service.name}'

# Cek routes untuk service tertentu
curl http://localhost:9546/services/sso-service/routes | jq '.data[] | {name: .name, paths: .paths, methods: .methods}'
```

### **4. Plugin Status**
```bash
# Cek plugin status
curl http://localhost:9546/plugins/ | jq '.data[] | {name: .name, enabled: .enabled, service: .service.name}'

# Cek plugins untuk service tertentu
curl http://localhost:9546/services/sso-service/plugins | jq '.data[] | {name: .name, enabled: .enabled, config: .config}'
```

---

## 🔍 **Troubleshooting**

### **1. Cek Konfigurasi Lengkap**
```bash
# Export semua konfigurasi
curl http://localhost:9546/config > kong_config_backup.json

# Cek services yang bermasalah
curl http://localhost:9546/services/ | jq '.data[] | select(.host == "host.docker.internal" or .host == "172.17.0.1") | {name: .name, host: .host, port: .port}'

# Cek routes yang bermasalah
curl http://localhost:9546/routes/ | jq '.data[] | select(.name | contains("old") or contains("wrong")) | {name: .name, service: .service.name}'
```

### **2. Cleanup Operations**
```bash
# Hapus semua services yang tidak digunakan
curl http://localhost:9546/services/ | jq -r '.data[] | select(.name | contains("test") or contains("old")) | .id' | xargs -I {} curl -X DELETE http://localhost:9546/services/{}

# Hapus semua routes yang tidak digunakan
curl http://localhost:9546/routes/ | jq -r '.data[] | select(.name | contains("test") or contains("old")) | .id' | xargs -I {} curl -X DELETE http://localhost:9546/routes/{}

# Hapus semua plugins yang tidak digunakan
curl http://localhost:9546/plugins/ | jq -r '.data[] | select(.name | contains("test")) | .id' | xargs -I {} curl -X DELETE http://localhost:9546/plugins/{}
```

### **3. Restart Operations**
```bash
# Restart Kong
docker-compose restart kong

# Tunggu Kong startup
sleep 15

# Verifikasi Kong berjalan
curl http://localhost:9546/status | jq '.database.reachable'
```

---

## 🚀 **Common Operations**

### **1. Deploy Service Baru Lengkap**
```bash
# 1. Buat service
curl -X POST http://localhost:9546/services/ \
  -d "name=new-api-service" \
  -d "url=https://new-api.example.com" \
  -d "connect_timeout=60000" \
  -d "write_timeout=60000" \
  -d "read_timeout=60000"

# 2. Buat routes
curl -X POST http://localhost:9546/services/new-api-service/routes \
  -d "name=new-api-routes" \
  -d "paths[]=/api/v1/new" \
  -d "methods[]=GET" \
  -d "methods[]=POST" \
  -d "strip_path=false"

# 3. Tambahkan plugins
curl -X POST http://localhost:9546/services/new-api-service/plugins \
  -d "name=rate-limiting" \
  -d "config.minute=100" \
  -d "config.hour=1000"

curl -X POST http://localhost:9546/services/new-api-service/plugins \
  -d "name=cors" \
  -d "config.origins=*" \
  -d "config.methods=GET,POST,OPTIONS"

# 4. Test endpoint
curl -v http://localhost:9545/api/v1/new
```

### **2. Update Service Existing**
```bash
# Update service URL
curl -X PATCH http://localhost:9546/services/sso-service \
  -d "url=https://new-sso-api.example.com"

# Update timeout
curl -X PATCH http://localhost:9546/services/sso-service \
  -d "connect_timeout=30000" \
  -d "write_timeout=30000" \
  -d "read_timeout=30000"

# Restart Kong
docker-compose restart kong
sleep 15

# Test endpoint
curl -v http://localhost:9545/api/auth/sso/login
```

### **3. Backup & Restore**
```bash
# Backup konfigurasi
curl http://localhost:9546/config > kong_backup_$(date +%Y%m%d_%H%M%S).json

# Backup services
curl http://localhost:9546/services/ > services_backup_$(date +%Y%m%d_%H%M%S).json

# Backup routes
curl http://localhost:9546/routes/ > routes_backup_$(date +%Y%m%d_%H%M%S).json

# Restore (jika menggunakan declarative config)
curl -X POST http://localhost:9546/config -F "config=@kong_backup_YYYYMMDD_HHMMSS.json"
```

### **4. Monitoring Commands**
```bash
# Monitor Kong logs
docker-compose logs -f kong

# Monitor Kong metrics
curl http://localhost:9546/status | jq '.server.connections_active'

# Monitor service health
curl http://localhost:9546/services/sso-service/health | jq

# Monitor route traffic
curl http://localhost:9546/routes/sso-login-routes | jq '{name: .name, paths: .paths, service: .service.name}'
```

---

## 📝 **Tips & Best Practices**

### **1. Naming Convention**
- Services: `{service-name}-service` (e.g., `sso-service`, `user-service`)
- Routes: `{service-name}-{endpoint}-routes` (e.g., `sso-login-routes`, `user-profile-routes`)
- Plugins: Use descriptive names based on functionality

### **2. Timeout Settings**
- `connect_timeout`: 60000ms (60 detik)
- `write_timeout`: 60000ms (60 detik)
- `read_timeout`: 60000ms (60 detik)

### **3. Error Handling**
- Selalu backup sebelum perubahan besar
- Test endpoint setelah perubahan
- Monitor logs setelah restart
- Gunakan `jq` untuk parsing JSON response

### **4. Testing Commands**
```bash
# Test service langsung
curl -v http://localhost:9545/api/endpoint

# Test dengan headers
curl -v http://localhost:9545/api/endpoint \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer token"

# Test dengan data
curl -v http://localhost:9545/api/endpoint \
  -H "Content-Type: application/json" \
  -d '{"key": "value"}'
```

---

**Catatan**: Selalu backup konfigurasi sebelum melakukan perubahan besar dan test endpoint setelah setiap perubahan!
