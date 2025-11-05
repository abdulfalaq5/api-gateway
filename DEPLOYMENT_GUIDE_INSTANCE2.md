# 🚀 Kong API Gateway - Deployment Guide (Instance 2)

Quick reference untuk deploy dan manage Kong API Gateway **Instance 2** (port berbeda).

## 📋 Perbedaan Instance 1 vs Instance 2

| Item | Instance 1 | Instance 2 |
|------|-----------|-----------|
| **Container Name** | `kong-gateway` | `kong-gateway2` |
| **Proxy Port** | 9545 | **9588** |
| **Admin Port** | 9546 | **9589** |
| **Admin GUI Port** | 9547 | **9590** |
| **Docker Compose** | `docker-compose.server.yml` | `docker-compose.server2.yml` |
| **Deploy Script** | `deploy-kong-routes.sh` | `deploy-kong-routes2.sh` |

## ⚡ Quick Commands (Instance 2)

### Deploy Kong Configuration

```bash
# Validate konfigurasi
./scripts/deploy-kong-routes2.sh validate

# Deploy perubahan kong.yml ke server (Instance 2)
./scripts/deploy-kong-routes2.sh deploy

# Check status Kong Instance 2
./scripts/deploy-kong-routes2.sh status

# Test route
./scripts/deploy-kong-routes2.sh test /api/your-endpoint
```

### Start/Stop Kong Instance 2

```bash
# Di server
ssh msiserver@162.11.0.232
cd ~/MSI/api-gateway

# Start Kong Instance 2
docker-compose -f docker-compose.server2.yml up -d

# Stop Kong Instance 2
docker-compose -f docker-compose.server2.yml down

# Restart Kong Instance 2
docker-compose -f docker-compose.server2.yml restart kong

# Check status
docker-compose -f docker-compose.server2.yml ps
```

### Check Logs

```bash
# Di server
ssh msiserver@162.11.0.232
docker logs kong-gateway2 --tail 50 -f
```

## 🔄 Workflow Deployment (Instance 2)

### 1. Edit kong.yml
```bash
vim config/kong.yml
```

### 2. Validate
```bash
./scripts/deploy-kong-routes2.sh validate
```

### 3. Deploy
```bash
./scripts/deploy-kong-routes2.sh deploy
```

### 4. Test
```bash
# Test via proxy port 9588
curl -v http://localhost:9588/api/your-endpoint
```

## 🌐 Endpoints (Instance 2)

| Service | URL | Port |
|---------|-----|------|
| **Kong Proxy** | `http://localhost:9588` | 9588 |
| **Kong Admin API** | `http://localhost:9589` | 9589 |
| **Kong Admin GUI** | `http://localhost:9590` | 9590 |

## 🔧 Troubleshooting

### Check Kong Instance 2 Status
```bash
# Check container
docker ps | grep kong-gateway2

# Check health
curl http://localhost:9589/status

# Check routes
curl http://localhost:9589/routes | jq '.'
```

### Restart Kong Instance 2
```bash
docker-compose -f docker-compose.server2.yml restart kong
```

### View Logs
```bash
docker logs kong-gateway2 --tail 50 -f
```

## ⚠️ Important Notes

1. **Port Conflicts**: Pastikan port 9588, 9589, 9590 tidak digunakan aplikasi lain
2. **Network Mode**: Instance 2 juga menggunakan `network_mode: host` seperti Instance 1
3. **Config File**: Kedua instance menggunakan file `config/kong.yml` yang sama
4. **Container Name**: Container name berbeda (`kong-gateway2`) untuk menghindari konflik

## 📚 Related Documentation

- **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - Dokumentasi untuk Instance 1
- **[docs/KONG_DEPLOYMENT_WORKFLOW.md](docs/KONG_DEPLOYMENT_WORKFLOW.md)** - Workflow lengkap

---

**Last Updated:** October 2025  
**Instance:** Kong Gateway Instance 2  
**Ports:** 9588 (Proxy), 9589 (Admin), 9590 (Admin GUI)
