# Kong API Gateway - Troubleshooting Guide

## 🚨 Masalah Umum dan Solusi

### Masalah: SSO Service Timeout

**Gejala:**
- SSO API bekerja langsung: `https://api-gate.motorsights.com/api/auth/sso/login`
- SSO API gagal melalui Kong: `https://services.motorsights.com/api/auth/sso/login`
- Log Kong menunjukkan: `upstream timed out (110: Connection timed out)`
- Error duplicate key: `duplicate key value violates unique constraint`

**Solusi Cepat:**
```bash
# Jalankan script fix otomatis
./scripts/fix-kong-sso-issues.sh
```

**Solusi Manual:**
```bash
# 1. Test connectivity ke SSO service
./scripts/test-sso-connectivity.sh

# 2. Clean database dari konfigurasi duplikat
./scripts/clean-kong-database.sh

# 3. Fix upstream configuration
./scripts/fix-sso-upstream.sh
```

**Root Cause:**
- Upstream URL tidak accessible dari container Kong
- Konfigurasi duplikat di database Kong
- Timeout settings terlalu rendah

### Masalah: Curl Gagal di Server

**Gejala:**
- Database sudah terhubung
- Sistem berjalan di Docker
- Curl ke endpoint Kong gagal

**Langkah Troubleshooting:**

#### 1. Quick Check
```bash
# Jalankan script quick check
./scripts/quick-server-check.sh
```

#### 2. Diagnosa Detail
```bash
# Jalankan diagnosa lengkap
./scripts/diagnose-kong-server.sh
```

#### 3. Test Curl Issues
```bash
# Test masalah curl secara detail
./scripts/test-curl-issues.sh
```

#### 4. Fix Otomatis
```bash
# Coba perbaiki masalah otomatis
./scripts/fix-kong-server-issues.sh
```

## 🔍 Checklist Troubleshooting

### ✅ Cek Dasar
- [ ] Docker berjalan: `docker info`
- [ ] Kong container berjalan: `docker ps | grep kong`
- [ ] Port terbuka: `netstat -tlnp | grep 9545`
- [ ] Database accessible: `telnet 162.11.0.232 5432`

### ✅ Cek Konektivitas
- [ ] Localhost access: `curl http://localhost:9545/`
- [ ] External access: `curl http://[SERVER_IP]:9545/`
- [ ] Admin API: `curl http://localhost:9546/`
- [ ] Admin GUI: `curl http://localhost:9547/`

### ✅ Cek Konfigurasi
- [ ] Kong binding ke 0.0.0.0 (bukan 127.0.0.1)
- [ ] Firewall mengizinkan port 9545, 9546, 9547
- [ ] Database connection string benar
- [ ] Docker network configuration

## 🛠️ Solusi Umum

### 1. Kong Tidak Merespons Curl

**Penyebab:**
- Kong belum fully started
- Port tidak terbuka
- Firewall memblokir
- Kong binding ke interface yang salah

**Solusi:**
```bash
# Restart Kong
docker-compose down
docker-compose up -d

# Tunggu 30 detik untuk startup
sleep 30

# Test lagi
curl http://localhost:9545/
```

### 2. External Access Gagal

**Penyebab:**
- Kong binding ke 127.0.0.1 (localhost only)
- Firewall memblokir external access
- Network interface tidak dikonfigurasi

**Solusi:**
```bash
# Cek binding Kong
docker exec kong-gateway netstat -tlnp | grep 9545

# Jika binding ke 127.0.0.1, restart dengan config yang benar
# Pastikan di docker-compose.yml:
# KONG_PROXY_LISTEN: 0.0.0.0:9545

# Buka firewall
sudo ufw allow 9545/tcp
sudo ufw allow 9546/tcp
sudo ufw allow 9547/tcp
```

### 3. Database Connection Issues

**Penyebab:**
- Database server tidak accessible
- Credentials salah
- Network connectivity masalah

**Solusi:**
```bash
# Test database connectivity
telnet 162.11.0.232 5432

# Test dengan psql
PGPASSWORD="pgpass" psql -h 162.11.0.232 -p 5432 -U sharedpg -d kong -c "SELECT 1;"

# Cek Kong logs untuk database errors
docker logs kong-gateway | grep -i database
```

### 4. Kong Container Tidak Start

**Penyebab:**
- Database migration gagal
- Configuration error
- Resource tidak cukup

**Solusi:**
```bash
# Cek container logs
docker logs kong-gateway

# Cek migration logs
docker logs kong-migrations

# Restart dengan clean state
docker-compose down -v
docker-compose up -d
```

## 📊 Monitoring Commands

### Status Check
```bash
# Cek status Kong
./scripts/status-kong.sh

# Cek connectivity
./scripts/test-server-connectivity.sh

# Test Kong functionality
./scripts/test-kong.sh
```

### Log Monitoring
```bash
# Kong logs
docker logs -f kong-gateway

# All services logs
docker-compose logs -f

# Kong Admin API info
curl http://localhost:9546/ | jq .
```

### Network Diagnostics
```bash
# Port status
netstat -tlnp | grep -E ":(9545|9546|9547|5432)"

# Firewall status
sudo ufw status

# Network interfaces
ip addr show
```

## 🔧 Advanced Troubleshooting

### Kong Configuration Issues
```bash
# Cek Kong configuration
docker exec kong-gateway kong config

# Reload configuration
docker exec kong-gateway kong reload

# Check plugins
curl http://localhost:9546/plugins/ | jq .
```

### Database Issues
```bash
# Kong database status
curl http://localhost:9546/status | jq .

# Check migrations
docker exec kong-gateway kong migrations status

# Run migrations manually
docker exec kong-gateway kong migrations bootstrap
```

### Performance Issues
```bash
# Check Kong metrics
curl http://localhost:9546/status | jq .

# Check container resources
docker stats kong-gateway

# Check system resources
top
free -h
df -h
```

## 📞 Emergency Commands

### Jika Semua Gagal
```bash
# Complete reset
docker-compose down -v
docker system prune -f
docker-compose up -d

# Manual Kong restart
docker restart kong-gateway

# Check system resources
free -h
df -h
```

### Backup dan Recovery
```bash
# Backup Kong configuration
curl http://localhost:9546/ | jq . > kong-backup.json

# Backup database (jika perlu)
pg_dump -h 162.11.0.232 -p 5432 -U sharedpg kong > kong-db-backup.sql
```

## 📋 Checklist Pre-Production

Sebelum deploy ke production, pastikan:

- [ ] Semua script test berhasil
- [ ] External access berfungsi
- [ ] Database connection stable
- [ ] Firewall dikonfigurasi dengan benar
- [ ] Logs tidak ada error
- [ ] Monitoring tools berfungsi
- [ ] Backup strategy siap

## 🆘 Getting Help

Jika masalah masih berlanjut:

1. Jalankan diagnosa lengkap: `./scripts/diagnose-kong-server.sh`
2. Simpan output logs: `docker logs kong-gateway > kong-logs.txt`
3. Simpan system info: `./scripts/quick-server-check.sh > system-status.txt`
4. Cek dokumentasi Kong: https://docs.konghq.com/
5. Cek Kong community: https://discuss.konghq.com/

---

**Catatan:** Selalu backup konfigurasi sebelum melakukan perubahan besar!
