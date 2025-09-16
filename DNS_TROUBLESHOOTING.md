# Troubleshooting DNS Resolution Kong Gateway

## Masalah DNS Resolution `host.docker.internal`

### Gejala Masalah
```
kong-gateway | 2025/09/16 01:38:32 [error] 1260#0: *1855 [lua] init.lua:371: execute(): DNS resolution failed: dns server error: 3 name error. Tried: ["(short)host.docker.internal:(na) - cache-miss","host.docker.internal:33 - cache-miss/scheduled/querying/dns server error: 3 name error","host.docker.internal:1 - cache-miss/scheduled/querying/dns server error: 3 name error","host.docker.internal:5 - cache-miss/scheduled/querying/dns server error: 3 name error"], client: 172.24.0.1, server: kong, request: "POST /api/auth/sso/login HTTP/1.1", host: "services.motorsights.com"
```

### Penyebab Masalah
1. **Missing `extra_hosts` configuration** di Docker Compose
2. **DNS server tidak bisa resolve `host.docker.internal`**
3. **Service Kong dikonfigurasi menggunakan `host.docker.internal`** tetapi tidak bisa diakses
4. **Network configuration Docker tidak tepat**

### Solusi

#### Solusi 1: Tambahkan `extra_hosts` Configuration
```yaml
services:
  kong:
    image: kong:3.4
    container_name: kong-gateway
    # ... konfigurasi lainnya
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

#### Solusi 2: Tambahkan DNS Server Eksplisit
```yaml
services:
  kong:
    image: kong:3.4
    container_name: kong-gateway
    # ... konfigurasi lainnya
    extra_hosts:
      - "host.docker.internal:host-gateway"
    dns:
      - 8.8.8.8
      - 8.8.4.4
```

#### Solusi 3: Gunakan Network Mode Host
```yaml
services:
  kong:
    image: kong:3.4
    container_name: kong-gateway
    # ... konfigurasi lainnya
    network_mode: host
```

#### Solusi 4: Gunakan IP Address Langsung
Ganti `host.docker.internal` dengan IP address host yang spesifik:
```yaml
services:
  kong:
    image: kong:3.4
    container_name: kong-gateway
    # ... konfigurasi lainnya
    extra_hosts:
      - "host.docker.internal:192.168.1.100"  # Ganti dengan IP host yang sesuai
```

### Script Otomatis

#### Script 1: Fix DNS Resolution
```bash
./scripts/fix-dns-resolution.sh
```

#### Script 2: Fix DNS dengan Solusi Alternatif
```bash
./scripts/fix-kong-dns-alternative.sh
```

### Langkah Manual

#### 1. Cek Status Kong
```bash
docker ps | grep kong
docker logs kong-gateway
```

#### 2. Test DNS Resolution
```bash
# Test dari dalam container Kong
docker exec kong-gateway nslookup host.docker.internal

# Test dari host
nslookup host.docker.internal
```

#### 3. Cek Konfigurasi Kong
```bash
# Cek services yang menggunakan host.docker.internal
curl -s http://localhost:9546/services | jq '.data[] | select(.url | contains("host.docker.internal"))'

# Cek routes
curl -s http://localhost:9546/routes | jq '.data[] | select(.service.url | contains("host.docker.internal"))'
```

#### 4. Restart Kong
```bash
# Stop Kong
docker-compose -f docker-compose.server.yml down

# Start Kong
docker-compose -f docker-compose.server.yml up -d

# Tunggu Kong start
sleep 15

# Test Kong health
curl http://localhost:9546/status
```

### Troubleshooting Lanjutan

#### 1. Cek Docker Network
```bash
# List Docker networks
docker network ls

# Inspect network
docker network inspect bridge
```

#### 2. Cek DNS Configuration
```bash
# Cek resolv.conf di container
docker exec kong-gateway cat /etc/resolv.conf

# Test DNS resolution
docker exec kong-gateway ping -c 3 8.8.8.8
```

#### 3. Cek Firewall
```bash
# Cek port yang digunakan
netstat -tlnp | grep -E "(9545|9546|9547)"

# Cek firewall rules
sudo ufw status
```

### Pencegahan

#### 1. Gunakan Konfigurasi yang Konsisten
- Pastikan semua environment menggunakan konfigurasi yang sama
- Gunakan environment variables untuk host configuration

#### 2. Test Konfigurasi Sebelum Deploy
```bash
# Test Docker Compose configuration
docker-compose -f docker-compose.server.yml config

# Test Kong configuration
kong config -c config/kong.conf
```

#### 3. Monitoring DNS Resolution
- Setup monitoring untuk DNS resolution
- Log DNS errors untuk analisis lebih lanjut

### Referensi
- [Docker Compose extra_hosts](https://docs.docker.com/compose/compose-file/compose-file-v3/#extra_hosts)
- [Kong DNS Resolution](https://docs.konghq.com/gateway/latest/configuration/#dns_resolver)
- [Docker Networking](https://docs.docker.com/network/)
