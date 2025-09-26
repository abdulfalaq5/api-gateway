# Kong DB-less Mode Troubleshooting

## Masalah yang Ditemukan

Ketika menjalankan `./scripts/switch-to-dbless.sh` di server, muncul error:

```
jq: error (at backups/kong_current_config.json:0): Cannot iterate over null (null)
jq: error (at backups/kong_current_config.json:0): Cannot iterate over null (null)
```

## Penyebab Masalah

1. **Kong dalam database mode** - Script mencoba mengakses `/config` endpoint yang hanya tersedia di DB-less mode
2. **File kong.yml kosong** - Konversi JSON ke YAML gagal karena data null
3. **Kong masih menggunakan database** - Meskipun docker-compose.yml sudah diupdate, Kong masih membaca dari database

## Solusi

### 1. Gunakan Script Perbaikan

```bash
# Jalankan script perbaikan
./scripts/fix-server-dbless.sh
```

Script ini akan:
- ✅ Backup konfigurasi saat ini dari database
- ✅ Convert services, routes, dan plugins ke kong.yml
- ✅ Restart Kong dengan konfigurasi yang benar
- ✅ Test endpoints untuk memastikan semuanya bekerja

### 2. Manual Fix (Alternatif)

Jika script tidak bekerja, lakukan manual:

```bash
# 1. Export konfigurasi dari database
curl -s http://localhost:9546/services > backups/services.json
curl -s http://localhost:9546/routes > backups/routes.json
curl -s http://localhost:9546/plugins > backups/plugins.json

# 2. Buat kong.yml manual
vim config/kong.yml

# 3. Restart Kong
docker-compose restart kong

# 4. Test endpoints
curl http://localhost:9545/api/auth/sso/login
```

### 3. Verifikasi Konfigurasi

```bash
# Cek kong.yml
cat config/kong.yml

# Cek Kong status
curl http://localhost:9546/

# Test SSO endpoint
curl -X POST http://localhost:9545/api/auth/sso/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@sso-testing.com","password":"admin123","client_id":"string","redirect_uri":"string"}'
```

## Struktur kong.yml yang Benar

```yaml
_format_version: "3.0"
_transform: true

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
    plugins:
      - name: rate-limiting
        config:
          minute: 100
          hour: 1000
          policy: local

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

## Troubleshooting Commands

```bash
# Cek Kong logs
docker-compose logs -f kong

# Cek Kong status
curl http://localhost:9546/

# Cek services
curl http://localhost:9546/services | jq .

# Cek routes
curl http://localhost:9546/routes | jq .

# Cek plugins
curl http://localhost:9546/plugins | jq .

# Test SSO endpoint
curl -v -X POST http://localhost:9545/api/auth/sso/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@sso-testing.com","password":"admin123","client_id":"string","redirect_uri":"string"}'
```

## Workflow DB-less Mode

```bash
# 1. Edit konfigurasi
vim config/kong.yml

# 2. Restart Kong
docker-compose restart kong

# 3. Test endpoints
curl http://localhost:9545/api/your-endpoint

# 4. Monitor logs
docker-compose logs -f kong
```

## Keuntungan DB-less Mode

- ✅ **No database cache issues** - Kong reload dari file
- ✅ **Version control friendly** - File bisa di-track di Git
- ✅ **Easy rollback** - Tinggal ganti file dan restart
- ✅ **Atomic updates** - Semua perubahan diterapkan sekaligus
- ✅ **No database dependency** - Tidak perlu PostgreSQL

## Rollback ke Database Mode

Jika perlu rollback:

```bash
# Restore docker-compose.yml
cp docker-compose.yml.backup docker-compose.yml

# Restart Kong
docker-compose up -d
```
