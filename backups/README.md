# Backups Folder

Folder ini berisi semua file backup Kong API Gateway.

## File Types:
- `kong_backup_*.json` - Backup konfigurasi Kong
- `kong_db_backup_*.json` - Backup database Kong
- `kong_current_config.json` - Konfigurasi Kong saat ini
- `kong_export_*` - Export konfigurasi Kong

## Usage:
Backup files digunakan untuk:
- Rollback konfigurasi
- Migrasi ke server lain
- Troubleshooting issues
