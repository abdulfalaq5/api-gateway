#!/bin/sh
# Script untuk mengganti variabel environment di kong.yml dan menjalankan Kong

# Pastikan file konfigurasi ada
if [ ! -f /kong/kong.yml ]; then
    echo "Error: /kong/kong.yml not found"
    exit 1
fi

# Ganti placeholder ${JWT_SECRET} dengan isi variabel environment JWT_SECRET
# Menggunakan temp file untuk menghindari masalah permission/rewrite
sed "s|\${JWT_SECRET}|${JWT_SECRET}|g" /kong/kong.yml > /tmp/kong_configured.yml

# Cek hasil replace
if grep -q "\${JWT_SECRET}" /tmp/kong_configured.yml; then
    echo "Warning: JWT_SECRET replacement failed or placeholder still exists."
fi

# Jalankan entrypoint asli Kong
exec /docker-entrypoint.sh kong docker-start
