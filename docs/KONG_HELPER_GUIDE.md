# Kong Helper Script - Usage Guide

## 🚀 **Kong Helper Script**

Script helper untuk operasi Kong API Gateway yang paling sering digunakan. Memudahkan management Kong tanpa perlu mengingat curl commands yang panjang.

## 📋 **Installation**

```bash
# Pastikan script executable
chmod +x scripts/kong-helper.sh

# Test script
./scripts/kong-helper.sh help
```

## 🔧 **Available Commands**

### **1. Status & Monitoring**
```bash
# Cek status Kong
./scripts/kong-helper.sh status

# Monitor Kong logs
./scripts/kong-helper.sh logs
```

### **2. List Operations**
```bash
# List semua services
./scripts/kong-helper.sh services

# List semua routes
./scripts/kong-helper.sh routes

# List semua plugins
./scripts/kong-helper.sh plugins
```

### **3. Service Operations**
```bash
# Cek service spesifik
./scripts/kong-helper.sh service sso-service

# Cek routes untuk service
./scripts/kong-helper.sh routes sso-service
```

### **4. Testing**
```bash
# Test endpoint
./scripts/kong-helper.sh test /api/auth/sso/login

# Test SSO endpoint
./scripts/kong-helper.sh sso
```

### **5. Maintenance**
```bash
# Backup konfigurasi
./scripts/kong-helper.sh backup

# Restart Kong
./scripts/kong-helper.sh restart

# Cleanup konfigurasi yang salah
./scripts/kong-helper.sh cleanup

# Fix SSO configuration
./scripts/kong-helper.sh fix-sso
```

## 📝 **Usage Examples**

### **Daily Operations**
```bash
# Cek status Kong
./scripts/kong-helper.sh status

# List services
./scripts/kong-helper.sh services

# Test SSO endpoint
./scripts/kong-helper.sh sso
```

### **Troubleshooting**
```bash
# Cek service SSO
./scripts/kong-helper.sh service sso-service

# Cek routes SSO
./scripts/kong-helper.sh routes sso-service

# Monitor logs
./scripts/kong-helper.sh logs
```

### **Maintenance**
```bash
# Backup sebelum perubahan
./scripts/kong-helper.sh backup

# Cleanup konfigurasi yang salah
./scripts/kong-helper.sh cleanup

# Fix SSO jika ada masalah
./scripts/kong-helper.sh fix-sso

# Restart Kong
./scripts/kong-helper.sh restart
```

## 🎯 **Common Workflows**

### **1. Deploy Service Baru**
```bash
# 1. Cek status Kong
./scripts/kong-helper.sh status

# 2. Backup konfigurasi
./scripts/kong-helper.sh backup

# 3. Deploy service (manual curl commands)
curl -X POST http://localhost:9546/services/ \
  -d "name=new-service" \
  -d "url=https://api.example.com"

# 4. Test endpoint
./scripts/kong-helper.sh test /api/v1/new

# 5. Monitor logs
./scripts/kong-helper.sh logs
```

### **2. Fix SSO Issues**
```bash
# 1. Cek status Kong
./scripts/kong-helper.sh status

# 2. Cek service SSO
./scripts/kong-helper.sh service sso-service

# 3. Test SSO endpoint
./scripts/kong-helper.sh sso

# 4. Fix SSO jika ada masalah
./scripts/kong-helper.sh fix-sso

# 5. Test lagi
./scripts/kong-helper.sh sso
```

### **3. Troubleshooting**
```bash
# 1. Cek status Kong
./scripts/kong-helper.sh status

# 2. List services untuk cek konfigurasi
./scripts/kong-helper.sh services

# 3. List routes untuk cek routing
./scripts/kong-helper.sh routes

# 4. Monitor logs untuk error
./scripts/kong-helper.sh logs
```

## 🔍 **Output Examples**

### **Status Check**
```
================================
Kong is running
================================
```

### **Services List**
```
================================
Kong Services
================================
{
  "name": "sso-service",
  "host": "api-gate.motorsights.com",
  "port": 443,
  "protocol": "https",
  "url": null
}
```

### **SSO Test**
```
================================
Testing SSO Endpoint
================================
✅ SSO endpoint working (HTTP 200)
```

## 🛠️ **Customization**

### **Ubah Kong Admin URL**
Edit script dan ubah:
```bash
KONG_ADMIN="http://your-server-ip:9546"
KONG_PROXY="http://your-server-ip:9545"
```

### **Tambah Command Baru**
Tambahkan case baru di script:
```bash
"new-command")
    # Your command logic here
    ;;
```

## 📊 **Integration dengan Manual Commands**

Script ini melengkapi manual commands. Gunakan kombinasi:

```bash
# Quick check dengan script
./scripts/kong-helper.sh status
./scripts/kong-helper.sh services

# Detail operations dengan manual commands
curl http://localhost:9546/services/sso-service | jq
curl -X PATCH http://localhost:9546/services/sso-service -d "url=https://new-api.com"

# Test dengan script
./scripts/kong-helper.sh sso
```

## 🚨 **Error Handling**

Script akan menampilkan error jika:
- Kong tidak berjalan
- Network tidak accessible
- Command tidak valid

```bash
❌ Kong is not running or not accessible
❌ Service name required
❌ Unknown command: invalid-command
```

## 📝 **Tips**

1. **Selalu cek status** sebelum operasi lain
2. **Backup sebelum perubahan** besar
3. **Monitor logs** setelah restart
4. **Test endpoint** setelah perubahan
5. **Gunakan kombinasi** script + manual commands

---

**Catatan**: Script ini dibuat untuk memudahkan operasi Kong sehari-hari. Untuk operasi kompleks, gunakan manual commands yang lebih detail.
