# 🔧 Deploy DNS Fix untuk Kong Gateway

## 📋 Yang Sudah Diupdate:

✅ **docker-compose.yml** - DNS fix sudah ditambahkan  
✅ **docker-compose.server.yml** - DNS fix sudah ditambahkan  
✅ **docker-compose.dev.yml** - DNS fix sudah ditambahkan  
✅ **docker-compose.local.yml** - DNS fix sudah ditambahkan  

## 🎯 Perubahan yang Dilakukan:

Semua file docker-compose sekarang memiliki konfigurasi DNS:

```yaml
dns:
  - 8.8.8.8      # Google DNS Primary
  - 8.8.4.4      # Google DNS Secondary
  - 1.1.1.1      # Cloudflare DNS
```

## 🚀 Cara Deploy ke Server Ubuntu:

### **Step 1: Backup dan Update Files**

```bash
# SSH ke server
ssh user@your-server

# Masuk ke directory project
cd ~/MSI/api-gateway

# Backup file lama
cp docker-compose.server.yml docker-compose.server.yml.backup.$(date +%Y%m%d_%H%M%S)

# Pull changes dari git (jika menggunakan git)
git pull origin production

# Atau copy manual file yang sudah diupdate
```

### **Step 2: Restart Kong dengan Config Baru**

```bash
# Stop Kong
docker-compose -f docker-compose.server.yml down

# Verify container stopped
docker ps | grep kong-gateway

# Start dengan config baru
docker-compose -f docker-compose.server.yml up -d

# Wait 15 detik untuk Kong fully start
sleep 15
```

### **Step 3: Verify DNS Fix Berhasil**

```bash
# Test DNS resolution dari Kong container
docker exec kong-gateway nslookup api-gate.motorsights.com

# Expected output: IP address dari api-gate.motorsights.com

# Test connectivity ke backend
docker exec kong-gateway curl -I https://api-gate.motorsights.com

# Expected: HTTP response (bukan timeout)
```

### **Step 4: Test Endpoint**

```bash
# Test Kong proxy endpoint
curl -X POST http://localhost:9545/api/menus \
  -H "Content-Type: application/json" \
  -d '{}' \
  -w "\nStatus: %{http_code}\nTime: %{time_total}s\n"

# Expected: HTTP 401/400 (bukan 504 timeout)
```

### **Step 5: Run Diagnostic (Optional)**

```bash
# Jalankan diagnostic script
./scripts/diagnose-timeout-issue.sh

# Expected: Backend services sekarang REACHABLE ✅
```

## ✅ Verification Checklist:

- [ ] Kong container running & healthy
- [ ] DNS resolution working dari Kong container
- [ ] Backend services reachable dari Kong
- [ ] Endpoint responding (bukan timeout)
- [ ] No 504 Gateway Timeout errors

## 🔍 Troubleshooting:

### Jika Masih Timeout Setelah DNS Fix:

1. **Check Firewall:**
   ```bash
   sudo ufw status
   sudo ufw allow out to any
   ```

2. **Check Backend Service Status:**
   ```bash
   curl -I https://api-gate.motorsights.com
   # Test dari server langsung
   ```

3. **Check Docker Network:**
   ```bash
   docker network ls
   docker network inspect bridge
   ```

4. **Recreate Network (Nuclear Option):**
   ```bash
   docker-compose -f docker-compose.server.yml down
   docker network prune
   docker-compose -f docker-compose.server.yml up -d
   ```

## 📊 Expected Results:

### Before DNS Fix:
```
Testing SSO Service (https://api-gate.motorsights.com) ... ❌ TIMEOUT or UNREACHABLE
```

### After DNS Fix:
```
Testing SSO Service (https://api-gate.motorsights.com) ... ✅ OK (0.234s) - HTTP 404
```

## 🛡️ Safety Note:

- ✅ Perubahan **hanya affect Kong container**
- ✅ Container lain **tidak terpengaruh**
- ✅ Downtime minimal (~10-15 detik)
- ✅ Config ter-backup otomatis

## 📞 Contact:

Jika masih ada masalah setelah DNS fix, kemungkinan:
1. Backend services sedang down
2. Firewall blocking outbound connections
3. Network routing issue di server

## 📝 Rollback (Jika Diperlukan):

```bash
# Restore backup
cp docker-compose.server.yml.backup.[timestamp] docker-compose.server.yml

# Restart
docker-compose -f docker-compose.server.yml down
docker-compose -f docker-compose.server.yml up -d
```

---

**Last Updated:** $(date)  
**Status:** Ready for deployment ✅

