# 🚀 Kong API Gateway - Deployment Guide

Quick reference untuk deploy dan manage Kong API Gateway.

## 📋 Table of Contents

- [Quick Commands](#quick-commands)
- [Update Routes](#update-routes)
- [Network Configuration](#network-configuration)
- [Troubleshooting](#troubleshooting)

---

## ⚡ Quick Commands

### Deploy Kong Configuration

```bash
# Deploy perubahan kong.yml ke server
./scripts/deploy-kong-routes.sh deploy

# Pull kong.yml dari server ke local
./scripts/deploy-kong-routes.sh pull

# Check status Kong
./scripts/deploy-kong-routes.sh status

# Test route
./scripts/deploy-kong-routes.sh test /api/your-endpoint
```

### Check Logs

```bash
# Di server
ssh msiserver@162.11.0.232
docker logs kong-gateway --tail 50 -f
```

---

## 🔄 Update Routes

### Tambah Route Baru

1. **Edit `config/kong.yml`**
   ```yaml
   services:
     - name: your-service
       url: http://localhost:9550    # ⚠️ MUST use localhost (not host.docker.internal)
       routes:
         - name: your-route
           paths:
             - /api/your-endpoint
           methods:
             - GET
             - POST
           strip_path: false
   ```

2. **Deploy**
   ```bash
   ./scripts/deploy-kong-routes.sh validate
   ./scripts/deploy-kong-routes.sh deploy
   ```

3. **Test**
   ```bash
   ./scripts/deploy-kong-routes.sh test /api/your-endpoint
   ```

---

## 🌐 Network Configuration

### ⚠️ PENTING: Network Mode Configuration

Kong menggunakan **`network_mode: host`** untuk menghindari IPv6 connection issues.

**✅ Correct Configuration:**

```yaml
# config/kong.yml
services:
  - name: backend-service
    url: http://localhost:9550    # ✅ Use localhost
```

**❌ Wrong Configuration:**

```yaml
# config/kong.yml
services:
  - name: backend-service
    url: http://host.docker.internal:9550    # ❌ Won't work with host network mode
```

### Kenapa Pakai `localhost`?

Backend services bind ke IPv6 (`:::9550`), Kong dengan `network_mode: host` bisa akses via `localhost` yang support IPv4 dan IPv6.

**Verification:**

```bash
# Check backend port bindings
sudo netstat -tlnp | grep -E '9518|9550|9502|9544'

# Should show:
# tcp6  :::9550  LISTEN    # IPv6 binding
```

---

## 🔧 Troubleshooting

### Issue: Request Timeout / Hang

**Symptom:** Request via Kong timeout atau hang.

**Cause:** Backend service tidak bisa diakses dari Kong.

**Solution:**

```bash
# 1. Check backend service running
sudo netstat -tlnp | grep 9550

# 2. Test backend langsung
curl -v http://localhost:9550/api/endpoint

# 3. Check Kong logs
docker logs kong-gateway --tail 50

# 4. Verify network mode
docker inspect kong-gateway | jq '.[0].HostConfig.NetworkMode'
# Should return: "host"

# 5. Restart Kong jika perlu
docker restart kong-gateway
```

### Issue: 404 No Route Matched

**Symptom:** `{"message":"no Route matched with those values"}`

**Cause:** Route path tidak sesuai atau belum terdaftar.

**Solution:**

```bash
# Check registered routes
./scripts/deploy-kong-routes.sh status

# Or check di server
curl -s http://localhost:9546/routes | jq '.data[].name'

# Test dengan path yang benar
./scripts/deploy-kong-routes.sh test /api/correct-path
```

### Issue: YAML Syntax Error

**Symptom:** Deployment failed dengan error YAML.

**Solution:**

```bash
# Validate YAML
python3 -c "import yaml; yaml.safe_load(open('config/kong.yml'))"

# Common issues:
# - Wrong indentation (use 2 spaces)
# - Missing quotes on special characters
# - Duplicate keys
```

---

## 📚 Documentation

Untuk dokumentasi lengkap, lihat:

- **[KONG_DEPLOYMENT_WORKFLOW.md](docs/KONG_DEPLOYMENT_WORKFLOW.md)** - Workflow lengkap dan best practices
- **[DOCKER_DEVELOPMENT_SETUP.md](docs/DOCKER_DEVELOPMENT_SETUP.md)** - Setup development environment
- **[KONG_MANUAL_COMMANDS.md](docs/KONG_MANUAL_COMMANDS.md)** - Manual commands reference

---

## 🎯 Best Practices

### 1. Selalu Validate Sebelum Deploy

```bash
./scripts/deploy-kong-routes.sh validate
./scripts/deploy-kong-routes.sh deploy
```

### 2. Check Diff untuk Production

```bash
./scripts/deploy-kong-routes.sh diff
./scripts/deploy-kong-routes.sh deploy
```

### 3. Test After Deploy

```bash
./scripts/deploy-kong-routes.sh deploy
./scripts/deploy-kong-routes.sh test /api/endpoint
```

### 4. Git Workflow

```bash
git checkout -b feature/new-route
vim config/kong.yml
git add config/kong.yml
git commit -m "Add route for XYZ"
./scripts/deploy-kong-routes.sh deploy
git push origin feature/new-route
```

---

## 🆘 Emergency Rollback

```bash
# 1. SSH to server
ssh msiserver@162.11.0.232
cd ~/MSI/api-gateway

# 2. Restore backup
ls -lt config/kong.yml.backup.*
cp config/kong.yml.backup.TIMESTAMP config/kong.yml

# 3. Restart Kong
docker restart kong-gateway
```

---

## 📞 Quick Reference

| Task | Command |
|------|---------|
| Deploy routes | `./scripts/deploy-kong-routes.sh deploy` |
| Check status | `./scripts/deploy-kong-routes.sh status` |
| Test route | `./scripts/deploy-kong-routes.sh test /api/path` |
| Pull from server | `./scripts/deploy-kong-routes.sh pull` |
| Show diff | `./scripts/deploy-kong-routes.sh diff` |
| Validate YAML | `./scripts/deploy-kong-routes.sh validate` |

---

## ✅ Checklist untuk Avoid Issues

- [ ] Service URL menggunakan `localhost:PORT` (bukan `host.docker.internal`)
- [ ] YAML syntax valid (indentation, quotes, dll)
- [ ] Route paths unique dan tidak overlap
- [ ] Validate sebelum deploy
- [ ] Test setelah deploy
- [ ] Backup tersedia (otomatis oleh script)
- [ ] Git commit untuk track changes

---

**Last Updated:** October 2025  
**Deployment Mode:** `network_mode: host`  
**Kong Version:** 3.4

