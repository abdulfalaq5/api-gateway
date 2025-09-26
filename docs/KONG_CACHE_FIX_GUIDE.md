# Kong Cache Issues - Solusi Masalah Cache Docker Kong

## Masalah yang Dihadapi

Ketika menggunakan Kong dalam mode `db-less` dengan file `kong.yml`, terkadang perubahan konfigurasi tidak langsung ter-load karena Kong masih menggunakan cache dari konfigurasi sebelumnya. Hal ini menyebabkan:

- Route baru tidak muncul setelah deployment
- Perubahan konfigurasi tidak ter-apply
- Kong masih menggunakan konfigurasi lama

## Penyebab Masalah

1. **Docker Container Cache**: Kong container menyimpan cache konfigurasi di memory
2. **Network Cache**: Docker networks yang sudah ada mungkin menyimpan informasi routing lama
3. **Volume Cache**: Docker volumes mungkin menyimpan data konfigurasi lama
4. **Restart Tidak Lengkap**: `docker-compose restart` tidak menghapus cache secara menyeluruh

## Solusi yang Tersedia

### 1. Script Kong Config Manager (Diperbarui)

Script `kong-config-manager.sh` sudah diperbarui dengan metode clean restart:

```bash
# Deploy dengan clean restart (direkomendasikan)
./scripts/kong-config-manager.sh deploy-clean

# Deploy biasa (mungkin masih ada masalah cache)
./scripts/kong-config-manager.sh deploy
```

### 2. Script Fix Kong Cache (Baru)

Script khusus untuk mengatasi masalah cache:

```bash
# Clean cache dan restart Kong
./scripts/fix-kong-cache.sh clean-cache

# Deploy dengan cache cleaning
./scripts/fix-kong-cache.sh deploy

# Cek status Kong
./scripts/fix-kong-cache.sh status
```

### 3. Script Quick Kong Cache Fix (Cepat)

Script cepat untuk mengatasi masalah cache:

```bash
# Fix cache dengan cepat
./scripts/quick-kong-cache-fix.sh
```

## Cara Kerja Solusi

### Clean Restart Process:

1. **Stop Kong Container**: Menghentikan container Kong
2. **Remove Container**: Menghapus container Kong sepenuhnya
3. **Clean Networks**: Membersihkan Docker networks
4. **Clean Volumes**: Membersihkan unused volumes
5. **Start Fresh**: Memulai Kong dengan state yang bersih
6. **Health Check**: Memverifikasi Kong sudah sehat
7. **Route Verification**: Memastikan routes sudah ter-load

### Perbedaan dengan Restart Biasa:

| Metode | Container | Networks | Volumes | Cache |
|--------|-----------|----------|---------|-------|
| `docker-compose restart` | ❌ Tidak dihapus | ❌ Tidak dibersihkan | ❌ Tidak dibersihkan | ❌ Masih ada |
| Clean Restart | ✅ Dihapus | ✅ Dibersihkan | ✅ Dibersihkan | ✅ Dihapus |

## Rekomendasi Penggunaan

### Untuk Development:
```bash
# Gunakan quick fix untuk testing cepat
./scripts/quick-kong-cache-fix.sh
```

### Untuk Production:
```bash
# Gunakan deploy-clean untuk deployment yang aman
./scripts/kong-config-manager.sh deploy-clean
```

### Untuk Troubleshooting:
```bash
# Gunakan script khusus untuk debugging
./scripts/fix-kong-cache.sh status
./scripts/fix-kong-cache.sh clean-cache
```

## Monitoring dan Verifikasi

Setelah deployment, selalu verifikasi:

1. **Health Check**: Kong harus healthy
2. **Route Count**: Jumlah routes sesuai dengan konfigurasi
3. **Service Count**: Jumlah services sesuai dengan konfigurasi
4. **Plugin Status**: Plugins ter-load dengan benar

```bash
# Cek status lengkap
curl -s http://localhost:9546/status | jq '.server'

# Cek routes
curl -s http://localhost:9546/routes | jq '.data[].name'

# Cek services
curl -s http://localhost:9546/services | jq '.data[].name'
```

## Troubleshooting

### Jika Masih Ada Masalah:

1. **Cek Kong Logs**:
   ```bash
   docker logs kong-gateway --tail 20
   ```

2. **Cek Konfigurasi File**:
   ```bash
   # Pastikan kong.yml valid
   docker run --rm -v $(pwd)/config/kong.yml:/kong/kong.yml kong:3.4 kong config -c /kong/kong.yml
   ```

3. **Cek Docker Networks**:
   ```bash
   docker network ls
   docker network inspect kong-network
   ```

4. **Force Clean Everything**:
   ```bash
   # Hapus semua container Kong
   docker rm -f $(docker ps -aq --filter "name=kong")
   
   # Hapus semua networks Kong
   docker network rm $(docker network ls -q --filter "name=kong")
   
   # Clean semua unused resources
   docker system prune -f
   ```

## Best Practices

1. **Selalu gunakan `deploy-clean`** untuk deployment production
2. **Backup konfigurasi** sebelum deployment
3. **Monitor logs** setelah deployment
4. **Test endpoints** setelah deployment
5. **Gunakan health checks** untuk monitoring

## Contoh Penggunaan

```bash
# 1. Backup konfigurasi
./scripts/kong-config-manager.sh backup

# 2. Deploy dengan cache cleaning
./scripts/kong-config-manager.sh deploy-clean

# 3. Verifikasi deployment
./scripts/fix-kong-cache.sh status

# 4. Test endpoint
curl -X POST http://localhost:9545/api/auth/sso/login
```

Dengan solusi ini, masalah cache Kong seharusnya sudah teratasi dan deployment akan berjalan lebih smooth.
