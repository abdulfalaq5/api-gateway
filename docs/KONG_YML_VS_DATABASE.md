# Kong.yml vs Database Mode - Perbedaan dan Solusi

## 🎯 **Jawaban untuk Pertanyaan Anda**

**Ya, menggunakan file `kong.yml` bisa menghindari masalah database cache yang tidak ter-update, TAPI ada syaratnya!**

## 🔍 **Perbedaan Kong.yml vs Database Mode**

### **1. Database Mode (Saat Ini)**
```bash
# Kong menggunakan PostgreSQL database
KONG_DATABASE: postgres
KONG_PG_HOST: host.docker.internal
KONG_PG_PORT: 5432
```

**Masalah:**
- ❌ **Cache issues** - Database mungkin tidak ter-update langsung
- ❌ **Manual commands** - Perlu curl commands untuk update
- ❌ **No version control** - Sulit track perubahan
- ❌ **Incremental updates** - Perubahan satu per satu

**Keuntungan:**
- ✅ **No restart** - Perubahan langsung aktif
- ✅ **Dynamic updates** - Bisa update tanpa restart

### **2. DB-less Mode (Menggunakan kong.yml)**
```bash
# Kong menggunakan file kong.yml
KONG_DATABASE: "off"
KONG_DECLARATIVE_CONFIG: /kong/kong.yml
```

**Keuntungan:**
- ✅ **No cache issues** - Kong reload dari file
- ✅ **Version control** - File bisa di-track di Git
- ✅ **Atomic updates** - Semua perubahan diterapkan sekaligus
- ✅ **Easy rollback** - Tinggal ganti file dan restart

**Kekurangan:**
- ❌ **Kong restart** - Perlu restart Kong untuk apply changes
- ❌ **File-based** - Perubahan harus melalui file

## 🚀 **Solusi: Switch ke DB-less Mode**

### **Option 1: Switch ke DB-less Mode (Recommended)**
```bash
# Switch Kong ke DB-less mode
./scripts/switch-to-dbless.sh
```

Script ini akan:
1. Backup konfigurasi saat ini
2. Export ke kong.yml
3. Update docker-compose.yml untuk DB-less mode
4. Restart Kong
5. Test endpoints

### **Option 2: Tetap Database Mode dengan Kong.yml**
```bash
# Update konfigurasi dari kong.yml (tetap database mode)
./scripts/update-kong-yml.sh
```

**Note**: Ini hanya bisa dilakukan jika Kong sudah di DB-less mode.

## 📋 **Workflow Lengkap**

### **Scenario A: Switch ke DB-less Mode**
```bash
# 1. Switch ke DB-less mode
./scripts/switch-to-dbless.sh

# 2. Edit config/kong.yml untuk perubahan
vim config/kong.yml

# 3. Restart Kong untuk apply changes
docker-compose restart kong

# 4. Test endpoints
curl http://localhost:9545/api/auth/sso/login
```

### **Scenario B: Tetap Database Mode**
```bash
# 1. Update konfigurasi manual
curl -X PATCH http://localhost:9546/services/sso-service \
  -d "url=https://api-gate.motorsights.com"

# 2. Restart Kong untuk clear cache
docker-compose restart kong

# 3. Test endpoints
curl http://localhost:9545/api/auth/sso/login
```

## 🔧 **Cara Update Konfigurasi**

### **DB-less Mode (Menggunakan kong.yml)**
```bash
# 1. Edit kong.yml
vim config/kong.yml

# 2. Restart Kong
docker-compose restart kong

# 3. Test endpoints
curl http://localhost:9545/api/auth/sso/login
```

### **Database Mode (Manual Commands)**
```bash
# 1. Update service
curl -X PATCH http://localhost:9546/services/sso-service \
  -d "url=https://api-gate.motorsights.com"

# 2. Restart Kong untuk clear cache
docker-compose restart kong

# 3. Test endpoints
curl http://localhost:9545/api/auth/sso/login
```

## 📊 **Perbandingan Methods**

| Method | Cache Issues | Version Control | Restart Required | Easy Rollback |
|--------|-------------|----------------|------------------|---------------|
| **Database Mode** | ❌ Yes | ❌ No | ❌ Yes | ❌ No |
| **DB-less Mode** | ✅ No | ✅ Yes | ✅ Yes | ✅ Yes |

## 🎯 **Rekomendasi**

### **Untuk Development**
```bash
# Gunakan DB-less mode
./scripts/switch-to-dbless.sh
```

**Keuntungan:**
- No cache issues
- Version control friendly
- Easy rollback
- Atomic updates

### **Untuk Production**
```bash
# Tetap database mode dengan monitoring
# Monitor logs untuk cache issues
docker-compose logs -f kong
```

**Keuntungan:**
- Dynamic updates
- No restart required
- Better performance

## 🛠️ **Troubleshooting**

### **Jika Database Cache Issues**
```bash
# Method 1: Restart Kong
docker-compose restart kong

# Method 2: Switch ke DB-less mode
./scripts/switch-to-dbless.sh

# Method 3: Manual cleanup
curl -X DELETE http://localhost:9546/services/wrong-service
curl -X PATCH http://localhost:9546/services/sso-service -d "url=https://api-gate.motorsights.com"
```

### **Jika Kong.yml Tidak Ter-apply**
```bash
# Cek Kong mode
curl http://localhost:9546/status | jq '.database.reachable'

# Jika database mode, switch ke DB-less
./scripts/switch-to-dbless.sh

# Jika DB-less mode, restart Kong
docker-compose restart kong
```

## 📝 **Best Practices**

### **Untuk Development**
1. **Gunakan DB-less mode** - No cache issues
2. **Edit kong.yml** - Version control friendly
3. **Restart Kong** - Apply changes
4. **Test endpoints** - Verify changes

### **Untuk Production**
1. **Monitor logs** - Watch for cache issues
2. **Backup sebelum update** - Safety first
3. **Test setelah update** - Verify changes
4. **Rollback plan** - Be prepared

## 🚀 **Quick Commands**

### **Switch ke DB-less Mode**
```bash
./scripts/switch-to-dbless.sh
```

### **Update kong.yml**
```bash
# Edit file
vim config/kong.yml

# Restart Kong
docker-compose restart kong
```

### **Tetap Database Mode**
```bash
# Update manual
curl -X PATCH http://localhost:9546/services/sso-service -d "url=https://api-gate.motorsights.com"

# Restart untuk clear cache
docker-compose restart kong
```

---

**Jadi jawabannya: Ya, menggunakan kong.yml bisa menghindari database cache issues, tapi Anda perlu switch ke DB-less mode terlebih dahulu. Atau tetap database mode tapi restart Kong setelah setiap update untuk clear cache.** 🚀
