# Kong API Gateway - Environment Configuration

## 🔧 Environment Variables

### Database Configuration
```bash
export DB_HOST_PROD=localhost
export DB_PORT_PROD=5432
export DB_USER_PROD=falaqmsi
export DB_PASS_PROD=Rubysa179596
export DB_NAME_PROD=kong
```

### Kong Configuration
```bash
export KONG_PROXY_PORT=8000
export KONG_ADMIN_PORT=8001
export KONG_ADMIN_GUI_PORT=8002
export KONG_LOG_LEVEL=notice
export KONG_LOG_FILE=/Users/falaqmsi/Documents/GitHub/kong-api-gateway/logs/kong.log
```

### API Keys (untuk testing)
```bash
export API_KEY_USER_SERVICE=sk-1234567890abcdef
export API_KEY_PRODUCT_SERVICE=sk-abcdef1234567890
export API_KEY_ORDER_SERVICE=sk-9876543210fedcba
```

## 📝 Setup Environment

### 1. Load Environment Variables
```bash
# Load environment variables
source config/env.sh
```

### 2. Verify Environment
```bash
# Check database connection
PGPASSWORD=$DB_PASS_PROD psql -h $DB_HOST_PROD -p $DB_PORT_PROD -U $DB_USER_PROD -d $DB_NAME_PROD -c "SELECT version();"

# Check Kong configuration
kong config -c config/kong.conf
```

## 🚀 Production Deployment

### 1. Update Configuration untuk Production
```bash
# Update kong.conf untuk production
sed -i '' 's/localhost/your-production-host/g' config/kong.conf
sed -i '' 's/8000/80/g' config/kong.conf
sed -i '' 's/8001/8001/g' config/kong.conf
```

### 2. Setup SSL/TLS
```bash
# Generate SSL certificates
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes

# Update Kong configuration untuk SSL
echo "ssl_cert = /path/to/cert.pem" >> config/kong.conf
echo "ssl_cert_key = /path/to/key.pem" >> config/kong.conf
```

### 3. Setup Logging
```bash
# Setup log rotation
sudo logrotate -f /etc/logrotate.d/kong
```

## 🔒 Security Configuration

### 1. Firewall Rules
```bash
# Allow Kong ports
sudo ufw allow 8000/tcp
sudo ufw allow 8001/tcp
sudo ufw allow 8002/tcp

# Block direct access to backend services
sudo ufw deny 3001/tcp
sudo ufw deny 3002/tcp
sudo ufw deny 3003/tcp
```

### 2. Database Security
```bash
# Update PostgreSQL configuration
echo "host all all 127.0.0.1/32 md5" >> /etc/postgresql/15/main/pg_hba.conf
echo "listen_addresses = 'localhost'" >> /etc/postgresql/15/main/postgresql.conf
```

## 📊 Monitoring Configuration

### 1. Enable Prometheus
```bash
# Add Prometheus plugin to all services
curl -i -X POST http://localhost:8001/plugins \
  --data "name=prometheus"
```

### 2. Setup Health Checks
```bash
# Add health check plugin
curl -i -X POST http://localhost:8001/services/user-service/plugins \
  --data "name=healthcheck" \
  --data "config.healthy.interval=30" \
  --data "config.unhealthy.interval=10"
```

## 🧪 Testing Environment

### 1. Test Database Connection
```bash
#!/bin/bash
# test-db.sh
PGPASSWORD=$DB_PASS_PROD psql -h $DB_HOST_PROD -p $DB_PORT_PROD -U $DB_USER_PROD -d $DB_NAME_PROD -c "SELECT 'Database connection successful' as status;"
```

### 2. Test Kong Health
```bash
#!/bin/bash
# test-kong-health.sh
curl -s http://localhost:8001/status | jq . 2>/dev/null || echo "Kong health check failed"
```

### 3. Test All Services
```bash
#!/bin/bash
# test-all-services.sh
services=("user-service" "product-service" "order-service")
for service in "${services[@]}"; do
    echo "Testing $service..."
    curl -s http://localhost:8000/api/v1/$service | head -n 1 || echo "Service $service failed"
done
```

## 🔄 Backup dan Restore

### 1. Backup Kong Configuration
```bash
# Backup declarative configuration
cp config/kong.yml config/kong.yml.backup.$(date +%Y%m%d_%H%M%S)

# Backup database
PGPASSWORD=$DB_PASS_PROD pg_dump -h $DB_HOST_PROD -p $DB_PORT_PROD -U $DB_USER_PROD $DB_NAME_PROD > backup/kong_db_$(date +%Y%m%d_%H%M%S).sql
```

### 2. Restore Kong Configuration
```bash
# Restore declarative configuration
kong config db_import config/kong.yml.backup.20240101_120000

# Restore database
PGPASSWORD=$DB_PASS_PROD psql -h $DB_HOST_PROD -p $DB_PORT_PROD -U $DB_USER_PROD $DB_NAME_PROD < backup/kong_db_20240101_120000.sql
```

## 📈 Performance Tuning

### 1. Kong Performance
```bash
# Update Kong configuration untuk performance
echo "nginx_worker_processes = auto" >> config/kong.conf
echo "nginx_worker_connections = 1024" >> config/kong.conf
echo "nginx_keepalive_requests = 1000" >> config/kong.conf
```

### 2. Database Performance
```bash
# Update PostgreSQL configuration
echo "shared_buffers = 256MB" >> /etc/postgresql/15/main/postgresql.conf
echo "effective_cache_size = 1GB" >> /etc/postgresql/15/main/postgresql.conf
echo "work_mem = 4MB" >> /etc/postgresql/15/main/postgresql.conf
```

## 🚨 Troubleshooting

### 1. Common Issues
```bash
# Kong tidak bisa start
kong config -c config/kong.conf

# Database connection error
PGPASSWORD=$DB_PASS_PROD psql -h $DB_HOST_PROD -p $DB_PORT_PROD -U $DB_USER_PROD -d $DB_NAME_PROD -c "SELECT 1;"

# Port sudah digunakan
lsof -i :8000
lsof -i :8001
lsof -i :8002
```

### 2. Log Analysis
```bash
# View Kong logs
tail -f logs/kong.log

# View PostgreSQL logs
tail -f /var/log/postgresql/postgresql-15-main.log

# View system logs
journalctl -u kong -f
```
