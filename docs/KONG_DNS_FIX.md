# 🔧 Fix: Kong DNS Resolution untuk Container Names

## ❌ Masalah

Error yang muncul:
```
DNS resolution failed: dns server error: 3 name error. 
Tried: ["(short)api-gate-sso:(na) - cache-miss"]
```

**Penyebab:** Kong menggunakan DNS resolver eksternal (8.8.8.8) yang tidak bisa resolve nama container Docker. Docker network memiliki DNS internal sendiri yang bisa resolve nama container.

## ✅ Solusi

### 1. Update DNS Configuration

Kong perlu menggunakan Docker internal DNS (`127.0.0.11`) untuk resolve container names, dengan fallback ke DNS eksternal untuk internet access.

**File yang diupdate:**
- `config/resolv.conf` - Tambahkan Docker internal DNS
- `docker-compose.yml` - Update `KONG_DNS_RESOLVER`

### 2. Verifikasi Container di Network

Pastikan container `api-gate-sso` ada di network `infra_net` yang sama dengan Kong:

```bash
# Cek container di network
docker network inspect infra_net | grep -A 10 "Containers"

# Atau cek container secara langsung
docker inspect api-gate-sso | grep -A 5 "Networks"
```

### 3. Alternatif: Gunakan IP Address Langsung

Jika DNS masih bermasalah, gunakan IP address container secara langsung:

```bash
# Dapatkan IP address container
docker inspect api-gate-sso | grep -A 5 "Networks" | grep "IPAddress"

# Atau
docker network inspect infra_net | grep -A 10 api-gate-sso | grep "IPv4Address"
```

Kemudian update `kong.yml`:
```yaml
- name: sso-service
  url: http://172.18.0.X:9601  # Ganti dengan IP yang didapat
```

## 🔄 Langkah-langkah Perbaikan

### Step 1: Update resolv.conf

File `config/resolv.conf` sudah diupdate dengan:
```
nameserver 127.0.0.11  # Docker internal DNS
nameserver 8.8.8.8     # Fallback
nameserver 8.8.4.4     # Fallback
```

### Step 2: Update docker-compose.yml

File `docker-compose.yml` sudah diupdate dengan:
```yaml
KONG_DNS_RESOLVER: "127.0.0.11:53,8.8.8.8:53,8.8.4.4:53"
```

### Step 3: Restart Kong

```bash
docker compose -f docker-compose.server.yml restart
```

### Step 4: Verifikasi DNS Resolution

```bash
# Test DNS resolution dari container Kong
docker exec kong-gateway nslookup api-gate-sso

# Test koneksi
docker exec kong-gateway curl http://api-gate-sso:9601/health
```

### Step 5: Test melalui Kong

```bash
curl -X POST http://localhost:9545/api/auth/sso/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test"}'
```

## 🔍 Troubleshooting

### DNS Masih Tidak Bisa Resolve

1. **Cek container ada di network yang sama:**
   ```bash
   docker network inspect infra_net | grep api-gate-sso
   ```

2. **Jika container tidak ada di network, tambahkan:**
   ```bash
   docker network connect infra_net api-gate-sso
   ```

3. **Cek resolv.conf sudah ter-mount:**
   ```bash
   docker exec kong-gateway cat /etc/resolv.conf
   ```

4. **Test DNS resolution manual:**
   ```bash
   docker exec kong-gateway nslookup api-gate-sso 127.0.0.11
   ```

### Gunakan IP Address Langsung (Workaround)

Jika DNS masih bermasalah, gunakan IP address:

```bash
# Dapatkan IP
CONTAINER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' api-gate-sso)
echo $CONTAINER_IP

# Update kong.yml dengan IP tersebut
```

## 📝 Catatan Penting

- **Docker Internal DNS (`127.0.0.11`)** hanya bisa resolve container yang ada di network yang sama
- **Pastikan semua container di network `infra_net`** agar bisa saling resolve
- **DNS order penting:** Docker DNS harus di urutan pertama untuk container names, DNS eksternal untuk internet

## 🔗 Referensi

- [Docker Embedded DNS](https://docs.docker.com/config/containers/container-networking/#dns-services)
- [Kong DNS Configuration](https://docs.konghq.com/gateway/latest/reference/configuration/#dns_resolver)

