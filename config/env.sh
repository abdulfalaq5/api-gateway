# Environment Configuration untuk Kong API Gateway
# File: config/env.sh

# SSO Service Configuration
# Sesuaikan dengan environment yang digunakan

# Untuk development lokal
# SSO_UPSTREAM_URL="http://localhost:9588"

# Untuk menggunakan API gateway langsung
# SSO_UPSTREAM_URL="https://api-gate.motorsights.com"

# Untuk Docker environment
# SSO_UPSTREAM_URL="http://host.docker.internal:9588"

# Untuk production
SSO_UPSTREAM_URL="https://api-gate.motorsights.com"

# Database Configuration
DB_HOST="host.docker.internal"
DB_PORT="5432"
DB_USER="falaqmsi"
DB_PASSWORD="Rubysa179596"
DB_NAME="kong"

# Kong Configuration
KONG_PROXY_PORT="9545"
KONG_ADMIN_PORT="9546"
KONG_ADMIN_GUI_PORT="9547"

# Timeout Configuration (dalam milliseconds)
CONNECT_TIMEOUT="60000"
WRITE_TIMEOUT="60000"
READ_TIMEOUT="60000"

# Rate Limiting
RATE_LIMIT_MINUTE="100"
RATE_LIMIT_HOUR="1000"

# CORS Configuration
CORS_ORIGINS="*"
CORS_METHODS="GET,POST,PUT,DELETE,OPTIONS"
CORS_HEADERS="Accept,Accept-Version,Content-Length,Content-MD5,Content-Type,Date,Authorization,X-Auth-Token"
CORS_EXPOSED_HEADERS="X-Auth-Token,Authorization"
CORS_CREDENTIALS="true"
CORS_MAX_AGE="3600"