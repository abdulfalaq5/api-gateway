# 🔄 Migrasi dari Traefik ke Nginx + Cloudflare Tunnel

Dokumentasi ini menjelaskan perubahan konfigurasi Kong API Gateway dari Traefik ke Nginx dan Cloudflare Tunnel.

## 📋 Perubahan Utama

### 1. Network Docker
- **Sebelum:** `traefik-network`
- **Sekarang:** `infra_net`

### 2. Reverse Proxy
- **Sebelum:** Traefik (dengan labels Docker)
- **Sekarang:** Nginx (standalone reverse proxy)

### 3. Internet Access
- **Sebelum:** Traefik → Cloudflare Tunnel
- **Sekarang:** Nginx → Cloudflare Tunnel

## 🚀 Quick Start

### 1. Pastikan Network `infra_net` Ada

```bash
docker network create infra_net
```

### 2. Jalankan Kong Gateway

```bash
docker compose -f docker-compose.server.yml up -d
```

### 3. Integrasikan Konfigurasi Nginx

Karena Nginx sudah ada di repository terpisah:

1. **Copy konfigurasi `kong.conf` ke repository Nginx:**
   ```bash
   cp config/nginx/kong.conf /path/to/nginx-repo/config/kong.conf
   ```

2. **Mount file di docker-compose Nginx (di repo Nginx) atau include di nginx.conf**

3. **Reload Nginx:**
   ```bash
   docker exec <nginx-container-name> nginx -t
   docker exec <nginx-container-name> nginx -s reload
   ```

### 4. Konfigurasi Cloudflare Tunnel

Update konfigurasi Cloudflare Tunnel untuk mengarahkan ke Nginx yang sudah ada:

```yaml
ingress:
  - hostname: gateway.motorsights.com
    service: http://<nginx-container-name>:80
  - hostname: kong-admin.motorsights.com
    service: http://<nginx-container-name>:80
  - hostname: kong-admin-gui.motorsights.com
    service: http://<nginx-container-name>:80
```

**Ganti `<nginx-container-name>` dengan nama container Nginx yang sebenarnya!**

## 📁 File Baru

- `config/nginx/kong.conf` - Konfigurasi Nginx untuk Kong (untuk diintegrasikan ke Nginx yang sudah ada)
- `docs/NGINX_CLOUDFLARE_SETUP.md` - Dokumentasi lengkap

## 🔍 Verifikasi

```bash
# Cek Kong berjalan
docker ps | grep kong-gateway
curl http://localhost:9546/status

# Test dari Nginx ke Kong (ganti dengan nama container Nginx yang sebenarnya)
docker exec <nginx-container-name> curl http://kong-gateway:9545/status

# Test konfigurasi Nginx
docker exec <nginx-container-name> nginx -t
```

## 📚 Dokumentasi Lengkap

Lihat `docs/NGINX_CLOUDFLARE_SETUP.md` untuk dokumentasi lengkap.


## untuk migrate ke database mode jalankan script migrate_to_db.sh
./scripts/migrate_to_db.sh

