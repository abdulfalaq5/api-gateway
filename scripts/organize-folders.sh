#!/bin/bash

# Script untuk mengorganisir struktur folder Kong API Gateway
# File: scripts/organize-folders.sh

echo "📁 Organizing Kong API Gateway Folder Structure"
echo "=============================================="

# Buat folder-folder yang diperlukan
echo "📂 Creating necessary folders..."
mkdir -p backups
mkdir -p docs
mkdir -p logs
mkdir -p plugins
mkdir -p config

# Pindahkan file backup
echo "📦 Moving backup files..."
mv kong_backup_*.json backups/ 2>/dev/null || echo "   No kong_backup files to move"
mv kong_current_config.json backups/ 2>/dev/null || echo "   No kong_current_config.json to move"
mv kong_db_backup_*.json backups/ 2>/dev/null || echo "   No kong_db_backup files to move"
mv kong_export_* backups/ 2>/dev/null || echo "   No kong_export folders to move"

# Pindahkan file dokumentasi
echo "📚 Moving documentation files..."
mv *.md docs/ 2>/dev/null || echo "   No markdown files to move"

# Pindahkan kong.yml ke config folder
echo "⚙️  Moving configuration files..."
mv kong.yml config/ 2>/dev/null || echo "   kong.yml already in config folder"

# Buat README untuk setiap folder
echo "📝 Creating folder READMEs..."

# README untuk backups folder
cat > backups/README.md << 'EOF'
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
EOF

# README untuk docs folder
cat > docs/README.md << 'EOF'
# Documentation Folder

Folder ini berisi semua dokumentasi Kong API Gateway.

## Files:
- `README.md` - Dokumentasi utama
- `KONG_MANUAL_COMMANDS.md` - Panduan command manual Kong
- `KONG_HELPER_GUIDE.md` - Panduan menggunakan kong-helper.sh
- `KONG_MIGRATION_GUIDE.md` - Panduan migrasi Kong
- `KONG_YML_VS_DATABASE.md` - Perbandingan kong.yml vs database mode
- `TUTORIAL_KONG_API_GATEWAY.md` - Tutorial lengkap Kong
- `SERVER_SETUP.md` - Panduan setup server
- `ENVIRONMENT_CONFIG.md` - Konfigurasi environment

## Usage:
Dokumentasi ini membantu dalam:
- Setup Kong API Gateway
- Troubleshooting issues
- Migrasi konfigurasi
- Maintenance dan monitoring
EOF

# README untuk config folder
cat > config/README.md << 'EOF'
# Configuration Folder

Folder ini berisi semua file konfigurasi Kong API Gateway.

## Files:
- `kong.yml` - Konfigurasi declarative Kong (DB-less mode)
- `kong.conf` - Konfigurasi Kong utama
- `env.sh` - Environment variables

## Usage:
Konfigurasi ini digunakan untuk:
- Mengatur Kong API Gateway
- Menentukan services dan routes
- Mengatur plugins dan policies
- Environment-specific settings
EOF

# README untuk logs folder
cat > logs/README.md << 'EOF'
# Logs Folder

Folder ini berisi semua file log Kong API Gateway.

## Usage:
Log files digunakan untuk:
- Monitoring Kong performance
- Troubleshooting issues
- Audit trail
- Debugging problems
EOF

# README untuk plugins folder
cat > plugins/README.md << 'EOF'
# Plugins Folder

Folder ini berisi custom plugins Kong API Gateway.

## Usage:
Custom plugins digunakan untuk:
- Menambah functionality khusus
- Integrasi dengan sistem lain
- Custom authentication
- Custom rate limiting
EOF

echo ""
echo "✅ Folder structure organized!"
echo ""
echo "📁 Current structure:"
echo "├── backups/     - Backup files"
echo "├── config/      - Configuration files"
echo "├── docs/        - Documentation"
echo "├── logs/        - Log files"
echo "├── plugins/     - Custom plugins"
echo "├── scripts/     - Utility scripts"
echo "└── examples/    - Example configurations"
echo ""
echo "📝 Each folder now has its own README.md for reference"
