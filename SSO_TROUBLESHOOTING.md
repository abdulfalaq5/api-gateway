# SSO Service Troubleshooting Guide

## 🚨 Masalah SSO Timeout

### Gejala Masalah
- ✅ SSO API langsung bekerja: `https://api-gate.motorsights.com/api/auth/sso/login`
- ❌ SSO API melalui Kong gagal: `https://services.motorsights.com/api/auth/sso/login`
- ⏱️ Kong log menunjukkan timeout: `upstream timed out (110: Connection timed out)`
- 🔑 Error duplicate key: `duplicate key value violates unique constraint`

### Analisis Root Cause

Berdasarkan log yang diberikan:

```
kong-gateway | 2025/09/16 02:10:01 [error] 1260#0: *178 upstream timed out (110: Connection timed out) while connecting to upstream, client: 172.24.0.1, server: kong, request: "POST /api/auth/sso/login HTTP/1.1", upstream: "http://172.17.0.1:9588/api/auth/sso/login", host: "services.motorsights.com"
```

**Masalah yang teridentifikasi:**

1. **Upstream URL Mismatch**: 
   - Kong mencoba mengakses `http://172.17.0.1:9588`
   - Tetapi SSO service sebenarnya di `https://api-gate.motorsights.com`

2. **Network Connectivity**: 
   - Kong container tidak bisa terhubung ke `172.17.0.1:9588`
   - IP `172.17.0.1` adalah Docker bridge network yang mungkin tidak accessible

3. **Duplicate Configuration**:
   - Routes dan plugins sudah ada di database Kong
   - Deploy ulang menyebabkan konflik unique constraint

## 🔧 Solusi Lengkap

### Solusi Otomatis (Recommended)
```bash
# Jalankan script fix otomatis
./scripts/fix-kong-sso-issues.sh
```

### Solusi Manual Step-by-Step

#### Step 1: Test Connectivity
```bash
# Test apakah SSO service accessible
./scripts/test-sso-connectivity.sh
```

#### Step 2: Clean Database
```bash
# Hapus konfigurasi duplikat dari database Kong
./scripts/clean-kong-database.sh
```

#### Step 3: Fix Upstream Configuration
```bash
# Perbaiki konfigurasi upstream SSO
./scripts/fix-sso-upstream.sh
```

#### Step 4: Test Final Configuration
```bash
# Test endpoint melalui Kong
curl --location 'https://services.motorsights.com/api/auth/sso/login' \
  --header 'Content-Type: application/json' \
  --data-raw '{
    "email": "admin@sso-testing.com",
    "password": "admin123",
    "client_id": "string",
    "redirect_uri": "string"
  }'
```

## 🔍 Troubleshooting Detail

### 1. Cek Upstream URL

**Masalah**: Kong menggunakan URL yang salah untuk upstream

**Solusi**:
```bash
# Cek konfigurasi service saat ini
curl http://localhost:9546/services/sso-service | jq

# Update upstream URL jika salah
curl -X PATCH http://localhost:9546/services/sso-service \
  -d "url=https://api-gate.motorsights.com"
```

### 2. Cek Network Connectivity

**Masalah**: Kong container tidak bisa terhubung ke SSO service

**Test connectivity**:
```bash
# Test dari dalam Kong container
docker exec kong-gateway curl -v https://api-gate.motorsights.com/api/auth/sso/login

# Test dari host
curl -v https://api-gate.motorsights.com/api/auth/sso/login
```

**Solusi**:
- Pastikan SSO service accessible dari network Kong
- Gunakan `host.docker.internal` untuk akses dari container ke host
- Atau gunakan IP external yang accessible

### 3. Cek Timeout Settings

**Masalah**: Timeout terlalu rendah untuk SSO service

**Solusi**:
```bash
# Update timeout settings
curl -X PATCH http://localhost:9546/services/sso-service \
  -d "connect_timeout=60000" \
  -d "write_timeout=60000" \
  -d "read_timeout=60000"
```

### 4. Cek Routes Configuration

**Masalah**: Routes tidak dikonfigurasi dengan benar

**Cek routes**:
```bash
# List semua routes
curl http://localhost:9546/routes/ | jq

# Cek route SSO login
curl http://localhost:9546/routes/sso-login-routes | jq
```

**Solusi**:
```bash
# Update route jika perlu
curl -X PATCH http://localhost:9546/routes/sso-login-routes \
  -d "strip_path=false"
```

## 📊 Monitoring dan Debugging

### Monitor Kong Logs
```bash
# Real-time logs
docker-compose logs -f kong

# Filter error logs
docker-compose logs kong | grep -i error

# Filter timeout logs
docker-compose logs kong | grep -i timeout
```

### Monitor Kong Status
```bash
# Kong health check
curl http://localhost:9546/status | jq

# Services status
curl http://localhost:9546/services/ | jq

# Routes status
curl http://localhost:9546/routes/ | jq
```

### Test Endpoints
```bash
# Test Kong proxy
curl http://localhost:9545/

# Test SSO endpoint
curl -X POST http://localhost:9545/api/auth/sso/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"test","client_id":"test","redirect_uri":"test"}'
```

## 🛠️ Advanced Configuration

### Environment Configuration
Update `config/env.sh`:
```bash
# SSO Service Configuration
SSO_UPSTREAM_URL="https://api-gate.motorsights.com"

# Timeout Configuration (milliseconds)
CONNECT_TIMEOUT="60000"
WRITE_TIMEOUT="60000"
READ_TIMEOUT="60000"
```

### Kong Configuration Update
Update `config/kong.yml`:
```yaml
services:
  - name: sso-service
    url: https://api-gate.motorsights.com
    connect_timeout: 60000
    write_timeout: 60000
    read_timeout: 60000
    routes:
      - name: sso-login-routes
        paths:
          - /api/auth/sso/login
        methods:
          - POST
          - OPTIONS
        strip_path: false
```

## 🚨 Emergency Recovery

### Jika Semua Gagal
```bash
# Complete reset Kong
docker-compose down
docker volume rm kong-api-gateway_kong_data 2>/dev/null || true
docker-compose up -d

# Tunggu Kong startup
sleep 30

# Deploy fresh configuration
./scripts/deploy-kong-config.sh
```

### Backup dan Restore
```bash
# Backup konfigurasi saat ini
curl http://localhost:9546/config > kong-backup-$(date +%Y%m%d_%H%M%S).json

# Restore dari backup
curl -X POST http://localhost:9546/config -F "config=@kong-backup-YYYYMMDD_HHMMSS.json"
```

## 📋 Checklist SSO Fix

- [ ] SSO service accessible langsung
- [ ] Kong container berjalan
- [ ] Database Kong clean dari duplikat
- [ ] Upstream URL benar
- [ ] Timeout settings adequate
- [ ] Routes dikonfigurasi dengan benar
- [ ] Test endpoint berhasil
- [ ] Monitor logs tidak ada error

## 🎯 Expected Results

Setelah fix berhasil:
- ✅ `curl https://services.motorsights.com/api/auth/sso/login` berhasil
- ✅ Kong logs tidak menunjukkan timeout error
- ✅ SSO login response sama dengan direct API
- ✅ Tidak ada duplicate key errors

---

**Catatan**: Selalu backup konfigurasi sebelum melakukan perubahan besar!
