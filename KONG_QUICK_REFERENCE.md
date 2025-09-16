# Kong Quick Reference - Most Used Commands

## 🚀 **Quick Commands untuk Daily Operations**

### **1. Service Management**

#### **Lihat Semua Services**
```bash
curl http://localhost:9546/services/ | jq '.data[] | {name: .name, host: .host, port: .port, protocol: .protocol}'
```

#### **Lihat Service Spesifik**
```bash
curl http://localhost:9546/services/sso-service | jq '{name: .name, host: .host, port: .port, protocol: .protocol, url: .url}'
```

#### **Buat Service Baru**
```bash
curl -X POST http://localhost:9546/services/ \
  -d "name=my-service" \
  -d "url=https://api.example.com" \
  -d "connect_timeout=60000" \
  -d "write_timeout=60000" \
  -d "read_timeout=60000"
```

#### **Update Service**
```bash
curl -X PATCH http://localhost:9546/services/sso-service \
  -d "url=https://new-api.example.com" \
  -d "connect_timeout=60000" \
  -d "write_timeout=60000" \
  -d "read_timeout=60000"
```

#### **Hapus Service**
```bash
curl -X DELETE http://localhost:9546/services/sso-service
```

### **2. Route Management**

#### **Lihat Semua Routes**
```bash
curl http://localhost:9546/routes/ | jq '.data[] | {name: .name, paths: .paths, methods: .methods, service: .service.name}'
```

#### **Lihat Routes untuk Service**
```bash
curl http://localhost:9546/services/sso-service/routes | jq '.data[] | {name: .name, paths: .paths, methods: .methods}'
```

#### **Buat Route Baru**
```bash
curl -X POST http://localhost:9546/services/sso-service/routes \
  -d "name=my-route" \
  -d "paths[]=/api/v1/endpoint" \
  -d "methods[]=GET" \
  -d "methods[]=POST" \
  -d "strip_path=false"
```

#### **Update Route**
```bash
curl -X PATCH http://localhost:9546/routes/my-route \
  -d "paths[]=/api/v1/new-endpoint" \
  -d "methods[]=GET" \
  -d "methods[]=POST" \
  -d "methods[]=PUT"
```

#### **Hapus Route**
```bash
curl -X DELETE http://localhost:9546/routes/my-route
```

### **3. Plugin Management**

#### **Lihat Semua Plugins**
```bash
curl http://localhost:9546/plugins/ | jq '.data[] | {name: .name, service: .service.name, enabled: .enabled}'
```

#### **Buat Plugin Rate Limiting**
```bash
curl -X POST http://localhost:9546/services/sso-service/plugins \
  -d "name=rate-limiting" \
  -d "config.minute=100" \
  -d "config.hour=1000" \
  -d "config.policy=local"
```

#### **Buat Plugin CORS**
```bash
curl -X POST http://localhost:9546/services/sso-service/plugins \
  -d "name=cors" \
  -d "config.origins=*" \
  -d "config.methods=GET,POST,PUT,DELETE,OPTIONS" \
  -d "config.headers=Accept,Content-Type,Authorization"
```

#### **Hapus Plugin**
```bash
curl -X DELETE http://localhost:9546/plugins/PLUGIN_ID
```

### **4. Status & Monitoring**

#### **Kong Status**
```bash
curl http://localhost:9546/status | jq
```

#### **Service Health**
```bash
curl http://localhost:9546/services/sso-service/health | jq
```

#### **Kong Logs**
```bash
docker-compose logs -f kong
```

### **5. Common Operations**

#### **Deploy Service Lengkap**
```bash
# 1. Buat service
curl -X POST http://localhost:9546/services/ \
  -d "name=new-service" \
  -d "url=https://api.example.com" \
  -d "connect_timeout=60000" \
  -d "write_timeout=60000" \
  -d "read_timeout=60000"

# 2. Buat route
curl -X POST http://localhost:9546/services/new-service/routes \
  -d "name=new-service-routes" \
  -d "paths[]=/api/v1/new" \
  -d "methods[]=GET" \
  -d "methods[]=POST" \
  -d "strip_path=false"

# 3. Tambahkan plugins
curl -X POST http://localhost:9546/services/new-service/plugins \
  -d "name=rate-limiting" \
  -d "config.minute=100" \
  -d "config.hour=1000"

curl -X POST http://localhost:9546/services/new-service/plugins \
  -d "name=cors" \
  -d "config.origins=*" \
  -d "config.methods=GET,POST,OPTIONS"

# 4. Test endpoint
curl -v http://localhost:9545/api/v1/new
```

#### **Update Service Existing**
```bash
# Update service
curl -X PATCH http://localhost:9546/services/sso-service \
  -d "url=https://new-sso-api.example.com" \
  -d "connect_timeout=60000" \
  -d "write_timeout=60000" \
  -d "read_timeout=60000"

# Restart Kong
docker-compose restart kong
sleep 15

# Test endpoint
curl -v http://localhost:9545/api/auth/sso/login
```

#### **Cleanup Operations**
```bash
# Hapus services yang salah
curl -X DELETE http://localhost:9546/services/wrong-service-1
curl -X DELETE http://localhost:9546/services/wrong-service-2

# Hapus routes yang salah
curl -X DELETE http://localhost:9546/routes/wrong-route-1
curl -X DELETE http://localhost:9546/routes/wrong-route-2

# Restart Kong
docker-compose restart kong
sleep 15
```

#### **Backup & Restore**
```bash
# Backup
curl http://localhost:9546/config > kong_backup_$(date +%Y%m%d_%H%M%S).json

# Restore
curl -X POST http://localhost:9546/config -F "config=@kong_backup_YYYYMMDD_HHMMSS.json"
```

### **6. Testing Commands**

#### **Test Service Langsung**
```bash
curl -v http://localhost:9545/api/endpoint
```

#### **Test dengan Headers**
```bash
curl -v http://localhost:9545/api/endpoint \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer token"
```

#### **Test dengan Data**
```bash
curl -v http://localhost:9545/api/endpoint \
  -H "Content-Type: application/json" \
  -d '{"key": "value"}'
```

#### **Test SSO Endpoint**
```bash
curl -v http://localhost:9545/api/auth/sso/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@sso-testing.com","password":"admin123","client_id":"string","redirect_uri":"string"}'
```

### **7. Troubleshooting Commands**

#### **Cek Services Bermasalah**
```bash
curl http://localhost:9546/services/ | jq '.data[] | select(.host == "host.docker.internal" or .host == "172.17.0.1") | {name: .name, host: .host, port: .port}'
```

#### **Cek Routes Bermasalah**
```bash
curl http://localhost:9546/routes/ | jq '.data[] | select(.name | contains("old") or contains("wrong")) | {name: .name, service: .service.name}'
```

#### **Cek Kong Logs Error**
```bash
docker-compose logs kong | grep -i error
```

#### **Cek Port Binding**
```bash
netstat -tlnp | grep 9545
```

#### **Restart Kong**
```bash
docker-compose restart kong
sleep 15
```

### **8. Quick Fix Commands**

#### **Fix SSO Service**
```bash
# Hapus routes dan services yang salah
curl -X DELETE http://localhost:9546/routes/sso-login-api-gate-final
curl -X DELETE http://localhost:9546/routes/sso-login-api-gate-transform
curl -X DELETE http://localhost:9546/routes/sso-login-api-gate-direct
curl -X DELETE http://localhost:9546/routes/sso-login-services-direct
curl -X DELETE http://localhost:9546/services/sso-service-api-gate

# Update service SSO
curl -X PATCH http://localhost:9546/services/sso-service \
  -d "url=https://api-gate.motorsights.com" \
  -d "connect_timeout=60000" \
  -d "write_timeout=60000" \
  -d "read_timeout=60000"

# Restart Kong
docker-compose restart kong
sleep 15

# Test
curl -v https://services.motorsights.com/api/auth/sso/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@sso-testing.com","password":"admin123","client_id":"string","redirect_uri":"string"}'
```

---

## 📝 **Tips**

1. **Selalu backup** sebelum perubahan besar
2. **Test endpoint** setelah setiap perubahan
3. **Monitor logs** setelah restart
4. **Gunakan jq** untuk parsing JSON response
5. **Restart Kong** setelah perubahan besar untuk membersihkan cache

---

**Catatan**: Ganti `localhost:9546` dengan IP server jika menjalankan dari remote machine.
