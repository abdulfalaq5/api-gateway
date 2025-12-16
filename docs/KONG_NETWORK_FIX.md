# 🔧 Fix: Kong Connection Refused Error

## ❌ Masalah

Error yang muncul:
```
connect() failed (111: Connection refused) while connecting to upstream, 
upstream: "http://127.0.0.1:9518/api/auth/sso/login"
```

**Penyebab:** Kong di Docker network `infra_net` mencoba connect ke `localhost:9518`, tapi `localhost` di dalam container merujuk ke container Kong sendiri, bukan ke service backend.

## ✅ Solusi

Ada 2 skenario, pilih sesuai setup Anda:

### Skenario 1: Service Backend Berjalan di Host (Bukan Container)

Jika service SSO dan service lainnya berjalan langsung di host server (bukan di container Docker), gunakan `host.docker.internal`:

**Untuk Linux:**
```yaml
# config/kong.yml
services:
  - name: sso-service
    url: http://host.docker.internal:9518
```

**Catatan untuk Linux:** `host.docker.internal` tidak tersedia secara default. Tambahkan di `docker-compose.yml`:

```yaml
services:
  kong:
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

**Atau gunakan IP gateway Docker network:**
```bash
# Cari IP gateway
docker network inspect infra_net | grep Gateway
# Contoh output: "Gateway": "172.18.0.1"
```

Kemudian gunakan IP tersebut:
```yaml
services:
  - name: sso-service
    url: http://172.18.0.1:9518
```

### Skenario 2: Service Backend Berjalan di Container (Network infra_net)

Jika service SSO dan service lainnya berjalan di container Docker di network `infra_net` yang sama, gunakan **nama container** atau **service name**:

```yaml
# config/kong.yml
services:
  - name: sso-service
    url: http://sso-container:9518
    # atau
    url: http://sso-service:9518  # jika menggunakan service name
```

**Cara cek nama container:**
```bash
# List semua container di network infra_net
docker network inspect infra_net | grep -A 5 "Containers"

# Atau
docker ps --filter "network=infra_net"
```

## 🔄 Langkah-langkah Perbaikan

### 1. Identifikasi Setup Anda

```bash
# Cek apakah service SSO berjalan di container atau host
docker ps | grep 9518
# Jika ada output, berarti service berjalan di container
# Jika tidak ada, berarti service berjalan di host
```

### 2. Update kong.yml

**Jika di host:**
```yaml
services:
  - name: sso-service
    url: http://host.docker.internal:9518
```

**Jika di container:**
```yaml
services:
  - name: sso-service
    url: http://<nama-container-sso>:9518
```

### 3. Update docker-compose.yml (jika perlu)

Jika menggunakan `host.docker.internal` di Linux, tambahkan:

```yaml
services:
  kong:
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

### 4. Restart Kong

```bash
docker compose -f docker-compose.server.yml restart
```

### 5. Verifikasi

```bash
# Test dari dalam container Kong
docker exec kong-gateway curl http://<target-url>:9518/health

# Test melalui Kong
curl -X POST http://localhost:9545/api/auth/sso/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test"}'
```

## 📋 Daftar Service yang Perlu Diperbaiki

Berdasarkan `kong.yml`, service berikut menggunakan `localhost` dan perlu diperbaiki:

1. `example-service` - port 3000
2. `sso-service` - port 9518 ⚠️ (yang error)
3. `power-bi-service` - port 9544
4. `interview-service` - port 9502
5. `ecatalogue-service` - port 9550
6. `epc-service` - port 9566
7. `quotation-service` - port 9565
8. `web-mis-service` - port 9509
9. `calculate-road-service` - port 9576
10. `bridge-service` - port 9575

**Semua service ini perlu diubah dari `localhost` ke URL yang sesuai!**

## 🔍 Troubleshooting

### Test Koneksi dari Container Kong

```bash
# Test ke host
docker exec kong-gateway curl http://host.docker.internal:9518/health

# Test ke container lain
docker exec kong-gateway curl http://sso-container:9518/health

# Test dengan IP gateway
docker exec kong-gateway curl http://172.18.0.1:9518/health
```

### Cek Network Configuration

```bash
# Cek container Kong di network
docker network inspect infra_net | grep -A 10 kong-gateway

# Cek semua container di network
docker network inspect infra_net | grep -A 5 "Containers"
```

### Cek DNS Resolution

```bash
# Test DNS resolution dari container Kong
docker exec kong-gateway nslookup host.docker.internal
docker exec kong-gateway nslookup sso-container
```

## 📝 Contoh Konfigurasi Lengkap

### Jika Service di Host:

```yaml
# docker-compose.server.yml
services:
  kong:
    extra_hosts:
      - "host.docker.internal:host-gateway"
    networks:
      - infra_net
```

```yaml
# config/kong.yml
services:
  - name: sso-service
    url: http://host.docker.internal:9518
```

### Jika Service di Container:

```yaml
# config/kong.yml
services:
  - name: sso-service
    url: http://sso-service-container:9518
    # atau jika menggunakan service name dari docker-compose
    url: http://sso-service:9518
```

