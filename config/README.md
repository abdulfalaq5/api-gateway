# Configuration Folder

Folder ini berisi semua file konfigurasi Kong API Gateway.

## Files:
- `kong.yml` - Konfigurasi declarative Kong (DB-less mode)
- `kong.conf` - Konfigurasi Kong utama
- `env.sh` - Environment variables
- `resolv.conf` - Custom DNS resolver configuration (8.8.8.8, 8.8.4.4, 1.1.1.1)

## Usage:
Konfigurasi ini digunakan untuk:
- Mengatur Kong API Gateway
- Menentukan services dan routes
- Mengatur plugins dan policies
- Environment-specific settings

## DNS Configuration:
File `resolv.conf` digunakan untuk:
- Bypass Docker internal DNS resolver (127.0.0.11)
- Force Kong menggunakan DNS publik yang reliable
- Mencegah DNS resolution timeout issues
- DNS servers yang digunakan:
  - 8.8.8.8 (Google DNS Primary)
  - 8.8.4.4 (Google DNS Secondary)
  - 1.1.1.1 (Cloudflare DNS)
