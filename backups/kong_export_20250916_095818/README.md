# Kong Configuration Export

Export dibuat pada: Tue Sep 16 09:58:19 WIB 2025

## Files:
- `kong.yml` - Declarative configuration untuk Kong
- `services.json` - Services backup
- `routes.json` - Routes backup  
- `plugins.json` - Plugins backup
- `full_config.json` - Full Kong configuration
- `deploy-to-new-server.sh` - Script untuk deploy ke server baru

## Cara Deploy ke Server Baru:

1. Copy semua files ke server baru
2. Jalankan script deploy:
   ```bash
   ./deploy-to-new-server.sh
   ```

3. Atau deploy manual:
   ```bash
   curl -X POST http://localhost:9546/config -F "config=@kong.yml"
   ```

## Verifikasi:
```bash
# Cek services
curl http://localhost:9546/services/ | jq

# Cek routes  
curl http://localhost:9546/routes/ | jq

# Test endpoint
curl http://localhost:9545/api/your-endpoint
```
