# Quick Fix Kong SSO di Server

## 🚀 **Solusi Cepat (Recommended)**

### **Option 1: Script Otomatis**
```bash
# Login ke server
ssh your-username@your-server-ip

# Masuk ke direktori Kong
cd /path/to/kong-api-gateway

# Jalankan script fix otomatis
./scripts/fix-kong-sso-server.sh
```

### **Option 2: Manual Commands**
```bash
# 1. Start Kong jika belum berjalan
docker-compose up -d
sleep 30

# 2. Hapus routes dan services yang salah
curl -X DELETE http://localhost:9546/routes/sso-login-api-gate-final
curl -X DELETE http://localhost:9546/routes/sso-login-api-gate-transform
curl -X DELETE http://localhost:9546/routes/sso-login-api-gate-direct
curl -X DELETE http://localhost:9546/routes/sso-login-services-direct
curl -X DELETE http://localhost:9546/services/sso-service-api-gate

# 3. Update service SSO ke konfigurasi yang benar
curl -X PATCH http://localhost:9546/services/sso-service \
  -d "url=https://api-gate.motorsights.com" \
  -d "connect_timeout=60000" \
  -d "write_timeout=60000" \
  -d "read_timeout=60000"

# 4. Restart Kong untuk membersihkan cache
docker-compose restart kong
sleep 15

# 5. Test Kong langsung
curl -v http://localhost:9545/api/auth/sso/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@sso-testing.com","password":"admin123","client_id":"string","redirect_uri":"string"}'

# 6. Test melalui nginx
curl -v https://services.motorsights.com/api/auth/sso/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@sso-testing.com","password":"admin123","client_id":"string","redirect_uri":"string"}'
```

## 🔍 **Verifikasi Hasil**

### **Cek Konfigurasi Kong**
```bash
# Cek service SSO
curl http://localhost:9546/services/sso-service | jq '{name: .name, host: .host, port: .port, protocol: .protocol}'

# Cek routes SSO
curl http://localhost:9546/routes/ | jq '.data[] | select(.name | contains("sso")) | {name: .name, paths: .paths}'
```

### **Expected Output**
```json
{
  "name": "sso-service",
  "host": "api-gate.motorsights.com",
  "port": 443,
  "protocol": "https"
}
```

## 📊 **Monitor Logs**

```bash
# Monitor Kong logs
docker-compose logs -f kong

# Monitor nginx logs
sudo tail -f /var/log/nginx/error.log
```

## ✅ **Success Indicators**

- ✅ Kong service menggunakan `api-gate.motorsights.com:443`
- ✅ Kong logs tidak menunjukkan error dengan IP lama
- ✅ `curl http://localhost:9545/api/auth/sso/login` berhasil
- ✅ `curl https://services.motorsights.com/api/auth/sso/login` berhasil

## 🆘 **Jika Masih Bermasalah**

1. **Cek Kong logs**: `docker-compose logs kong | grep -i error`
2. **Cek nginx logs**: `sudo tail -20 /var/log/nginx/error.log`
3. **Restart semua**: `docker-compose restart kong && sudo systemctl restart nginx`
4. **Test SSO service langsung**: `curl https://api-gate.motorsights.com/api/auth/sso/login`

---

**Catatan**: Gunakan **Option 1 (Script Otomatis)** untuk hasil yang lebih reliable dan comprehensive.
