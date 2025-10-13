# Kong Deployment Workflow

Panduan lengkap untuk deploy dan update Kong routes dengan mudah dan aman.

## 📋 Table of Contents

- [Quick Start](#quick-start)
- [Workflow untuk Update Routes](#workflow-untuk-update-routes)
- [Commands](#commands)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

---

## 🚀 Quick Start

### Deploy Script Baru: `deploy-kong-routes.sh`

Script ini menggantikan `fix-kong-yaml-syntax.sh` dengan fitur lebih lengkap:

- ✅ Auto-validate YAML syntax
- ✅ Auto-replace `host.docker.internal` → `localhost`
- ✅ Hot reload (tanpa restart container)
- ✅ Automatic rollback jika gagal
- ✅ Show diff before deploy
- ✅ Pull changes from server
- ✅ Test routes

---

## 📝 Workflow untuk Update Routes

### Scenario 1: Tambah Route Baru

```bash
# 1. Edit kong.yml di local machine
vim config/kong.yml

# 2. Tambahkan route baru, misalnya:
# - name: new-route
#   paths:
#     - /api/new-endpoint
#   methods:
#     - GET
#     - POST

# 3. Validate local file
./scripts/deploy-kong-routes.sh validate

# 4. Deploy ke server
./scripts/deploy-kong-routes.sh deploy

# 5. Test route baru
./scripts/deploy-kong-routes.sh test /api/new-endpoint
```

### Scenario 2: Update Route yang Sudah Ada

```bash
# 1. Pull config terbaru dari server (optional, jika ada perubahan di server)
./scripts/deploy-kong-routes.sh pull

# 2. Edit kong.yml
vim config/kong.yml

# 3. Check perbedaan dengan server
./scripts/deploy-kong-routes.sh diff

# 4. Deploy changes
./scripts/deploy-kong-routes.sh deploy
```

### Scenario 3: Hapus Route

```bash
# 1. Edit kong.yml dan hapus route yang tidak dibutuhkan
vim config/kong.yml

# 2. Deploy
./scripts/deploy-kong-routes.sh deploy

# 3. Verify routes
./scripts/deploy-kong-routes.sh status
```

---

## 🛠️ Commands

### `deploy`
Deploy local `kong.yml` ke server dengan validation dan hot reload.

```bash
./scripts/deploy-kong-routes.sh deploy
```

**Flow:**
1. ✅ Validate local YAML
2. ✅ Auto-fix `host.docker.internal` → `localhost`
3. ✅ Backup remote file
4. ✅ Copy to server
5. ✅ Validate on server
6. ✅ Hot reload Kong (atau restart jika perlu)
7. ✅ Verify health
8. ✅ Show current routes

### `pull`
Pull `kong.yml` dari server ke local (backup local file automatically).

```bash
./scripts/deploy-kong-routes.sh pull
```

**Use case:** 
- Sinkronisasi dengan perubahan di server
- Backup config dari production

### `diff`
Lihat perbedaan antara local dan remote `kong.yml`.

```bash
./scripts/deploy-kong-routes.sh diff
```

**Output:** Unified diff format (seperti `git diff`)

### `status`
Check status Kong di server.

```bash
./scripts/deploy-kong-routes.sh status
```

**Output:**
- Kong health status
- Total routes
- Total services
- Container status

### `test <path>`
Test route specific melalui Kong.

```bash
./scripts/deploy-kong-routes.sh test /api/catalogs/categories/get
```

### `validate`
Validate local `kong.yml` tanpa deploy.

```bash
./scripts/deploy-kong-routes.sh validate
```

---

## ✅ Best Practices

### 1. **Selalu Validate Sebelum Deploy**

```bash
./scripts/deploy-kong-routes.sh validate
./scripts/deploy-kong-routes.sh deploy
```

### 2. **Check Diff Sebelum Deploy (untuk Production)**

```bash
./scripts/deploy-kong-routes.sh diff
# Review changes
./scripts/deploy-kong-routes.sh deploy
```

### 3. **Backup Regular**

Script otomatis backup setiap deploy dengan timestamp:
```
config/kong.yml.backup.20251013_120000
```

Restore jika perlu:
```bash
cp config/kong.yml.backup.20251013_120000 config/kong.yml
./scripts/deploy-kong-routes.sh deploy
```

### 4. **Test Setelah Deploy**

```bash
./scripts/deploy-kong-routes.sh deploy
./scripts/deploy-kong-routes.sh status
./scripts/deploy-kong-routes.sh test /api/your-endpoint
```

### 5. **Git Workflow (Recommended)**

```bash
# 1. Create branch untuk perubahan
git checkout -b feature/add-new-route

# 2. Edit kong.yml
vim config/kong.yml

# 3. Validate
./scripts/deploy-kong-routes.sh validate

# 4. Commit changes
git add config/kong.yml
git commit -m "Add new route for XYZ service"

# 5. Push to remote
git push origin feature/add-new-route

# 6. Deploy ke server
./scripts/deploy-kong-routes.sh deploy

# 7. Merge to main/production
git checkout production
git merge feature/add-new-route
git push origin production
```

---

## 🔧 Troubleshooting

### Issue 1: YAML Syntax Error

**Symptom:**
```
[ERROR] YAML syntax error!
```

**Solution:**
```bash
# Validate dengan detail error
python3 -c "import yaml; yaml.safe_load(open('config/kong.yml'))"

# Fix indentation atau syntax error
vim config/kong.yml
```

### Issue 2: Hot Reload Failed

**Symptom:**
```
[WARNING] Hot reload failed, restarting container...
```

**Cause:** Hot reload hanya bekerja untuk perubahan routes/services, tidak untuk perubahan global config.

**Solution:** Script akan otomatis restart container. Tunggu ~15 detik.

### Issue 3: Kong Not Responding After Deploy

**Solution:**
```bash
# Check logs
ssh msiserver@162.11.0.232
cd ~/MSI/api-gateway
docker logs kong-gateway --tail 50

# Restart Kong
docker restart kong-gateway

# Verify
./scripts/deploy-kong-routes.sh status
```

### Issue 4: Route Tidak Bekerja (404)

**Debugging:**
```bash
# 1. Check route terdaftar
./scripts/deploy-kong-routes.sh status

# 2. Check route detail di server
ssh msiserver@162.11.0.232
curl -s http://localhost:9546/routes | jq '.data[] | select(.name=="your-route-name")'

# 3. Test direct ke backend
curl -v http://localhost:9550/your-backend-endpoint

# 4. Test via Kong
curl -v http://localhost:9545/your-kong-route
```

---

## 🎯 Configuration Best Practices

### Service URLs (PENTING!)

**✅ Correct (dengan network_mode: host):**
```yaml
services:
  - name: my-service
    url: http://localhost:9550    # ✅ localhost
```

**❌ Wrong:**
```yaml
services:
  - name: my-service
    url: http://host.docker.internal:9550    # ❌ Tidak akan work di host network mode
```

Script `deploy-kong-routes.sh` akan otomatis fix ini.

### Route Priority

Route yang lebih specific harus di atas:

```yaml
routes:
  # ✅ Specific route first
  - name: categories-get-route
    paths:
      - /api/categories/get
  
  # Then general route
  - name: categories-route
    paths:
      - /api/categories
```

### Strip Path

```yaml
# strip_path: true → Remove path dari request ke upstream
routes:
  - name: example-route
    paths:
      - /api/v1/users
    strip_path: true    # Request ke upstream: /users

# strip_path: false → Keep full path
routes:
  - name: example-route
    paths:
      - /api/v1/users
    strip_path: false   # Request ke upstream: /api/v1/users
```

---

## 📊 Monitoring

### Check Kong Logs Real-time

```bash
ssh msiserver@162.11.0.232
docker logs kong-gateway -f
```

### Check Metrics

```bash
./scripts/deploy-kong-routes.sh status
```

### Check Specific Route

```bash
ssh msiserver@162.11.0.232
curl -s http://localhost:9546/routes | jq '.data[] | select(.name=="your-route-name")'
```

---

## 🚨 Emergency Rollback

Jika deployment menyebabkan masalah:

```bash
# 1. SSH ke server
ssh msiserver@162.11.0.232
cd ~/MSI/api-gateway

# 2. List backups
ls -lt config/kong.yml.backup.*

# 3. Restore backup
cp config/kong.yml.backup.20251013_120000 config/kong.yml

# 4. Restart Kong
docker restart kong-gateway

# 5. Verify
curl -s http://localhost:9546/status
```

---

## 📞 Support

Jika ada masalah:

1. Check logs: `docker logs kong-gateway --tail 100`
2. Check status: `./scripts/deploy-kong-routes.sh status`
3. Review documentation: `docs/KONG_DEPLOYMENT_WORKFLOW.md`
4. Check troubleshooting section di atas

---

## 🎓 Summary

**Daily Workflow:**

```bash
# Edit routes
vim config/kong.yml

# Validate
./scripts/deploy-kong-routes.sh validate

# Deploy
./scripts/deploy-kong-routes.sh deploy

# Test
./scripts/deploy-kong-routes.sh test /api/your-endpoint
```

**That's it!** ✨

