# 🔧 Fix Network URLs - Kong API Gateway

## ✅ Perbaikan yang Sudah Dilakukan

Service SSO sudah diperbaiki:
- **Sebelum:** `url: http://localhost:9518`
- **Sesudah:** `url: http://api-gate-sso:9518`

## ⚠️ Service Lain yang Perlu Diperbaiki

Service berikut masih menggunakan `localhost` dan perlu diperbaiki sesuai dengan nama container atau hostname yang benar:

1. `example-service` - port 3000
2. `power-bi-service` - port 9544
3. `interview-service` - port 9502
4. `ecatalogue-service` - port 9550
5. `epc-service` - port 9566
6. `quotation-service` - port 9565
7. `web-mis-service` - port 9509
8. `calculate-road-service` - port 9576
9. `bridge-service` - port 9575

## 🔍 Cara Mencari Nama Container

```bash
# List semua container di network infra_net
docker network inspect infra_net | grep -A 10 "Containers"

# Atau list semua container yang berjalan
docker ps

# Cek container berdasarkan port
docker ps | grep 9544  # untuk power-bi-service
docker ps | grep 9502  # untuk interview-service
# dst...
```

## 📝 Format Perbaikan

### Jika Service Berjalan di Container (di network infra_net):

```yaml
# Sebelum
url: http://localhost:PORT

# Sesudah (gunakan nama container)
url: http://nama-container:PORT
```

**Contoh:**
```yaml
- name: power-bi-service
  url: http://power-bi-container:9544
```

### Jika Service Berjalan di Host (bukan container):

```yaml
# Sebelum
url: http://localhost:PORT

# Sesudah (gunakan host.docker.internal)
url: http://host.docker.internal:PORT
```

**Dan tambahkan di docker-compose.yml:**
```yaml
services:
  kong:
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

## 🚀 Langkah Setelah Update

1. **Update kong.yml** dengan URL yang benar
2. **Restart Kong:**
   ```bash
   docker compose -f docker-compose.server.yml restart
   ```
3. **Verifikasi:**
   ```bash
   # Test dari container Kong
   docker exec kong-gateway curl http://api-gate-sso:9518/health
   
   # Test melalui Kong API Gateway
   curl -X POST http://localhost:9545/api/auth/sso/login \
     -H "Content-Type: application/json" \
     -d '{"username":"test","password":"test"}'
   ```

## 📚 Dokumentasi Lengkap

Lihat `docs/KONG_NETWORK_FIX.md` untuk dokumentasi lengkap tentang troubleshooting network issues.

