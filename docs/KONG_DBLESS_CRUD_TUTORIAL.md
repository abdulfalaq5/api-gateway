# Kong DB-LESS CRUD Tutorial
# Tutorial lengkap untuk CRUD service dan route di Kong dengan DB-less mode

## 📋 **File yang Terlibat:**

### 1. **config/kong.yml** - File konfigurasi utama
- Berisi semua services, routes, dan plugins
- Format YAML declarative
- Dimount ke container Kong di `/kong/kong.yml`

### 2. **docker-compose.server.yml** - File Docker Compose
- Konfigurasi container Kong
- Environment variables untuk db-less mode
- Volume mounting untuk kong.yml

## 🔧 **Environment Variables Penting:**

```yaml
KONG_DATABASE: "off"                    # Mode db-less
KONG_DECLARATIVE_CONFIG: /kong/kong.yml # File konfigurasi
```

## 📝 **Struktur kong.yml:**

```yaml
_format_version: "3.0"
_transform: true

services:
  - name: service-name
    url: http://backend-service:port
    connect_timeout: 60000
    write_timeout: 60000
    read_timeout: 60000
    routes:
      - name: route-name
        paths:
          - /api/path
        methods:
          - GET
          - POST
        strip_path: true
    plugins:
      - name: plugin-name
        config:
          key: value

plugins:
  - name: global-plugin
    config:
      key: value
```

## 🚀 **CRUD Operations:**

### **CREATE Service & Route:**

#### **Method 1: Edit kong.yml (Recommended untuk Production)**
```bash
# 1. Edit file config/kong.yml
nano config/kong.yml

# 2. Tambahkan service dan route baru
# Contoh:
services:
  - name: user-service
    url: http://user-backend:3000
    connect_timeout: 60000
    write_timeout: 60000
    read_timeout: 60000
    routes:
      - name: user-routes
        paths:
          - /api/users
        methods:
          - GET
          - POST
          - PUT
          - DELETE
        strip_path: true

# 3. Deploy ke server
scp config/kong.yml msiserver@162.11.0.232:/home/msiserver/MSI/api-gateway/config/kong.yml

# 4. Restart Kong di server
sshpass -p "m0t0r519ht5!@#" ssh -o StrictHostKeyChecking=no msiserver@162.11.0.232 "cd /home/msiserver/MSI/api-gateway && docker-compose -f docker-compose.server.yml restart kong"

# 5. Tunggu Kong ready
sleep 15

# 6. Test endpoint
curl -X GET https://services.motorsights.com/api/users
```

#### **Method 2: Admin API (Temporary untuk Testing)**
```bash
# 1. Create service
curl -X POST http://localhost:9546/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "user-service",
    "url": "http://user-backend:3000",
    "connect_timeout": 60000,
    "write_timeout": 60000,
    "read_timeout": 60000
  }'

# 2. Create route
curl -X POST http://localhost:9546/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "user-routes",
    "paths": ["/api/users"],
    "methods": ["GET", "POST", "PUT", "DELETE"],
    "strip_path": true,
    "service": {"name": "user-service"}
  }'

# 3. Test endpoint
curl -X GET https://services.motorsights.com/api/users
```

### **READ (List Services & Routes):**

```bash
# List semua services
curl -s http://localhost:9546/services | jq '.data[] | {name: .name, url: .url}'

# List semua routes
curl -s http://localhost:9546/routes | jq '.data[] | {name: .name, paths: .paths, methods: .methods}'

# Detail service tertentu
curl -s http://localhost:9546/services/user-service | jq '.'

# Detail route tertentu
curl -s http://localhost:9546/routes/user-routes | jq '.'
```

### **UPDATE Service & Route:**

#### **Method 1: Edit kong.yml**
```bash
# 1. Edit file config/kong.yml
nano config/kong.yml

# 2. Update service URL atau route path
# Contoh update URL:
services:
  - name: user-service
    url: http://new-user-backend:3000  # URL baru
    # ... rest of config

# 3. Deploy dan restart
scp config/kong.yml msiserver@162.11.0.232:/home/msiserver/MSI/api-gateway/config/kong.yml
sshpass -p "m0t0r519ht5!@#" ssh -o StrictHostKeyChecking=no msiserver@162.11.0.232 "cd /home/msiserver/MSI/api-gateway && docker-compose -f docker-compose.server.yml restart kong"
```

#### **Method 2: Admin API**
```bash
# Update service URL
curl -X PATCH http://localhost:9546/services/user-service \
  -H "Content-Type: application/json" \
  -d '{
    "url": "http://new-user-backend:3000"
  }'

# Update route path
curl -X PATCH http://localhost:9546/routes/user-routes \
  -H "Content-Type: application/json" \
  -d '{
    "paths": ["/api/new-users"],
    "methods": ["GET", "POST", "PUT", "DELETE", "PATCH"]
  }'
```

### **DELETE Service & Route:**

#### **Method 1: Edit kong.yml**
```bash
# 1. Edit file config/kong.yml
nano config/kong.yml

# 2. Hapus service dan route yang tidak diinginkan
# Contoh: hapus user-service dan user-routes

# 3. Deploy dan restart
scp config/kong.yml msiserver@162.11.0.232:/home/msiserver/MSI/api-gateway/config/kong.yml
sshpass -p "m0t0r519ht5!@#" ssh -o StrictHostKeyChecking=no msiserver@162.11.0.232 "cd /home/msiserver/MSI/api-gateway && docker-compose -f docker-compose.server.yml restart kong"
```

#### **Method 2: Admin API**
```bash
# Delete route dulu (karena ada dependency)
curl -X DELETE http://localhost:9546/routes/user-routes

# Delete service
curl -X DELETE http://localhost:9546/services/user-service
```

## 🛠️ **Script Helper yang Sudah Dibuat:**

### **1. Kong CRUD Helper (Admin API)**
```bash
# List services dan routes
./scripts/kong-crud-helper.sh list-services
./scripts/kong-crud-helper.sh list-routes

# Create service dan route
./scripts/kong-crud-helper.sh create-service user-api http://backend:3000
./scripts/kong-crud-helper.sh create-route user-routes user-api /api/users GET,POST

# Update service dan route
./scripts/kong-crud-helper.sh update-service user-api http://new-backend:3000
./scripts/kong-crud-helper.sh update-route user-routes /api/new-users GET,POST,PUT

# Delete service dan route
./scripts/kong-crud-helper.sh delete-route user-routes
./scripts/kong-crud-helper.sh delete-service user-api
```

### **2. Kong Config Manager (kong.yml)**
```bash
# Show current config
./scripts/kong-config-manager.sh show

# Backup config
./scripts/kong-config-manager.sh backup

# Add service ke kong.yml
./scripts/kong-config-manager.sh add-service user-api http://backend:3000 /api/users GET,POST

# Remove service dari kong.yml
./scripts/kong-config-manager.sh remove-service user-api

# Deploy config ke Kong
./scripts/kong-config-manager.sh deploy
```

## 📋 **Workflow yang Direkomendasikan:**

### **Untuk Development/Testing:**
```bash
# 1. Test dengan Admin API (temporary)
./scripts/kong-crud-helper.sh create-service test-api http://localhost:3000
./scripts/kong-crud-helper.sh create-route test-routes test-api /api/test GET,POST

# 2. Test endpoint
curl -X POST https://services.motorsights.com/api/test -H "Content-Type: application/json" -d '{"test": "data"}'

# 3. Jika OK, tambahkan ke kong.yml
./scripts/kong-config-manager.sh add-service test-api http://localhost:3000 /api/test GET,POST
./scripts/kong-config-manager.sh deploy
```

### **Untuk Production:**
```bash
# 1. Backup config
./scripts/kong-config-manager.sh backup

# 2. Edit kong.yml
nano config/kong.yml

# 3. Deploy config
./scripts/kong-config-manager.sh deploy

# 4. Verify deployment
./scripts/kong-crud-helper.sh list-routes
```

## 🔍 **Monitoring dan Debugging:**

### **Check Kong Status:**
```bash
# Status Kong
curl -s http://localhost:9546/status | jq '.'

# Health check
curl -s http://localhost:9546/health | jq '.'

# Kong logs
docker logs kong-gateway --tail 20
```

### **Test Endpoints:**
```bash
# Test service langsung
curl -X GET http://localhost:9545/api/users

# Test melalui Nginx
curl -X GET https://services.motorsights.com/api/users

# Test dengan headers
curl -X POST https://services.motorsights.com/api/users \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer token" \
  -d '{"name": "John", "email": "john@example.com"}'
```

## ⚠️ **Important Notes:**

1. **Admin API changes are temporary** - Hilang saat restart Kong
2. **kong.yml changes are persistent** - Tersimpan dan dimuat saat restart
3. **Always backup** sebelum melakukan perubahan besar
4. **Test di development** sebelum deploy ke production
5. **Restart Kong** setelah mengubah kong.yml
6. **Check logs** jika ada masalah

## 🎯 **Quick Reference:**

| Operation | File | Command |
|-----------|------|---------|
| **Create** | kong.yml | `nano config/kong.yml` → `./scripts/kong-config-manager.sh deploy` |
| **Read** | - | `./scripts/kong-crud-helper.sh list-services` |
| **Update** | kong.yml | `nano config/kong.yml` → `./scripts/kong-config-manager.sh deploy` |
| **Delete** | kong.yml | `nano config/kong.yml` → `./scripts/kong-config-manager.sh deploy` |
| **Backup** | - | `./scripts/kong-config-manager.sh backup` |
| **Test** | - | `curl -X GET https://services.motorsights.com/api/path` |

**File utama yang perlu diedit: `config/kong.yml`**
**Command utama yang perlu dijalankan: `./scripts/kong-config-manager.sh deploy`**
