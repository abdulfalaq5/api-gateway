# Kong API Gateway - Panduan Setup Lengkap Server Internal

## 📋 Overview
Panduan lengkap untuk menginstall dan mengkonfigurasi Kong API Gateway di server internal dengan menggunakan PostgreSQL yang sudah ada.

## 🌐 Port Configuration
| Port | Service | Akses | Deskripsi |
|------|---------|-------|-----------|
| **9545** | Kong Proxy | **Public** | Port utama untuk client mengakses API |
| **9546** | Kong Admin API | **Internal Only** | Management Kong via API |
| **9547** | Kong Admin GUI | **Internal Only** | Interface web untuk management |
| **5432** | PostgreSQL | **Internal Only** | Database Kong (sudah ada) |

## 🚀 Langkah-langkah Setup

### 1. Prerequisites
Pastikan server internal sudah memiliki:
- ✅ Docker dan Docker Compose
- ✅ PostgreSQL yang sudah berjalan
- ✅ User database dengan hak akses untuk membuat database

### 2. Persiapan Database PostgreSQL

#### 2.1 Login ke PostgreSQL
```bash
# Login sebagai superuser
sudo -u postgres psql

# Atau jika menggunakan user lain
psql -h localhost -U postgres
```

#### 2.2 Buat Database Kong
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

#### 2.3 Verifikasi Database
```bash
# Test koneksi ke database kong
psql -h localhost -U kong -d kong -c "SELECT version();"
```

### 3. Download dan Setup Kong

#### 3.1 Clone/Download Kong API Gateway
```bash
# Jika menggunakan git
git clone <repository-url> kong-api-gateway
cd kong-api-gateway

# Atau download dan extract manual
```

#### 3.2 Update Konfigurasi Database
Edit file `docker-compose.yml`:
```yaml
services:
  kong-migrations:
    image: kong:3.4
    container_name: kong-migrations
    environment:
      KONG_DATABASE: postgres
      KONG_PG_HOST: host.docker.internal  # Untuk akses ke host
      KONG_PG_USER: kong                  # User database
      KONG_PG_PASSWORD: kong_password     # Password database
      KONG_PG_DATABASE: kong             # Database name
    command: kong migrations bootstrap
    restart: "no"
    extra_hosts:
      - "host.docker.internal:host-gateway"

  kong:
    image: kong:3.4
    container_name: kong-gateway
    environment:
      KONG_DATABASE: postgres
      KONG_PG_HOST: host.docker.internal
      KONG_PG_USER: kong
      KONG_PG_PASSWORD: kong_password
      KONG_PG_DATABASE: kong
      KONG_PROXY_LISTEN: 0.0.0.0:9545
      KONG_ADMIN_LISTEN: 0.0.0.0:9546
      KONG_ADMIN_GUI_LISTEN: 0.0.0.0:9547
    ports:
      - "9545:9545"
      - "9546:9546"
      - "9547:9547"
    depends_on:
      kong-migrations:
        condition: service_completed_successfully
    restart: unless-stopped
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

### 4. Setup Firewall dan Network

#### 4.1 Setup Firewall (Ubuntu/Debian)
```bash
# Jalankan script setup
sudo ./scripts/setup-server.sh

# Atau manual setup UFW
sudo ufw allow 9545/tcp comment "Kong Proxy - Public Access"
sudo ufw allow from 192.168.1.0/24 to any port 9546 comment "Kong Admin API - Internal"
sudo ufw allow from 192.168.1.0/24 to any port 9547 comment "Kong Admin GUI - Internal"
sudo ufw allow from 192.168.1.0/24 to any port 5432 comment "PostgreSQL - Internal"
```

#### 4.2 Setup Firewall (CentOS/RHEL)
```bash
# Setup iptables
sudo iptables -A INPUT -p tcp --dport 9545 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 9546 -s 192.168.1.0/24 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 9547 -s 192.168.1.0/24 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 5432 -s 192.168.1.0/24 -j ACCEPT

# Save rules
sudo iptables-save > /etc/iptables/rules.v4
```

### 5. Install dan Jalankan Kong

#### 5.1 Jalankan Kong
```bash
# Start Kong dengan Docker
./scripts/start-kong-docker.sh

# Atau manual
docker-compose up -d
```

#### 5.2 Verifikasi Instalasi
```bash
# Test Kong services
./scripts/test-kong-docker.sh

# Atau manual test
curl http://localhost:9545/  # Kong Proxy
curl http://localhost:9546/  # Kong Admin API
curl http://localhost:9547/  # Kong Admin GUI
```

### 6. Konfigurasi Kong

#### 6.1 Tambahkan Service Pertama
```bash
# Tambahkan service
curl -i -X POST http://localhost:9546/services/ \
  --data "name=test-service" \
  --data "url=http://httpbin.org"

# Tambahkan route
curl -i -X POST http://localhost:9546/services/test-service/routes \
  --data "paths[]=/test" \
  --data "strip_path=true"

# Test service
curl -i http://localhost:9545/test
```

#### 6.2 Setup Authentication (Opsional)
```bash
# Buat consumer
curl -i -X POST http://localhost:9546/consumers/ \
  --data "username=api-client"

# Buat API key
curl -i -X POST http://localhost:9546/consumers/api-client/key-auth \
  --data "key=your-secret-key"

# Enable key auth untuk service
curl -i -X POST http://localhost:9546/services/test-service/plugins \
  --data "name=key-auth"

# Test dengan API key
curl -i http://localhost:9545/test \
  -H "apikey: your-secret-key"
```

### 7. Monitoring dan Maintenance

#### 7.1 Setup Monitoring
```bash
# Jalankan monitoring script
kong-monitor.sh

# Atau manual check
docker-compose ps
docker-compose logs kong
```

#### 7.2 Backup Database
```bash
# Backup database kong
pg_dump -h localhost -U kong kong > kong_backup_$(date +%Y%m%d).sql

# Restore database (jika diperlukan)
psql -h localhost -U kong kong < kong_backup_20240101.sql
```

## 🔧 Troubleshooting

### Database Connection Issues
```bash
# Cek koneksi PostgreSQL
pg_isready -h localhost -p 5432 -U kong

# Test koneksi dari container
docker run --rm --network host postgres:15 pg_isready -h localhost -p 5432 -U kong
```

### Port Issues
```bash
# Cek port yang digunakan
netstat -tlnp | grep -E ":(9545|9546|9547|5432)"

# Cek firewall
sudo ufw status
# atau
sudo iptables -L
```

### Kong Service Issues
```bash
# Cek log Kong
docker-compose logs kong

# Restart Kong
docker-compose restart kong

# Rebuild Kong
docker-compose down
docker-compose up -d --build
```

## 📊 Testing dan Validation

### Test Connectivity
```bash
# Test dari server internal
./scripts/test-server-connectivity.sh

# Test dari client external
curl http://your-server-ip:9545/
```

### Test Management
```bash
# Test Admin API
curl http://your-server-ip:9546/

# Test Admin GUI
curl http://your-server-ip:9547/
```

## 🔒 Security Best Practices

1. **Firewall Configuration**
   - Port 9545: Public access
   - Port 9546, 9547, 5432: Internal access only

2. **Database Security**
   - Gunakan password yang kuat
   - Batasi akses database ke internal network
   - Regular backup database

3. **Kong Security**
   - Enable authentication untuk sensitive services
   - Setup rate limiting
   - Monitor access logs

## 📚 Referensi

- [Kong Documentation](https://docs.konghq.com/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

## 🆘 Support

Jika mengalami masalah:
1. Cek log Kong: `docker-compose logs kong`
2. Cek database connection: `pg_isready -h localhost -p 5432`
3. Cek firewall rules: `sudo ufw status`
4. Test connectivity: `./scripts/test-server-connectivity.sh`
