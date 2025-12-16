# 🚀 Setup Kong API Gateway dengan Nginx dan Cloudflare Tunnel

Dokumentasi lengkap untuk setup Kong API Gateway menggunakan Nginx sebagai reverse proxy dan Cloudflare Tunnel untuk akses dari internet.

## 📋 Arsitektur

```
Internet → Cloudflare Tunnel → Nginx (port 80) → Kong Gateway (port 9545/9546/9547)
```

## 🔧 Prasyarat

1. **Docker dan Docker Compose terinstall**
2. **Network Docker `infra_net` sudah dibuat**
   ```bash
   docker network ls | grep infra_net
   ```
   
   Jika belum ada, buat network:
   ```bash
   docker network create infra_net
   ```

3. **Cloudflare Tunnel sudah dikonfigurasi** (cloudflared)
4. **Domain sudah dikonfigurasi di Cloudflare DNS**

## 📁 Struktur File

```
kong-api-gateway/
├── docker-compose.server.yml    # Kong Gateway
└── config/
    └── nginx/
        └── kong.conf            # Konfigurasi Nginx untuk Kong
```

**Catatan:** Nginx sudah di-setup di repository terpisah dan sudah terhubung ke network `infra_net`. File `kong.conf` ini perlu ditambahkan ke konfigurasi Nginx yang sudah ada.

## 🚀 Langkah-langkah Setup

### 1. Setup Kong Gateway

```bash
# Pastikan network infra_net sudah ada
docker network create infra_net

# Jalankan Kong Gateway
docker compose -f docker-compose.server.yml up -d

# Verifikasi Kong berjalan
docker ps | grep kong-gateway
curl http://localhost:9546/status
```

### 2. Integrasikan Konfigurasi Nginx ke Nginx yang Sudah Ada

Karena Nginx sudah di-setup di repository terpisah, Anda perlu:

1. **Copy file `kong.conf` ke repository Nginx:**
   ```bash
   # Dari repo kong-api-gateway
   cp config/nginx/kong.conf /path/to/nginx-repo/config/kong.conf
   ```

2. **Mount file konfigurasi di docker-compose Nginx (di repo Nginx):**
   ```yaml
   volumes:
     - ./config/kong.conf:/etc/nginx/conf.d/kong.conf:ro
   ```

3. **Atau tambahkan include di konfigurasi Nginx utama:**
   ```nginx
   # Di nginx.conf atau default.conf
   include /etc/nginx/conf.d/kong.conf;
   ```

4. **Reload Nginx:**
   ```bash
   # Test konfigurasi terlebih dahulu
   docker exec <nginx-container-name> nginx -t
   
   # Reload Nginx
   docker exec <nginx-container-name> nginx -s reload
   ```

5. **Verifikasi:**
   ```bash
   # Cek Nginx bisa connect ke Kong
   docker exec <nginx-container-name> curl http://kong-gateway:9545/status
   ```

### 3. Konfigurasi Cloudflare Tunnel

Update file konfigurasi Cloudflare Tunnel (`config.yml` untuk cloudflared) untuk mengarahkan ke Nginx yang sudah ada:

```yaml
tunnel: your-tunnel-id
credentials-file: /path/to/credentials.json

ingress:
  # Kong Proxy API
  - hostname: gateway.motorsights.com
    service: http://<nginx-container-name>:80
  
  # Kong Admin API
  - hostname: kong-admin.motorsights.com
    service: http://<nginx-container-name>:80
  
  # Kong Admin GUI
  - hostname: kong-admin-gui.motorsights.com
    service: http://<nginx-container-name>:80
  
  # Catch-all rule (harus di akhir)
  - service: http_status:404
```

**Catatan:** 
- Ganti `<nginx-container-name>` dengan nama container Nginx yang sebenarnya
- Pastikan Cloudflare Tunnel container juga terhubung ke network `infra_net`

### 4. Verifikasi Setup

```bash
# Test dari dalam network Docker (dari container Nginx)
docker exec <nginx-container-name> curl http://kong-gateway:9545/status

# Test Nginx reverse proxy (dari host)
curl -H "Host: gateway.motorsights.com" http://localhost/api/your-endpoint

# Test Kong Admin melalui Nginx
curl -H "Host: kong-admin.motorsights.com" http://localhost/status
```

## 🔍 Troubleshooting

### Nginx tidak bisa connect ke Kong

```bash
# Pastikan Kong dan Nginx di network yang sama
docker network inspect infra_net

# Test connectivity dari Nginx ke Kong
docker exec <nginx-container-name> ping kong-gateway

# Cek logs Nginx
docker logs <nginx-container-name>

# Test koneksi HTTP
docker exec <nginx-container-name> curl http://kong-gateway:9545/status
```

### Cloudflare Tunnel tidak bisa connect ke Nginx

```bash
# Pastikan Cloudflare Tunnel container di network infra_net
docker network inspect infra_net | grep cloudflared

# Pastikan Nginx container juga di network infra_net
docker network inspect infra_net | grep <nginx-container-name>

# Test dari Cloudflare Tunnel container
docker exec <cloudflared-container> curl http://<nginx-container-name>:80
```

### Kong Gateway tidak berjalan

```bash
# Cek logs Kong
docker logs kong-gateway

# Cek status Kong
curl http://localhost:9546/status

# Restart Kong
docker compose -f docker-compose.server.yml restart
```

### Konfigurasi Nginx tidak ter-load

```bash
# Pastikan file kong.conf sudah di-mount dengan benar
docker exec <nginx-container-name> ls -la /etc/nginx/conf.d/kong.conf

# Test konfigurasi Nginx
docker exec <nginx-container-name> nginx -t

# Cek apakah konfigurasi sudah di-include
docker exec <nginx-container-name> cat /etc/nginx/nginx.conf | grep kong.conf
```

## 📝 Konfigurasi Domain di Cloudflare

1. Login ke Cloudflare Dashboard
2. Pilih domain `motorsights.com`
3. Tambahkan DNS records (A atau CNAME) yang mengarah ke Cloudflare Tunnel
4. Pastikan proxy status aktif (orange cloud)

## 🔐 Keamanan

### Rekomendasi:

1. **Kong Admin API dan GUI** sebaiknya tidak di-expose ke internet
   - Gunakan VPN atau IP whitelist di Cloudflare Tunnel
   - Atau gunakan Cloudflare Access untuk proteksi

2. **Rate Limiting** sudah dikonfigurasi di Kong (lihat `kong.yml`)

3. **CORS** sudah dikonfigurasi di Kong untuk mengizinkan request dari frontend

## 📊 Monitoring

### Logs Nginx

```bash
# Access logs (sesuaikan path sesuai konfigurasi Nginx yang sudah ada)
docker exec <nginx-container-name> tail -f /var/log/nginx/kong-proxy-access.log
docker exec <nginx-container-name> tail -f /var/log/nginx/kong-admin-access.log
docker exec <nginx-container-name> tail -f /var/log/nginx/kong-admin-gui-access.log

# Error logs
docker exec <nginx-container-name> tail -f /var/log/nginx/kong-proxy-error.log
docker exec <nginx-container-name> tail -f /var/log/nginx/kong-admin-error.log
docker exec <nginx-container-name> tail -f /var/log/nginx/kong-admin-gui-error.log

# Atau jika logs di-mount ke host
tail -f /path/to/nginx/logs/kong-proxy-access.log
```

### Logs Kong

```bash
# Kong logs
docker logs kong-gateway --tail 100 -f
```

## 🔄 Update Konfigurasi

### Update Kong Config

```bash
# Edit config/kong.yml
# Restart Kong
docker compose -f docker-compose.server.yml restart
```

### Update Nginx Config

```bash
# Edit config/nginx/kong.conf di repo ini
# Copy ke repo Nginx atau update langsung di repo Nginx

# Test konfigurasi terlebih dahulu
docker exec <nginx-container-name> nginx -t

# Reload Nginx (tanpa restart)
docker exec <nginx-container-name> nginx -s reload
```

## 📚 Referensi

- [Kong Documentation](https://docs.konghq.com/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)

