# Kong Migration Guide - Setup di Server Baru

## 🎯 **Overview**
Panduan lengkap untuk memindahkan Kong API Gateway ke server baru tanpa perlu insert ulang semua service, routes, dan plugins secara manual.

## 🚀 **Solusi yang Tersedia**

### **1. Export/Import Konfigurasi (Recommended)**
### **2. Declarative Configuration**
### **3. Setup Otomatis dengan Script**

---

## 📦 **Method 1: Export/Import Konfigurasi**

### **Step 1: Export dari Server Lama**
```bash
# Export semua konfigurasi Kong
curl http://localhost:9546/config > kong_full_config.json

# Atau export per komponen
curl http://localhost:9546/services/ > services_backup.json
curl http://localhost:9546/routes/ > routes_backup.json
curl http://localhost:9546/plugins/ > plugins_backup.json
```

### **Step 2: Copy ke Server Baru**
```bash
# Copy file ke server baru
scp kong_full_config.json user@new-server:/path/to/kong-api-gateway/
```

### **Step 3: Import ke Server Baru**
```bash
# Import konfigurasi lengkap
curl -X POST http://localhost:9546/config -F "config=@kong_full_config.json"
```

---

## 🔧 **Method 2: Menggunakan Script Export**

### **Export Konfigurasi dengan Script**
```bash
# Jalankan script export
./scripts/export-kong-config.sh
```

Script ini akan membuat:
- `kong.yml` - Declarative configuration
- `services.json`, `routes.json`, `plugins.json` - Backups
- `deploy-to-new-server.sh` - Script deploy otomatis
- `README.md` - Instructions

### **Deploy ke Server Baru**
```bash
# Copy folder export ke server baru
scp -r kong_export_YYYYMMDD_HHMMSS/ user@new-server:/path/to/kong-api-gateway/

# Di server baru, jalankan script deploy
./kong_export_YYYYMMDD_HHMMSS/deploy-to-new-server.sh
```

---

## 🚀 **Method 3: Setup Otomatis**

### **Setup Kong di Server Baru**
```bash
# Jalankan script setup otomatis
./scripts/setup-kong-new-server.sh
```

Script ini akan:
- Start Kong jika belum berjalan
- Buat service SSO default
- Buat routes SSO default
- Tambahkan plugins default
- Test endpoints

---

## 📋 **Workflow Lengkap**

### **Scenario A: Migrasi Lengkap**
```bash
# Di server lama
./scripts/export-kong-config.sh

# Copy ke server baru
scp -r kong_export_*/ user@new-server:/path/to/kong-api-gateway/

# Di server baru
cd /path/to/kong-api-gateway
./kong_export_*/deploy-to-new-server.sh
```

### **Scenario B: Setup Baru dengan Konfigurasi Default**
```bash
# Di server baru
cd /path/to/kong-api-gateway
./scripts/setup-kong-new-server.sh
```

### **Scenario C: Import Konfigurasi Manual**
```bash
# Di server baru
cd /path/to/kong-api-gateway
./scripts/import-kong-config.sh kong_full_config.json
```

---

## 🔍 **Verifikasi Setup**

### **Cek Konfigurasi**
```bash
# Cek services
curl http://localhost:9546/services/ | jq

# Cek routes
curl http://localhost:9546/routes/ | jq

# Cek plugins
curl http://localhost:9546/plugins/ | jq
```

### **Test Endpoints**
```bash
# Test SSO endpoint
curl -v http://localhost:9545/api/auth/sso/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@sso-testing.com","password":"admin123","client_id":"string","redirect_uri":"string"}'

# Test endpoint lain
curl -v http://localhost:9545/api/your-endpoint
```

### **Monitor Logs**
```bash
# Monitor Kong logs
docker-compose logs -f kong
```

---

## 🛠️ **Troubleshooting**

### **Jika Import Gagal**
```bash
# Cek Kong status
curl http://localhost:9546/status

# Cek Kong logs
docker-compose logs kong

# Restart Kong
docker-compose restart kong
```

### **Jika Endpoint Tidak Bekerja**
```bash
# Cek service configuration
curl http://localhost:9546/services/sso-service | jq

# Cek routes
curl http://localhost:9546/routes/ | jq

# Test service langsung
curl https://api-gate.motorsights.com/api/auth/sso/login
```

### **Rollback jika Perlu**
```bash
# Rollback ke backup
curl -X POST http://localhost:9546/config -F "config=@kong_backup_YYYYMMDD_HHMMSS.json"
```

---

## 📊 **Perbandingan Methods**

| Method | Pros | Cons | Use Case |
|--------|------|------|----------|
| **Export/Import** | Simple, complete | Manual process | Quick migration |
| **Script Export** | Automated, includes docs | More complex | Production migration |
| **Setup Otomatis** | Fast, default config | Limited customization | New server setup |

---

## 🎯 **Best Practices**

### **Sebelum Migrasi**
1. **Backup konfigurasi** dari server lama
2. **Test konfigurasi** di environment staging
3. **Dokumentasikan** semua custom settings

### **Saat Migrasi**
1. **Stop traffic** ke server lama
2. **Export konfigurasi** lengkap
3. **Import ke server baru**
4. **Test semua endpoints**

### **Setelah Migrasi**
1. **Monitor logs** untuk error
2. **Test semua endpoints**
3. **Update DNS** ke server baru
4. **Monitor performance**

---

## 🚀 **Quick Commands**

### **Export dari Server Lama**
```bash
curl http://localhost:9546/config > kong_config.json
```

### **Import ke Server Baru**
```bash
curl -X POST http://localhost:9546/config -F "config=@kong_config.json"
```

### **Setup Otomatis**
```bash
./scripts/setup-kong-new-server.sh
```

### **Verifikasi**
```bash
curl http://localhost:9546/services/ | jq
curl http://localhost:9545/api/auth/sso/login
```

---

## 📝 **Contoh Praktis**

### **Migrasi Server Production**
```bash
# 1. Di server lama
./scripts/export-kong-config.sh

# 2. Copy ke server baru
scp -r kong_export_20250916_143022/ user@new-server:/opt/kong-api-gateway/

# 3. Di server baru
cd /opt/kong-api-gateway
./kong_export_20250916_143022/deploy-to-new-server.sh

# 4. Test endpoints
curl -v http://localhost:9545/api/auth/sso/login

# 5. Update DNS
# Update A record dari old-server-ip ke new-server-ip
```

### **Setup Server Development**
```bash
# Di server development
cd /path/to/kong-api-gateway
./scripts/setup-kong-new-server.sh

# Test
curl http://localhost:9545/api/auth/sso/login
```

---

**Dengan methods ini, Anda tidak perlu insert ulang semua service, routes, dan plugins secara manual. Semua konfigurasi bisa di-export dan di-import dengan mudah!** 🚀
