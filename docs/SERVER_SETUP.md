# Kong API Gateway - Setup Server Internal

## 🌐 Port yang Perlu Didaftarkan

### Port Utama Kong
| Port | Service | Deskripsi | Akses |
|------|---------|-----------|-------|
| **9545** | Kong Proxy | Port utama untuk akses API | Public/Internal |
| **8001** | Kong Admin API | Management Kong via API | Internal Only |
| **8002** | Kong Admin GUI | Interface web Kong | Internal Only |

### Port Database
| Port | Service | Deskripsi | Akses |
|------|---------|-----------|-------|
| **5432** | PostgreSQL | Database Kong | Internal Only |

### Port Docker (Opsional)
Jika menggunakan Docker, port di atas akan di-mapping dari container ke host.

## 🔒 Rekomendasi Keamanan

### Port yang Boleh Diakses Public:
- ✅ **Port 9545** - Kong Proxy (untuk client mengakses API)

### Port yang Harus Internal Only:
- ❌ **Port 8001** - Kong Admin API (jangan expose ke public!)
- ❌ **Port 8002** - Kong Admin GUI (jangan expose ke public!)
- ❌ **Port 5432** - PostgreSQL Database (jangan expose ke public!)

## 🛡️ Firewall Configuration

### Contoh iptables rules:
```bash
# Allow Kong Proxy (Port 9545) - Public access
iptables -A INPUT -p tcp --dport 9545 -j ACCEPT

# Allow Kong Admin API (Port 8001) - Internal only
iptables -A INPUT -p tcp --dport 8001 -s 192.168.1.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 8001 -s 10.0.0.0/8 -j ACCEPT

# Allow Kong Admin GUI (Port 8002) - Internal only  
iptables -A INPUT -p tcp --dport 8002 -s 192.168.1.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 8002 -s 10.0.0.0/8 -j ACCEPT

# Allow PostgreSQL (Port 5432) - Internal only
iptables -A INPUT -p tcp --dport 5432 -s 192.168.1.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 5432 -s 10.0.0.0/8 -j ACCEPT
```

## 🌍 Network Configuration

### Untuk Akses dari Client External:
```
Client → Server:9545 → Kong Proxy → Backend Services
```

### Untuk Management Internal:
```
Admin → Server:8001 (Admin API) atau Server:8002 (Admin GUI)
```

## 📋 Checklist Setup Server Internal

### 1. Port Registration
- [ ] Port 9545 - Kong Proxy (Public)
- [ ] Port 8001 - Kong Admin API (Internal)
- [ ] Port 8002 - Kong Admin GUI (Internal)
- [ ] Port 5432 - PostgreSQL (Internal)

### 2. Firewall Rules
- [ ] Allow port 9545 untuk semua IP
- [ ] Restrict port 8001 ke internal network
- [ ] Restrict port 8002 ke internal network
- [ ] Restrict port 5432 ke internal network

### 3. DNS/Network
- [ ] Setup domain untuk Kong Proxy (optional)
- [ ] Configure load balancer jika diperlukan
- [ ] Setup SSL/TLS certificates

### 4. Monitoring
- [ ] Setup monitoring untuk port 9545
- [ ] Setup log monitoring
- [ ] Setup health checks

## 🚀 Deployment Commands

### Start Kong di Server:
```bash
# Dengan Docker
./scripts/start-kong-docker.sh

# Atau dengan binary (jika ada)
./scripts/start-kong.sh
```

### Test Connectivity:
```bash
# Test Kong Proxy (dari external)
curl http://your-server-ip:9545/

# Test Admin API (dari internal)
curl http://your-server-ip:8001/

# Test Admin GUI (dari internal)
curl http://your-server-ip:8002/
```

## 🔧 Production Considerations

### 1. Load Balancer
Jika menggunakan load balancer, pastikan:
- Load balancer forward ke port 9545
- Health check endpoint: `http://server:9545/`

### 2. SSL/TLS
- Setup SSL certificate untuk port 9545
- Redirect HTTP ke HTTPS
- Update Kong configuration untuk SSL

### 3. High Availability
- Setup multiple Kong instances
- Use shared database
- Configure load balancer untuk failover

## 📞 Support
Jika mengalami masalah dengan port configuration:
1. Cek firewall rules
2. Verify port binding dengan `netstat -tlnp`
3. Check Kong logs: `docker-compose logs kong`
4. Test connectivity dengan `telnet server-ip port`
