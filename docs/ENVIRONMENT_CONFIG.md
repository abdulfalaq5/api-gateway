# Kong API Gateway - Konfigurasi Lokal vs Server

## 📋 Overview

Proyek ini memiliki konfigurasi terpisah untuk environment lokal dan server internal.

## 🏠 Konfigurasi Lokal (Development)

### Database Configuration:
- **Host**: `host.docker.internal` (PostgreSQL lokal)
- **Port**: `5432`
- **User**: `falaqmsi`
- **Password**: `Rubysa179596`
- **Database**: `kong`

### File Konfigurasi:
- `docker-compose.local.yml` - Konfigurasi untuk development lokal
- `docker-compose.yml` - File aktif (akan di-copy dari local.yml)

### Script untuk Lokal:
```bash
# Start Kong di lokal
./scripts/start-kong-local.sh

# Switch ke konfigurasi lokal
./scripts/switch-kong-config.sh local
```

## 🖥️ Konfigurasi Server (Production)

### Database Configuration:
- **Host**: `162.11.0.232` (Server internal PostgreSQL)
- **Port**: `5432`
- **User**: `sharedpg`
- **Password**: `pgpass`
- **Database**: `kong`

### File Konfigurasi:
- `docker-compose.server.yml` - Konfigurasi untuk server internal
- `docker-compose.yml` - File aktif (akan di-copy dari server.yml)

### Script untuk Server:
```bash
# Start Kong di server
./scripts/start-kong-server.sh

# Switch ke konfigurasi server
./scripts/switch-kong-config.sh server
```

## 🔄 Switching Environment

### Manual Switch:
```bash
# Switch ke lokal
./scripts/switch-kong-config.sh local

# Switch ke server
./scripts/switch-kong-config.sh server
```

### Manual Copy:
```bash
# Copy konfigurasi lokal
cp docker-compose.local.yml docker-compose.yml

# Copy konfigurasi server
cp docker-compose.server.yml docker-compose.yml
```

## 🚀 Quick Start

### Untuk Development Lokal:
```bash
# 1. Pastikan PostgreSQL lokal berjalan
# 2. Start Kong
./scripts/start-kong-local.sh

# 3. Deploy konfigurasi
./scripts/deploy-kong-config-db.sh

# 4. Test
curl http://localhost:9545/
```

### Untuk Server Internal:
```bash
# 1. Pastikan koneksi ke database server OK
# 2. Start Kong
./scripts/start-kong-server.sh

# 3. Deploy konfigurasi
./scripts/deploy-kong-config-db.sh

# 4. Test
curl http://localhost:9545/
```

## 📝 Perbedaan Utama

| Aspek | Lokal | Server |
|-------|-------|--------|
| Database Host | `host.docker.internal` | `162.11.0.232` |
| Database User | `falaqmsi` | `sharedpg` |
| Database Password | `Rubysa179596` | `pgpass` |
| Network | Docker internal | External network |
| Use Case | Development | Production |

## 🔧 Troubleshooting

### Lokal:
- Pastikan PostgreSQL lokal berjalan
- Cek Docker Desktop running
- Cek port 5432 tidak conflict

### Server:
- Cek koneksi ke `162.11.0.232:5432`
- Cek firewall rules
- Cek credentials database

## 📚 Scripts Available

- `./scripts/start-kong-local.sh` - Start Kong di lokal
- `./scripts/start-kong-server.sh` - Start Kong di server
- `./scripts/switch-kong-config.sh` - Switch konfigurasi
- `./scripts/deploy-kong-config-db.sh` - Deploy konfigurasi Kong
- `./scripts/status-kong-config.sh` - Cek status Kong
