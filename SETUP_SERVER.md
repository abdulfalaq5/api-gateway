# 🚀 Panduan Setup Kong API Gateway di Server Baru

Dokumentasi lengkap untuk setup Kong API Gateway menggunakan `docker-compose.server.yml` di server baru.

> **Catatan:** Dokumentasi ini disesuaikan untuk Docker 29.1.2 yang menggunakan Compose V2. Gunakan `docker compose` (dengan spasi) bukan `docker-compose` (dengan dash).

## 📋 Prasyarat

1. **Server dengan Docker terinstall (versi 20.10+ dengan Compose V2)**
   ```bash
   docker --version
   docker compose version
   ```
   
   **Catatan:** Docker 29.1.2 sudah include Compose V2, gunakan `docker compose` (dengan spasi), bukan `docker-compose`.

2. **Network Traefik sudah dibuat** (jika menggunakan Traefik)
   ```bash
   docker network ls | grep traefik-network
   ```
   
   Jika belum ada, buat network:
   ```bash
   docker network create traefik-network
   ```

3. **Akses SSH ke server**

## 🔧 Langkah-langkah Setup

### 1. Persiapan Direktori

```bash
# Login ke server
ssh user@your-server-ip

# Buat direktori project
mkdir -p /home/msiserver/MSI/api-gateway
cd /home/msiserver/MSI/api-gateway
```

### 2. Upload File ke Server

Dari komputer lokal, upload file yang diperlukan:

```bash
# Upload docker-compose.server.yml
scp docker-compose.server.yml user@your-server-ip:/home/msiserver/MSI/api-gateway/

# Upload config/kong.yml
scp config/kong.yml user@your-server-ip:/home/msiserver/MSI/api-gateway/config/

# Upload config/resolv.conf (jika ada)
scp config/resolv.conf user@your-server-ip:/home/msiserver/MSI/api-gateway/config/
```

**Atau menggunakan Git:**

```bash
# Di server
cd /home/msiserver/MSI/api-gateway
git clone <repository-url> .
# atau
git pull origin main
```

### 3. Struktur Direktori

Pastikan struktur direktori di server seperti ini:

```
/home/msiserver/MSI/api-gateway/
├── docker-compose.server.yml
└── config/
    ├── kong.yml
    └── resolv.conf
```

### 4. Verifikasi Network Traefik

Pastikan network `traefik-network` sudah ada:

```bash
docker network inspect traefik-network
```

Jika belum ada, buat network:

```bash
docker network create traefik-network
```

### 5. Jalankan Kong Gateway

```bash
cd /home/msiserver/MSI/api-gateway

# Pull image Kong (jika belum ada)
docker pull kong:3.4

# Start Kong Gateway
docker compose -f docker-compose.server.yml up -d

# Cek status container
docker ps | grep kong-gateway
```

### 6. Verifikasi Kong Berjalan

```bash
# Cek health status
curl http://localhost:9546/status

# Cek routes
curl http://localhost:9546/routes | jq

# Cek services
curl http://localhost:9546/services | jq

# Cek logs
docker logs kong-gateway --tail 50
```

### 7. Test Kong Gateway

```bash
# Test admin API
curl http://localhost:9546/

# Test proxy (sesuai route di kong.yml)
curl http://localhost:9545/api/your-endpoint
```

## 🔍 Troubleshooting

### Container tidak start

```bash
# Cek logs
docker logs kong-gateway

# Cek apakah port sudah digunakan
netstat -tulpn | grep 9545
netstat -tulpn | grep 9546
netstat -tulpn | grep 9547
```

### Network tidak ditemukan

```bash
# Cek network
docker network ls

# Buat network jika belum ada
docker network create traefik-network
```

### Kong tidak bisa connect ke backend

```bash
# Test DNS resolution dari dalam container
docker exec kong-gateway nslookup your-backend-domain.com

# Test connectivity
docker exec kong-gateway curl -v https://your-backend-domain.com
```

### File kong.yml tidak ditemukan

```bash
# Pastikan file ada
ls -la config/kong.yml

# Cek mount volume
docker inspect kong-gateway | jq '.[0].Mounts'
```

## 📝 Konfigurasi Penting

### Port yang Digunakan

- **9545**: Kong Proxy (untuk request dari client)
- **9546**: Kong Admin API (untuk management)
- **9547**: Kong Admin GUI (jika digunakan)

### Network

Kong Gateway menggunakan network `traefik-network` (external) agar bisa berkomunikasi dengan container lain di network yang sama.

### Mode Operasi

Kong menggunakan **DB-less mode** (declarative config), semua konfigurasi ada di `config/kong.yml`.

## 🔄 Update Kong

Untuk update Kong ke versi baru:

```bash
# Stop container
docker compose -f docker-compose.server.yml down

# Edit docker-compose.server.yml, ubah image version
# image: kong:3.4  -> image: kong:3.5

# Pull image baru
docker pull kong:3.5

# Start lagi
docker compose -f docker-compose.server.yml up -d
```

## 📚 Referensi

- [Kong Documentation](https://docs.konghq.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

## ✅ Checklist Setup

- [ ] Docker terinstall (versi 20.10+ dengan Compose V2)
- [ ] Network `traefik-network` sudah dibuat
- [ ] File `docker-compose.server.yml` sudah diupload
- [ ] File `config/kong.yml` sudah diupload
- [ ] File `config/resolv.conf` sudah diupload (jika ada)
- [ ] Container Kong berjalan (`docker ps`)
- [ ] Kong health check berhasil (`curl http://localhost:9546/status`)
- [ ] Routes bisa diakses sesuai konfigurasi

---

**Selamat! Kong API Gateway sudah siap digunakan! 🎉**

