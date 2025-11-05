# 🔍 Analisis Konflik: Kong Instance 1 vs Instance 2

Dokumen ini menganalisis potensi konflik saat menjalankan kedua Kong instance di server yang sama.

## ✅ **TIDAK ADA KONFLIK** - Aman Dijalankan Bersamaan

### 1. Port Allocation ✅

| Port | Instance 1 | Instance 2 | Status |
|------|-----------|-----------|--------|
| **Proxy** | 9545 | 9588 | ✅ **TIDAK KONFLIK** |
| **Admin API** | 9546 | 9589 | ✅ **TIDAK KONFLIK** |
| **Admin GUI** | 9547 | 9590 | ✅ **TIDAK KONFLIK** |

**Kesimpulan**: Port berbeda, tidak ada overlap. ✅

---

### 2. Container Names ✅

| Instance | Container Name | Status |
|----------|---------------|--------|
| Instance 1 | `kong-gateway` | ✅ |
| Instance 2 | `kong-gateway2` | ✅ |

**Kesimpulan**: Nama container berbeda, tidak ada konflik. ✅

---

### 3. Network Configuration ✅

**Kedua instance menggunakan `network_mode: host`:**

```yaml
# Instance 1 & 2
network_mode: host
```

**Analisis:**
- ✅ **AMAN**: Meskipun menggunakan host network yang sama, port berbeda
- ✅ **Isolated**: Setiap instance bind ke port sendiri-sendiri
- ✅ **No conflict**: Host network mode hanya berarti menggunakan network stack host, bukan share network namespace

**Kesimpulan**: Network mode sama, tapi aman karena port berbeda. ✅

---

### 4. Config File Sharing ✅

**Kedua instance menggunakan file config yang sama:**
```yaml
volumes:
  - ./config/kong.yml:/kong/kong.yml:ro
```

**Analisis:**
- ✅ **Read-only**: File mount sebagai read-only, tidak ada race condition
- ✅ **Independent**: Setiap instance membaca file secara independen
- ⚠️ **Perhatian**: Jika ada duplicate route/service names di kong.yml, **kedua instance akan crash**

**Kesimpulan**: Sharing config file aman, asalkan tidak ada duplicate names. ✅

---

### 5. Resource Usage ⚠️

**Dampak Resource saat menjalankan 2 instance:**

| Resource | Per Instance | Total (2 instance) |
|----------|-------------|-------------------|
| **Memory** | ~200-400 MB | ~400-800 MB |
| **CPU** | Low-Medium | ~2x |
| **Disk** | Minimal (shared config) | Minimal |
| **Network** | Berbagi host network | Tidak ada overhead tambahan |

**Kesimpulan**: Resource usage akan double, tapi masih wajar untuk server modern. ⚠️

---

## 🚨 **POTENSI MASALAH & SOLUSI**

### ⚠️ Issue 1: Duplicate Route/Service Names

**Masalah:**
Jika `kong.yml` memiliki duplicate route atau service names, **kedua instance akan crash** saat startup.

**Cek:**
```bash
# Check duplicate route names
grep -E "^\s+- name:" config/kong.yml | sort | uniq -d

# Check duplicate service names  
grep -E "^\s+- name:.*-service" config/kong.yml | sort | uniq -d
```

**Solusi:**
- Pastikan tidak ada duplicate names di `kong.yml`
- Gunakan script validation sebelum deploy:
  ```bash
  ./scripts/deploy-kong-routes2.sh validate
  ```

---

### ⚠️ Issue 2: Resource Exhaustion

**Masalah:**
Dua instance akan menggunakan ~2x resource dibanding satu instance.

**Solusi:**
- Monitor resource usage:
  ```bash
  docker stats kong-gateway kong-gateway2
  ```
- Jika server kurang resource, pertimbangkan:
  - Upgrade server specs
  - Atau jalankan hanya satu instance yang diperlukan

---

### ⚠️ Issue 3: Log Management

**Masalah:**
Log dari kedua instance tercampur jika tidak difilter.

**Solusi:**
```bash
# View Instance 1 logs only
docker logs kong-gateway --tail 50 -f

# View Instance 2 logs only
docker logs kong-gateway2 --tail 50 -f

# View both (separated)
docker logs kong-gateway --tail 20 && echo "---" && docker logs kong-gateway2 --tail 20
```

---

### ⚠️ Issue 4: Docker Compose Project Name Conflict

**Masalah:**
Kedua docker-compose file menggunakan service name `kong`, sehingga saat menjalankan satu file bisa mempengaruhi yang lain karena menggunakan project name default yang sama.

**Solusi:**
Gunakan script `start-kong-instances.sh` yang sudah meng-handle project name berbeda, atau gunakan flag `-p` (project name) secara manual:

```bash
# Menggunakan script (RECOMMENDED)
./scripts/start-kong-instances.sh start

# Atau manual dengan project name berbeda
docker-compose -p kong-instance1 -f docker-compose.server.yml up -d
docker-compose -p kong-instance2 -f docker-compose.server2.yml up -d
```

---

## 🚀 **CARA MENGGUNAKAN KEDUA INSTANCE**

### **Method 1: Menggunakan Script (RECOMMENDED) ✅**

Script `start-kong-instances.sh` sudah menangani semua konflik dan memastikan kedua instance bisa berjalan bersamaan:

```bash
# Start kedua instance
./scripts/start-kong-instances.sh start

# Check status
./scripts/start-kong-instances.sh status

# Stop kedua instance
./scripts/start-kong-instances.sh stop

# Restart kedua instance
./scripts/start-kong-instances.sh restart

# View logs
./scripts/start-kong-instances.sh logs 1  # Instance 1
./scripts/start-kong-instances.sh logs 2  # Instance 2

# Test kedua instance
./scripts/start-kong-instances.sh test
```

### **Method 2: Manual dengan Project Name**

Jika ingin menggunakan docker-compose langsung, gunakan project name berbeda:

```bash
# Start Instance 1
docker-compose -p kong-instance1 -f docker-compose.server.yml up -d

# Start Instance 2
docker-compose -p kong-instance2 -f docker-compose.server2.yml up -d

# Stop Instance 1
docker-compose -p kong-instance1 -f docker-compose.server.yml down

# Stop Instance 2
docker-compose -p kong-instance2 -f docker-compose.server2.yml down
```

**⚠️ PENTING**: Jika tidak menggunakan project name (`-p`), docker-compose akan menggunakan project name default yang sama, menyebabkan konflik!

---

## 📊 **TABEL PERBANDINGAN LENGKAP**

| Aspect | Instance 1 | Instance 2 | Konflik? |
|--------|-----------|-----------|----------|
| **Container Name** | `kong-gateway` | `kong-gateway2` | ❌ No |
| **Proxy Port** | 9545 | 9588 | ❌ No |
| **Admin Port** | 9546 | 9589 | ❌ No |
| **Admin GUI Port** | 9547 | 9590 | ❌ No |
| **Network Mode** | `host` | `host` | ❌ No* |
| **Config File** | `kong.yml` | `kong.yml` | ❌ No* |
| **Image** | `kong:3.4` | `kong:3.4` | ❌ No |
| **DNS Resolver** | Shared | Shared | ❌ No |
| **Resource Usage** | ~300MB | ~300MB | ⚠️ Double |
| **Project Name** | `kong-instance1` | `kong-instance2` | ❌ No |

*Tidak ada konflik karena isolated execution

---

## ✅ **KESIMPULAN**

### **AMAN Dijalankan Bersamaan** ✅

1. ✅ **Port berbeda** - Tidak ada konflik port
2. ✅ **Container name berbeda** - Tidak ada konflik container
3. ✅ **Network isolated** - Meski sama-sama host mode, port berbeda
4. ✅ **Config sharing aman** - Read-only mount, tidak ada race condition
5. ✅ **Project name berbeda** - Tidak ada konflik docker-compose
6. ⚠️ **Resource usage** - Akan double, tapi masih wajar

### **Yang Perlu Diperhatikan:**

1. ⚠️ **Pastikan tidak ada duplicate names** di `kong.yml`
2. ⚠️ **Monitor resource usage** server
3. ⚠️ **Filter logs** berdasarkan container name
4. ⚠️ **Gunakan project name berbeda** atau script helper untuk menghindari konflik docker-compose

### **Recommended Workflow:**

```bash
# 1. Validate config
./scripts/deploy-kong-routes.sh validate
./scripts/deploy-kong-routes2.sh validate

# 2. Start both instances (RECOMMENDED)
./scripts/start-kong-instances.sh start

# 3. Check status
./scripts/start-kong-instances.sh status

# 4. Test both
./scripts/start-kong-instances.sh test
```

---

## 🧪 **Test Konflik**

Jalankan script berikut untuk test konflik:

```bash
# Check port conflicts
netstat -tuln | grep -E '9545|9546|9547|9588|9589|9590'

# Check container status
docker ps | grep kong-gateway

# Test both instances
curl -s http://localhost:9546/status | jq '.'  # Instance 1
curl -s http://localhost:9589/status | jq '.'  # Instance 2

# Atau gunakan script helper
./scripts/start-kong-instances.sh test
```

---

**Last Updated:** October 2025  
**Status:** ✅ **NO CONFLICTS - Safe to Run Both Instances**  
**Script Helper:** `./scripts/start-kong-instances.sh`
