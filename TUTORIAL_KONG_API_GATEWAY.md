# Kong API Gateway - Tutorial Lengkap

## 📋 Daftar Isi
1. [Setup Kong di Server](#1-setup-kong-di-server)
2. [Operasi Docker Kong](#2-operasi-docker-kong)
3. [Menambahkan Endpoint melalui File YML](#3-menambahkan-endpoint-melalui-file-yml)
4. [Troubleshooting](#4-troubleshooting)
5. [Referensi](#5-referensi)

---

## 1. Setup Kong di Server

### 1.1 Prerequisites
Pastikan server sudah memiliki:
- ✅ Docker dan Docker Compose
- ✅ PostgreSQL yang sudah berjalan
- ✅ User database dengan hak akses untuk membuat database
- ✅ Port yang diperlukan sudah tersedia

### 1.2 Port Configuration
| Port | Service | Akses | Deskripsi |
|------|---------|-------|-----------|
| **9545** | Kong Proxy | **Public** | Port utama untuk client mengakses API |
| **9546** | Kong Admin API | **Internal Only** | Management Kong via API |
| **9547** | Kong Admin GUI | **Internal Only** | Interface web untuk management |
| **5432** | PostgreSQL | **Internal Only** | Database Kong |

### 1.3 Persiapan Database PostgreSQL

#### Login ke PostgreSQL
```bash
# Login sebagai superuser
sudo -u postgres psql

# Atau jika menggunakan user lain
psql -h localhost -U postgres
```

#### Buat Database Kong
```sql
-- Buat database kong
CREATE DATABASE kong;

-- Buat user kong (opsional, bisa menggunakan user yang sudah ada)
CREATE USER kong WITH PASSWORD 'kong_password';

-- Berikan hak akses ke database kong
GRANT ALL PRIVILEGES ON DATABASE kong TO kong;

-- Keluar dari psql
\q
```

#### Verifikasi Database
```bash
# Test koneksi ke database kong
psql -h localhost -U kong -d kong -c "SELECT version();"
```

### 1.4 Konfigurasi Docker Compose

File `docker-compose.yml` sudah dikonfigurasi dengan:
- Kong Proxy di port 9545
- Kong Admin API di port 9546
- Kong Admin GUI di port 9547
- Koneksi ke PostgreSQL yang sudah ada

### 1.5 Setup Firewall

#### Ubuntu/Debian (UFW)
```bash
# Allow Kong Proxy (Public)
sudo ufw allow 9545/tcp comment "Kong Proxy - Public Access"

# Allow Kong Admin API (Internal Only)
sudo ufw allow from 192.168.1.0/24 to any port 9546 comment "Kong Admin API - Internal"

# Allow Kong Admin GUI (Internal Only)
sudo ufw allow from 192.168.1.0/24 to any port 9547 comment "Kong Admin GUI - Internal"

# Allow PostgreSQL (Internal Only)
sudo ufw allow from 192.168.1.0/24 to any port 5432 comment "PostgreSQL - Internal"
```

#### CentOS/RHEL (iptables)
```bash
# Allow Kong Proxy (Public)
sudo iptables -A INPUT -p tcp --dport 9545 -j ACCEPT

# Allow Kong Admin API (Internal Only)
sudo iptables -A INPUT -p tcp --dport 9546 -s 192.168.1.0/24 -j ACCEPT

# Allow Kong Admin GUI (Internal Only)
sudo iptables -A INPUT -p tcp --dport 9547 -s 192.168.1.0/24 -j ACCEPT

# Allow PostgreSQL (Internal Only)
sudo iptables -A INPUT -p tcp --dport 5432 -s 192.168.1.0/24 -j ACCEPT

# Save rules
sudo iptables-save > /etc/iptables/rules.v4
```

---

## 2. Operasi Docker Kong

### 2.1 Menjalankan Kong

#### Menggunakan Script (Recommended)
```bash
# Jalankan Kong dengan script
./scripts/start-kong-docker.sh
```

#### Manual dengan Docker Compose
```bash
# Jalankan Kong
docker-compose up -d

# Atau dengan rebuild
docker-compose up -d --build
```

### 2.2 Menghentikan Kong

#### Menggunakan Script
```bash
# Hentikan Kong dengan script
./scripts/stop-kong-docker.sh
```

#### Manual dengan Docker Compose
```bash
# Hentikan Kong
docker-compose down

# Hentikan dan hapus volume (HATI-HATI!)
docker-compose down -v
```

### 2.3 Restart Kong

```bash
# Restart Kong
docker-compose restart

# Atau restart service tertentu
docker-compose restart kong
```

### 2.4 Start Kong (setelah stop)

```bash
# Start Kong yang sudah dihentikan
docker-compose start

# Atau start service tertentu
docker-compose start kong
```

### 2.5 Monitoring Kong

#### Cek Status Kong
```bash
# Cek status container
docker-compose ps

# Cek log Kong
docker-compose logs kong

# Cek log real-time
docker-compose logs -f kong
```

#### Test Kong
```bash
# Test Kong dengan script
./scripts/test-kong-docker.sh

# Manual test
curl http://localhost:9545/  # Kong Proxy
curl http://localhost:9546/  # Kong Admin API
curl http://localhost:9547/  # Kong Admin GUI
```

### 2.6 Command Reference

| Command | Deskripsi |
|---------|-----------|
| `docker-compose up -d` | Jalankan Kong di background |
| `docker-compose down` | Hentikan Kong |
| `docker-compose restart` | Restart Kong |
| `docker-compose start` | Start Kong yang sudah dihentikan |
| `docker-compose stop` | Stop Kong tanpa menghapus container |
| `docker-compose ps` | Cek status container |
| `docker-compose logs kong` | Lihat log Kong |
| `docker-compose logs -f kong` | Lihat log Kong real-time |

---

## 3. Menambahkan Endpoint melalui File YML

### 3.1 Struktur File kong.yml

File `config/kong.yml` menggunakan format declarative configuration Kong:

```yaml
_format_version: "3.0"
_transform: true

services:
  - name: nama-service
    url: http://backend-service:port
    routes:
      - name: nama-route
        paths:
          - /api/path
        methods:
          - GET
          - POST
        strip_path: true
    plugins:
      - name: plugin-name
        config:
          parameter: value

plugins:
  - name: global-plugin
    config:
      parameter: value
```

### 3.2 Menambahkan Service Baru

#### Contoh Service Sederhana
```yaml
services:
  - name: user-service
    url: http://localhost:3001
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
```

#### Service dengan Multiple Routes
```yaml
services:
  - name: auth-service
    url: http://localhost:3002
    routes:
      - name: auth-login-route
        paths:
          - /api/auth/login
        methods:
          - POST
        strip_path: false
      - name: auth-register-route
        paths:
          - /api/auth/register
        methods:
          - POST
        strip_path: false
      - name: auth-profile-route
        paths:
          - /api/auth/profile
        methods:
          - GET
          - PUT
        strip_path: true
```

### 3.3 Menambahkan Plugin

#### Rate Limiting
```yaml
services:
  - name: api-service
    url: http://localhost:3000
    routes:
      - name: api-routes
        paths:
          - /api/v1
        strip_path: true
    plugins:
      - name: rate-limiting
        config:
          minute: 100
          hour: 1000
          policy: local
```

#### CORS Plugin
```yaml
services:
  - name: web-service
    url: http://localhost:3000
    routes:
      - name: web-routes
        paths:
          - /api/web
        strip_path: true
    plugins:
      - name: cors
        config:
          origins:
            - "http://localhost:3000"
            - "https://yourdomain.com"
          methods:
            - GET
            - POST
            - PUT
            - DELETE
            - OPTIONS
          headers:
            - Accept
            - Content-Type
            - Authorization
          credentials: true
```

#### Authentication Plugin
```yaml
services:
  - name: protected-service
    url: http://localhost:3000
    routes:
      - name: protected-routes
        paths:
          - /api/protected
        strip_path: true
    plugins:
      - name: key-auth
        config:
          key_names:
            - apikey
            - x-api-key
```

### 3.4 Global Plugins

```yaml
plugins:
  - name: cors
    config:
      origins:
        - "*"
      methods:
        - GET
        - POST
        - PUT
        - DELETE
        - OPTIONS
      headers:
        - Accept
        - Content-Type
        - Authorization
        - X-Auth-Token
      credentials: true
      max_age: 3600
```

### 3.5 Deploy Configuration

#### Menggunakan Kong Admin API
```bash
# Deploy configuration dari file YML
curl -X POST http://localhost:9546/config \
  -F "config=@config/kong.yml"
```

#### Menggunakan Kong CLI (jika tersedia)
```bash
# Deploy configuration
kong config db_import config/kong.yml
```

### 3.6 Contoh Lengkap kong.yml

```yaml
_format_version: "3.0"
_transform: true

services:
  # User Management Service
  - name: user-service
    url: http://localhost:3001
    routes:
      - name: user-crud-routes
        paths:
          - /api/users
        methods:
          - GET
          - POST
          - PUT
          - DELETE
        strip_path: true
    plugins:
      - name: rate-limiting
        config:
          minute: 60
          hour: 1000
          policy: local

  # Authentication Service
  - name: auth-service
    url: http://localhost:3002
    routes:
      - name: auth-login-route
        paths:
          - /api/auth/login
        methods:
          - POST
        strip_path: false
      - name: auth-register-route
        paths:
          - /api/auth/register
        methods:
          - POST
        strip_path: false
      - name: auth-profile-route
        paths:
          - /api/auth/profile
        methods:
          - GET
          - PUT
        strip_path: true
    plugins:
      - name: key-auth
        config:
          key_names:
            - apikey

  # Product Service
  - name: product-service
    url: http://localhost:3003
    routes:
      - name: product-routes
        paths:
          - /api/products
        methods:
          - GET
          - POST
          - PUT
          - DELETE
        strip_path: true
    plugins:
      - name: rate-limiting
        config:
          minute: 100
          hour: 2000
          policy: local

# Global Plugins
plugins:
  - name: cors
    config:
      origins:
        - "http://localhost:3000"
        - "https://yourdomain.com"
      methods:
        - GET
        - POST
        - PUT
        - DELETE
        - OPTIONS
      headers:
        - Accept
        - Accept-Version
        - Content-Length
        - Content-MD5
        - Content-Type
        - Date
        - Authorization
        - X-Auth-Token
      exposed_headers:
        - X-Auth-Token
        - Authorization
      credentials: true
      max_age: 3600
      preflight_continue: false
```

### 3.7 Deploy Perubahan Konfigurasi

Setelah mengubah file `kong.yml`, ikuti langkah-langkah berikut:

#### Langkah 1: Validasi File YML
```bash
# Validasi syntax file YML (jika Kong CLI tersedia)
kong config parse config/kong.yml

# Atau cek dengan YAML parser
python3 -c "import yaml; yaml.safe_load(open('config/kong.yml'))"
```

#### Langkah 2: Deploy Konfigurasi ke Kong
```bash
# Deploy menggunakan Kong Admin API
curl -X POST http://localhost:9546/config \
  -F "config=@config/kong.yml"

# Atau jika menggunakan Kong CLI
kong config db_import config/kong.yml
```

#### Langkah 3: Verifikasi Deploy
```bash
# Cek semua services
curl http://localhost:9546/services/

# Cek semua routes
curl http://localhost:9546/routes/

# Cek konfigurasi saat ini
curl http://localhost:9546/config
```

#### Langkah 4: Test Endpoint Baru
```bash
# Test endpoint yang sudah diubah
curl http://localhost:9545/api/v1/example

# Test dengan method POST
curl -X POST http://localhost:9545/api/v1/example \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'

# Test SSO service
curl http://localhost:9545/api/auth/sso/login \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"username": "test", "password": "test"}'
```

### 3.8 Troubleshooting Deploy

#### Jika Deploy Gagal
```bash
# Cek log Kong untuk error
docker-compose logs kong

# Cek status Kong
docker-compose ps

# Restart Kong jika diperlukan
docker-compose restart kong
```

#### Jika Route Tidak Berfungsi
```bash
# Cek apakah route terdaftar
curl http://localhost:9546/routes/ | jq '.[] | {name: .name, paths: .paths}'

# Cek service yang terkait
curl http://localhost:9546/services/ | jq '.[] | {name: .name, url: .url}'

# Test koneksi ke backend
curl http://localhost:3000  # untuk example-service
curl http://host.docker.internal:9588  # untuk sso-service
```

### 3.9 Rollback Konfigurasi

Jika ada masalah dengan konfigurasi baru:

```bash
# Backup konfigurasi saat ini
curl http://localhost:9546/config > kong_backup_$(date +%Y%m%d_%H%M%S).json

# Rollback ke konfigurasi sebelumnya
curl -X POST http://localhost:9546/config \
  -F "config=@kong_backup_20240101_120000.json"
```

### 3.10 Workflow Lengkap Setelah Mengubah File YML

Berikut adalah workflow lengkap yang harus diikuti setelah mengubah file `kong.yml`:

#### Step 1: Persiapan
```bash
# Pastikan Kong sedang berjalan
docker-compose ps

# Jika tidak berjalan, start Kong
./scripts/start-kong-docker.sh
```

#### Step 2: Backup Konfigurasi Saat Ini
```bash
# Backup konfigurasi sebelum deploy
curl http://localhost:9546/config > kong_backup_$(date +%Y%m%d_%H%M%S).json

# Atau backup menggunakan declarative config
curl http://localhost:9546/config > kong_current_config.json
```

#### Step 3: Validasi File YML
```bash
# Validasi syntax YAML
python3 -c "import yaml; yaml.safe_load(open('config/kong.yml')); print('✅ YAML syntax valid')"

# Atau dengan Kong CLI (jika tersedia)
kong config parse config/kong.yml
```

#### Step 4: Deploy Konfigurasi
```bash
# Deploy konfigurasi baru
curl -X POST http://localhost:9546/config \
  -F "config=@config/kong.yml"

# Cek response untuk memastikan deploy berhasil
echo "Deploy status: $?"
```

#### Step 5: Verifikasi Deploy
```bash
# Cek services yang terdaftar
echo "=== Services ==="
curl -s http://localhost:9546/services/ | jq '.[] | {name: .name, url: .url}'

# Cek routes yang terdaftar
echo "=== Routes ==="
curl -s http://localhost:9546/routes/ | jq '.[] | {name: .name, paths: .paths, methods: .methods}'

# Cek plugins yang aktif
echo "=== Plugins ==="
curl -s http://localhost:9546/plugins/ | jq '.[] | {name: .name, service: .service.name}'
```

#### Step 6: Test Endpoint
```bash
# Test endpoint berdasarkan konfigurasi saat ini
echo "=== Testing Endpoints ==="

# Test example service
echo "Testing example service..."
curl -s http://localhost:9545/api/v1/example || echo "❌ Example service tidak dapat diakses"

# Test SSO service
echo "Testing SSO login..."
curl -s -X POST http://localhost:9545/api/auth/sso/login \
  -H "Content-Type: application/json" \
  -d '{"username": "test", "password": "test"}' || echo "❌ SSO login tidak dapat diakses"

# Test SSO userinfo
echo "Testing SSO userinfo..."
curl -s http://localhost:9545/api/auth/sso/userinfo || echo "❌ SSO userinfo tidak dapat diakses"

# Test menus
echo "Testing menus..."
curl -s http://localhost:9545/api/menus || echo "❌ Menus tidak dapat diakses"
```

#### Step 7: Monitoring
```bash
# Monitor log Kong untuk error
echo "=== Monitoring Kong Logs ==="
docker-compose logs --tail=50 kong

# Monitor performance
echo "=== Kong Status ==="
curl -s http://localhost:9546/status | jq '.'
```

#### Step 8: Rollback (Jika Diperlukan)
```bash
# Jika ada masalah, rollback ke konfigurasi sebelumnya
if [ -f "kong_backup_$(date +%Y%m%d)*.json" ]; then
    echo "Rolling back to previous configuration..."
    curl -X POST http://localhost:9546/config \
      -F "config=@kong_backup_$(ls kong_backup_*.json | tail -1)"
fi
```

### 3.11 Script Otomatis untuk Deploy

Buat script untuk memudahkan deploy:

```bash
#!/bin/bash
# File: scripts/deploy-kong-config.sh

set -e

echo "🚀 Deploying Kong Configuration..."

# Backup current config
echo "📦 Creating backup..."
curl -s http://localhost:9546/config > kong_backup_$(date +%Y%m%d_%H%M%S).json

# Validate YML
echo "✅ Validating YML..."
python3 -c "import yaml; yaml.safe_load(open('config/kong.yml')); print('YAML syntax valid')"

# Deploy
echo "🔄 Deploying configuration..."
curl -X POST http://localhost:9546/config -F "config=@config/kong.yml"

# Verify
echo "🔍 Verifying deployment..."
curl -s http://localhost:9546/services/ | jq '.[] | .name' | wc -l | xargs -I {} echo "Services deployed: {}"

echo "✅ Deployment completed!"
```

---

## 4. Troubleshooting

### 4.1 Database Connection Issues

```bash
# Cek koneksi PostgreSQL
pg_isready -h localhost -p 5432 -U kong

# Test koneksi dari container
docker run --rm --network host postgres:15 pg_isready -h localhost -p 5432 -U kong
```

### 4.2 Port Issues

```bash
# Cek port yang digunakan
netstat -tlnp | grep -E ":(9545|9546|9547|5432)"

# Cek firewall
sudo ufw status
# atau
sudo iptables -L
```

### 4.3 Kong Service Issues

```bash
# Cek log Kong
docker-compose logs kong

# Restart Kong
docker-compose restart kong

# Rebuild Kong
docker-compose down
docker-compose up -d --build
```

### 4.4 Configuration Issues

```bash
# Cek konfigurasi Kong
curl http://localhost:9546/config

# Validasi file YML
kong config parse config/kong.yml
```

### 4.5 Common Error Messages

| Error | Penyebab | Solusi |
|-------|----------|--------|
| `database connection failed` | PostgreSQL tidak berjalan | Start PostgreSQL |
| `port already in use` | Port sudah digunakan | Cek dan stop service yang menggunakan port |
| `permission denied` | Hak akses tidak cukup | Gunakan sudo atau cek ownership file |
| `service not found` | Service tidak terdaftar | Cek konfigurasi kong.yml |

---

## 5. Referensi

### 5.1 Dokumentasi Resmi
- [Kong Documentation](https://docs.konghq.com/)
- [Kong Declarative Configuration](https://docs.konghq.com/gateway/latest/declarative-config/)
- [Kong Docker](https://docs.konghq.com/gateway/latest/install-and-run/docker/)

### 5.2 Scripts yang Tersedia
- `./scripts/start-kong-docker.sh` - Start Kong
- `./scripts/stop-kong-docker.sh` - Stop Kong
- `./scripts/test-kong-docker.sh` - Test Kong
- `./scripts/setup-server.sh` - Setup server
- `./scripts/deploy-kong-config.sh` - Deploy konfigurasi Kong
- `./scripts/rollback-kong-config.sh` - Rollback konfigurasi Kong
- `./scripts/status-kong-config.sh` - Cek status konfigurasi Kong

### 5.3 File Konfigurasi
- `docker-compose.yml` - Konfigurasi Docker
- `config/kong.yml` - Konfigurasi Kong declarative
- `config/kong.conf` - Konfigurasi Kong traditional

### 5.4 Endpoints
- Kong Proxy: `http://localhost:9545`
- Kong Admin API: `http://localhost:9546`
- Kong Admin GUI: `http://localhost:9547`

---

## 🚀 Quick Start: Setelah Mengubah File kong.yml

**TL;DR - Langkah cepat setelah mengubah file kong.yml:**

```bash
# 1. Deploy konfigurasi baru
./scripts/deploy-kong-config.sh

# 2. Cek status
./scripts/status-kong-config.sh

# 3. Test endpoint
curl http://localhost:9545/api/v1/example
```

**Langkah detail:**

1. **Pastikan Kong berjalan**: `docker-compose ps`
2. **Deploy konfigurasi**: `./scripts/deploy-kong-config.sh`
3. **Verifikasi**: `./scripts/status-kong-config.sh`
4. **Test endpoint**: Sesuai dengan route yang Anda ubah
5. **Monitor**: `docker-compose logs -f kong`

**Jika ada masalah:**
- Rollback: `./scripts/rollback-kong-config.sh`
- Restart Kong: `docker-compose restart kong`

---

## 🆘 Support

Jika mengalami masalah:
1. Cek log Kong: `docker-compose logs kong`
2. Cek database connection: `pg_isready -h localhost -p 5432`
3. Cek firewall rules: `sudo ufw status`
4. Test connectivity: `./scripts/test-kong-docker.sh`
5. Cek konfigurasi: `curl http://localhost:9546/config`
6. Cek status lengkap: `./scripts/status-kong-config.sh`

---

*Dokumen ini dibuat untuk membantu setup dan penggunaan Kong API Gateway. Update terakhir: $(date)*
