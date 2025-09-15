# Kong API Gateway Setup Guide

## 📋 Deskripsi
Dokumentasi ini menjelaskan cara setup Kong API Gateway tanpa Docker di macOS dengan PostgreSQL sebagai database.

## 🏗️ Struktur Folder
```
kong-api-gateway/
├── config/
│   ├── kong.conf          # Konfigurasi utama Kong
│   └── kong.yml           # Konfigurasi declarative
├── scripts/
│   ├── install-kong.sh    # Script instalasi Kong
│   ├── start-kong.sh      # Script menjalankan Kong
│   ├── stop-kong.sh       # Script menghentikan Kong
│   └── status-kong.sh     # Script cek status Kong
├── logs/                  # Folder untuk log Kong
├── plugins/               # Folder untuk custom plugins
└── README.md              # Dokumentasi ini
```

## 🔧 Prerequisites
- macOS (tested on macOS 14.6.0)
- Homebrew package manager
- PostgreSQL 15+
- Kong 3.0+

## 🚀 Instalasi

### 1. Install Homebrew (jika belum ada)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Install Kong dan PostgreSQL
```bash
# Jalankan script instalasi
./scripts/install-kong.sh
```

Script ini akan:
- Install PostgreSQL 15 via Homebrew
- Install Kong via Homebrew
- Setup database Kong
- Menjalankan migrasi database

### 3. Verifikasi Instalasi
```bash
# Cek status Kong
./scripts/status-kong.sh

# Cek versi Kong
kong version

# Cek status PostgreSQL
pg_isready -h localhost -p 5432 -U falaqmsi
```

## 🎮 Penggunaan

### Menjalankan Kong
```bash
./scripts/start-kong.sh
```

### Menghentikan Kong
```bash
./scripts/stop-kong.sh
```

### Cek Status Kong
```bash
./scripts/status-kong.sh
```

## 🌐 Endpoints

Setelah Kong berjalan, endpoint berikut akan tersedia:

- **Kong Proxy**: http://localhost:9545
- **Kong Admin API**: http://localhost:8001
- **Kong Admin GUI**: http://localhost:8002

## 🗄️ Database Configuration

Kong menggunakan PostgreSQL dengan konfigurasi berikut:
- **Host**: localhost
- **Port**: 5432
- **User**: falaqmsi
- **Password**: Rubysa179596
- **Database**: kong

## 📝 Konfigurasi Kong

### File Konfigurasi Utama (`config/kong.conf`)
```ini
# Database configuration
database = postgres
pg_host = localhost
pg_port = 5432
pg_user = falaqmsi
pg_password = Rubysa179596
pg_database = kong

# Kong configuration
proxy_listen = 0.0.0.0:9545
admin_listen = 0.0.0.0:8001
admin_gui_listen = 0.0.0.0:8002

# Logging
log_level = notice
log_file = /Users/falaqmsi/Documents/GitHub/kong-api-gateway/logs/kong.log
```

### File Konfigurasi Declarative (`config/kong.yml`)
File ini berisi konfigurasi services, routes, dan plugins dalam format YAML.

## 🔌 Plugins yang Tersedia

Kong dikonfigurasi dengan plugin berikut:
- **CORS**: Cross-Origin Resource Sharing
- **Rate Limiting**: Pembatasan rate request
- **JWT**: JSON Web Token authentication
- **Key Auth**: API Key authentication
- **Basic Auth**: Basic authentication
- **OAuth2**: OAuth2 authentication
- **Request/Response Transformer**: Transformasi request/response

## 🧪 Testing Kong

### Test Admin API
```bash
curl http://localhost:8001/
```

### Test Kong Proxy
```bash
curl http://localhost:9545/
```

### Test dengan Service
```bash
# Tambahkan service
curl -i -X POST http://localhost:8001/services/ \
  --data "name=example-service" \
  --data "url=http://httpbin.org"

# Tambahkan route
curl -i -X POST http://localhost:8001/services/example-service/routes \
  --data "paths[]=/test"

# Test route
curl -i http://localhost:9545/test
```

## 🛠️ Troubleshooting

### Kong tidak bisa start
1. Cek apakah PostgreSQL berjalan:
   ```bash
   pg_isready -h localhost -p 5432 -U falaqmsi
   ```

2. Cek log Kong:
   ```bash
   tail -f logs/kong.log
   ```

3. Cek konfigurasi Kong:
   ```bash
   kong config -c config/kong.conf
   ```

### Database connection error
1. Pastikan PostgreSQL berjalan:
   ```bash
   brew services start postgresql@15
   ```

2. Cek koneksi database:
   ```bash
   PGPASSWORD=Rubysa179596 psql -h localhost -p 5432 -U falaqmsi -d kong
   ```

### Port sudah digunakan
1. Cek port yang digunakan:
   ```bash
   lsof -i :9545
   lsof -i :8001
   lsof -i :8002
   ```

2. Ubah port di `config/kong.conf` jika diperlukan

## 📚 Referensi

- [Kong Documentation](https://docs.konghq.com/)
- [Kong Admin API](https://docs.konghq.com/gateway/latest/admin-api/)
- [Kong Plugins](https://docs.konghq.com/hub/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

## 🤝 Support

Jika mengalami masalah, silakan:
1. Cek log Kong di folder `logs/`
2. Pastikan semua prerequisites terpenuhi
3. Verifikasi konfigurasi database
4. Cek dokumentasi Kong resmi

## 📄 License

Proyek ini menggunakan Kong yang berlisensi Apache 2.0.
