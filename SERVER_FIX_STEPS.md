# Step-by-Step Fix Kong SSO di Server

## 🎯 **Tujuan**
Memperbaiki masalah Kong SSO yang masih menggunakan cache lama dengan IP `172.17.0.1:9588` dan mengubahnya ke subdomain `https://api-gate.motorsights.com`.

## 📋 **Step-by-Step Instructions**

### **Step 1: Login ke Server**
```bash
# Login ke server Anda
ssh your-username@your-server-ip
# atau
ssh your-username@services.motorsights.com
```

### **Step 2: Navigate ke Kong Directory**
```bash
# Masuk ke direktori Kong API Gateway
cd /path/to/kong-api-gateway
# atau jika di home directory
cd ~/kong-api-gateway
```

### **Step 3: Cek Status Kong**
```bash
# Cek apakah Kong sedang berjalan
docker-compose ps

# Jika Kong tidak berjalan, start Kong
docker-compose up -d

# Tunggu Kong startup (30 detik)
sleep 30
```

### **Step 4: Backup Konfigurasi Saat Ini**
```bash
# Backup konfigurasi Kong saat ini
curl http://localhost:9546/config > kong_backup_$(date +%Y%m%d_%H%M%S).json

# Backup juga routes dan services
curl http://localhost:9546/services/ > services_backup_$(date +%Y%m%d_%H%M%S).json
curl http://localhost:9546/routes/ > routes_backup_$(date +%Y%m%d_%H%M%S).json
```

### **Step 5: Cek Konfigurasi Saat Ini**
```bash
# Cek semua services
curl http://localhost:9546/services/ | jq '.data[] | {name: .name, host: .host, port: .port, protocol: .protocol}'

# Cek semua routes SSO
curl http://localhost:9546/routes/ | jq '.data[] | select(.name | contains("sso")) | {name: .name, service: .service.id, paths: .paths}'
```

### **Step 6: Identifikasi Service yang Salah**
```bash
# Cari service yang masih menggunakan IP lama
curl http://localhost:9546/services/ | jq '.data[] | select(.host == "host.docker.internal" or .host == "172.17.0.1" or .port == 9588) | {id: .id, name: .name, host: .host, port: .port}'
```

### **Step 7: Hapus Routes yang Salah**
```bash
# Hapus routes yang menggunakan service lama
# Ganti dengan ID service yang benar dari Step 6

# Contoh (sesuaikan dengan ID yang ditemukan):
curl -X DELETE http://localhost:9546/routes/sso-login-api-gate-final
curl -X DELETE http://localhost:9546/routes/sso-login-api-gate-transform
curl -X DELETE http://localhost:9546/routes/sso-login-api-gate-direct
curl -X DELETE http://localhost:9546/routes/sso-login-services-direct
```

### **Step 8: Hapus Service yang Salah**
```bash
# Hapus service yang masih menggunakan konfigurasi lama
# Ganti dengan ID service yang ditemukan di Step 6

# Contoh (sesuaikan dengan ID yang ditemukan):
curl -X DELETE http://localhost:9546/services/sso-service-api-gate
```

### **Step 9: Pastikan Service SSO Benar**
```bash
# Cek service sso-service yang benar
curl http://localhost:9546/services/sso-service | jq

# Jika belum ada atau salah, buat service yang benar:
curl -X POST http://localhost:9546/services/ \
  -d "name=sso-service" \
  -d "url=https://api-gate.motorsights.com" \
  -d "connect_timeout=60000" \
  -d "write_timeout=60000" \
  -d "read_timeout=60000"
```

### **Step 10: Update Service SSO jika Perlu**
```bash
# Update service sso-service ke konfigurasi yang benar
curl -X PATCH http://localhost:9546/services/sso-service \
  -d "url=https://api-gate.motorsights.com" \
  -d "connect_timeout=60000" \
  -d "write_timeout=60000" \
  -d "read_timeout=60000"
```

### **Step 11: Pastikan Routes SSO Benar**
```bash
# Cek routes yang tersisa
curl http://localhost:9546/routes/ | jq '.data[] | select(.name | contains("sso")) | {name: .name, service: .service.id, paths: .paths}'

# Jika routes tidak ada, buat routes yang benar:
# SSO Login Route
curl -X POST http://localhost:9546/services/sso-service/routes \
  -d "name=sso-login-routes" \
  -d "paths[]=/api/auth/sso/login" \
  -d "methods[]=POST" \
  -d "methods[]=OPTIONS" \
  -d "strip_path=false"

# SSO Userinfo Route
curl -X POST http://localhost:9546/services/sso-service/routes \
  -d "name=sso-userinfo-routes" \
  -d "paths[]=/api/auth/sso/userinfo" \
  -d "methods[]=GET" \
  -d "methods[]=OPTIONS" \
  -d "strip_path=true"

# SSO Menus Route
curl -X POST http://localhost:9546/services/sso-service/routes \
  -d "name=sso-menus-routes" \
  -d "paths[]=/api/menus" \
  -d "methods[]=GET" \
  -d "methods[]=POST" \
  -d "methods[]=PUT" \
  -d "methods[]=DELETE" \
  -d "methods[]=OPTIONS" \
  -d "strip_path=true"
```

### **Step 12: Restart Kong untuk Membersihkan Cache**
```bash
# Restart Kong untuk membersihkan cache
docker-compose restart kong

# Tunggu Kong startup
sleep 15
```

### **Step 13: Verifikasi Konfigurasi**
```bash
# Cek service sso-service
curl http://localhost:9546/services/sso-service | jq '{name: .name, host: .host, port: .port, protocol: .protocol, url: .url}'

# Cek routes SSO
curl http://localhost:9546/routes/ | jq '.data[] | select(.name | contains("sso")) | {name: .name, service: .service.id, paths: .paths}'
```

### **Step 14: Test Kong Langsung**
```bash
# Test Kong langsung (harus berhasil)
curl -v http://localhost:9545/api/auth/sso/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@sso-testing.com","password":"admin123","client_id":"string","redirect_uri":"string"}'
```

### **Step 15: Cek Nginx Status**
```bash
# Cek nginx status
sudo systemctl status nginx

# Jika nginx tidak berjalan, start nginx
sudo systemctl start nginx

# Reload nginx
sudo systemctl reload nginx
```

### **Step 16: Test Melalui Nginx**
```bash
# Test melalui nginx (harus berhasil)
curl -v https://services.motorsights.com/api/auth/sso/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@sso-testing.com","password":"admin123","client_id":"string","redirect_uri":"string"}'
```

### **Step 17: Monitor Logs**
```bash
# Monitor Kong logs untuk memastikan tidak ada error
docker-compose logs -f kong

# Monitor nginx logs
sudo tail -f /var/log/nginx/error.log
```

## 🔧 **Troubleshooting Commands**

### Jika Masih Ada Error:
```bash
# Cek Kong logs
docker-compose logs kong | grep -i error

# Cek nginx logs
sudo tail -20 /var/log/nginx/error.log

# Cek port binding
netstat -tlnp | grep 9545

# Test Kong connectivity
curl -v http://localhost:9545/

# Test SSO service langsung
curl -v https://api-gate.motorsights.com/api/auth/sso/login
```

### Jika Perlu Rollback:
```bash
# Rollback ke backup
curl -X POST http://localhost:9546/config -F "config=@kong_backup_YYYYMMDD_HHMMSS.json"
```

## ✅ **Expected Results**

Setelah semua step selesai:
- ✅ Kong service menggunakan `https://api-gate.motorsights.com:443`
- ✅ Tidak ada routes duplikat
- ✅ Kong logs tidak menunjukkan error dengan IP lama
- ✅ `curl http://localhost:9545/api/auth/sso/login` berhasil
- ✅ `curl https://services.motorsights.com/api/auth/sso/login` berhasil

## 📞 **Jika Masih Bermasalah**

1. **Cek Kong logs**: `docker-compose logs kong`
2. **Cek nginx logs**: `sudo tail -f /var/log/nginx/error.log`
3. **Test Kong langsung**: `curl http://localhost:9545/api/auth/sso/login`
4. **Test SSO service**: `curl https://api-gate.motorsights.com/api/auth/sso/login`
5. **Restart semua**: `docker-compose restart kong && sudo systemctl restart nginx`

---

**Catatan**: Jalankan step-step ini secara berurutan dan tunggu setiap command selesai sebelum melanjutkan ke step berikutnya.
