# 🔄 Panduan Update Routes di Kong API Gateway

Dokumentasi lengkap untuk menambahkan atau mengupdate routes di Kong API Gateway.

## 📋 Prasyarat

1. **Akses ke server** (SSH)
2. **File `config/kong.yml`** sudah ada di server
3. **Kong Gateway sudah berjalan**

## 🚀 Cara Update Routes

### Metode 1: Menggunakan Script Deploy (Recommended)

Script `deploy-kong-routes.sh` memudahkan proses deploy dari lokal ke server.

#### 1. Edit kong.yml di Lokal

```bash
# Edit file config/kong.yml
vim config/kong.yml
# atau
nano config/kong.yml
```

#### 2. Validasi Lokal (Optional)

```bash
# Validasi syntax YAML
./scripts/deploy-kong-routes.sh validate
```

#### 3. Deploy ke Server

```bash
# Deploy perubahan
./scripts/deploy-kong-routes.sh deploy
```

Script ini akan:
- ✅ Validasi YAML syntax
- ✅ Backup file remote
- ✅ Copy file ke server
- ✅ Validasi di server
- ✅ Reload Kong configuration
- ✅ Verifikasi Kong health
- ✅ Tampilkan routes yang ada

### Metode 2: Manual Update di Server

Jika ingin update langsung di server:

#### 1. SSH ke Server

```bash
ssh user@your-server-ip
cd /home/msiserver/MSI/api-gateway
```

#### 2. Backup File Sebelumnya

```bash
# Backup kong.yml
cp config/kong.yml config/kong.yml.backup.$(date +%Y%m%d_%H%M%S)
```

#### 3. Edit kong.yml

```bash
vim config/kong.yml
# atau
nano config/kong.yml
```

#### 4. Validasi YAML Syntax

```bash
# Validasi dengan Python
python3 -c "import yaml; yaml.safe_load(open('config/kong.yml'))"
```

#### 5. Reload Kong Configuration

**Opsi A: Hot Reload (Recommended - Tidak perlu restart)**

```bash
# Hot reload configuration
curl -X POST http://localhost:9546/config -F config=@config/kong.yml
```

**Opsi B: Restart Container**

```bash
# Restart container
docker compose -f docker-compose.server.yml restart kong
```

#### 6. Verifikasi

```bash
# Cek Kong health
curl http://localhost:9546/status

# Cek routes
curl http://localhost:9546/routes | jq '.data | length'

# Cek routes detail
curl http://localhost:9546/routes | jq -r '.data[] | "\(.name) - \(.paths[])"'
```

## 📝 Contoh Menambahkan Route Baru

### Struktur Route di kong.yml

```yaml
services:
  - name: my-new-service
    url: http://localhost:8080/api
    routes:
      - name: my-new-route
        paths:
          - /api/my-new-endpoint
        methods:
          - GET
          - POST
        strip_path: false
```

### Langkah-langkah

1. **Buka `config/kong.yml`**

2. **Tambahkan service dan route** di bagian `services:`

3. **Validasi syntax**

4. **Deploy** menggunakan script atau manual

5. **Test route baru**

```bash
# Test route
curl http://localhost:9545/api/my-new-endpoint
```

## 🔍 Verifikasi Setelah Update

### 1. Cek Kong Status

```bash
curl http://localhost:9546/status | jq
```

### 2. Cek Routes

```bash
# Total routes
curl http://localhost:9546/routes | jq '.data | length'

# List semua routes
curl http://localhost:9546/routes | jq -r '.data[] | .name'

# Detail route tertentu
curl http://localhost:9546/routes/my-route-name | jq
```

### 3. Cek Services

```bash
# Total services
curl http://localhost:9546/services | jq '.data | length'

# List semua services
curl http://localhost:9546/services | jq -r '.data[] | .name'
```

### 4. Test Route

```bash
# Test dengan curl
curl -v http://localhost:9545/api/your-endpoint

# Test dengan method tertentu
curl -X POST http://localhost:9545/api/your-endpoint \
  -H "Content-Type: application/json" \
  -d '{"key": "value"}'
```

## 🐛 Troubleshooting

### Route tidak muncul setelah update

```bash
# Cek logs Kong
docker logs kong-gateway --tail 100

# Cek apakah config berhasil di-load
docker exec kong-gateway cat /kong/kong.yml | grep -A 10 "your-route-name"

# Cek Kong error logs
docker logs kong-gateway 2>&1 | grep -i error
```

### YAML syntax error

```bash
# Validasi YAML
python3 -c "import yaml; yaml.safe_load(open('config/kong.yml'))"

# Cek indentasi (harus 2 spaces, bukan tab)
cat -A config/kong.yml | grep -n "^\t"
```

### Hot reload tidak bekerja

```bash
# Cek apakah Kong support hot reload
curl http://localhost:9546/status | jq '.configuration.db'

# Jika tidak support, restart container
docker compose -f docker-compose.server.yml restart kong
```

### Route tidak bisa diakses

```bash
# Cek apakah route terdaftar
curl http://localhost:9546/routes | jq '.data[] | select(.name=="your-route-name")'

# Cek service yang terkait
curl http://localhost:9546/routes/your-route-name | jq '.service'

# Test connectivity ke backend
docker exec kong-gateway curl -v http://your-backend-url
```

## 📊 Monitoring Routes

### Cek Routes dengan Script

```bash
# Menggunakan script deploy-kong-routes.sh
./scripts/deploy-kong-routes.sh status

# Atau test route tertentu
./scripts/deploy-kong-routes.sh test /api/your-endpoint
```

### Cek Diff Sebelum Deploy

```bash
# Lihat perbedaan local vs remote
./scripts/deploy-kong-routes.sh diff
```

## 🔄 Workflow Update Routes

### Workflow Recommended

1. **Edit lokal** → Edit `config/kong.yml` di komputer lokal
2. **Validasi** → `./scripts/deploy-kong-routes.sh validate`
3. **Cek diff** → `./scripts/deploy-kong-routes.sh diff` (optional)
4. **Deploy** → `./scripts/deploy-kong-routes.sh deploy`
5. **Verifikasi** → `./scripts/deploy-kong-routes.sh status`
6. **Test** → Test route yang baru ditambahkan

### Workflow Manual

1. **SSH ke server**
2. **Backup** → Backup `config/kong.yml`
3. **Edit** → Edit `config/kong.yml`
4. **Validasi** → Validasi YAML syntax
5. **Reload** → Hot reload atau restart
6. **Verifikasi** → Cek routes dan test

## 📝 Best Practices

1. **Selalu backup** sebelum update
2. **Validasi YAML** sebelum deploy
3. **Test di development** sebelum production
4. **Gunakan hot reload** jika memungkinkan (lebih cepat)
5. **Monitor logs** setelah update
6. **Test routes** setelah update
7. **Dokumentasikan perubahan** yang signifikan

## ⚠️ Catatan Penting

- Kong menggunakan **DB-less mode**, semua config ada di `kong.yml`
- Perubahan di `kong.yml` perlu **reload** untuk aktif
- **Hot reload** lebih cepat daripada restart container
- Pastikan **YAML syntax benar** (2 spaces indent, bukan tab)
- **Backup selalu** sebelum melakukan perubahan besar

## 🔗 Referensi

- [Kong Declarative Configuration](https://docs.konghq.com/gateway/latest/production/deployment-topologies/db-less-and-declarative-config/)
- [Kong Routes Documentation](https://docs.konghq.com/gateway/latest/admin-api/routes/reference/)
- [Kong Services Documentation](https://docs.konghq.com/gateway/latest/admin-api/services/reference/)

---

**Selamat! Routes berhasil diupdate! 🎉**

