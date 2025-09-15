#!/bin/bash

# Script untuk setup database Kong di PostgreSQL yang sudah ada

set -e

echo "🗄️  Kong Database Setup Script"
echo "==============================="

# Default values
DB_HOST="localhost"
DB_PORT="5432"
DB_USER="postgres"
DB_PASSWORD=""
KONG_DB_NAME="kong"
KONG_DB_USER="kong"
KONG_DB_PASSWORD=""

# Function untuk input password secara aman
read_password() {
    local prompt="$1"
    local var_name="$2"
    
    echo -n "$prompt: "
    read -s password
    echo
    eval "$var_name='$password'"
}

# Function untuk test koneksi database
test_db_connection() {
    local host=$1
    local port=$2
    local user=$3
    local password=$4
    local db=$5
    
    echo "🔍 Testing database connection..."
    
    if [ -n "$password" ]; then
        export PGPASSWORD="$password"
    fi
    
    if psql -h "$host" -p "$port" -U "$user" -d "$db" -c "SELECT 1;" > /dev/null 2>&1; then
        echo "✅ Database connection successful"
        return 0
    else
        echo "❌ Database connection failed"
        return 1
    fi
}

# Function untuk buat database Kong
create_kong_database() {
    local host=$1
    local port=$2
    local user=$3
    local password=$4
    local kong_db=$5
    local kong_user=$6
    local kong_password=$7
    
    echo "🗄️  Creating Kong database..."
    
    if [ -n "$password" ]; then
        export PGPASSWORD="$password"
    fi
    
    # Buat database kong
    psql -h "$host" -p "$port" -U "$user" -d postgres -c "CREATE DATABASE $kong_db;" 2>/dev/null || echo "   Database $kong_db already exists"
    
    # Buat user kong
    psql -h "$host" -p "$port" -U "$user" -d postgres -c "CREATE USER $kong_user WITH PASSWORD '$kong_password';" 2>/dev/null || echo "   User $kong_user already exists"
    
    # Berikan hak akses
    psql -h "$host" -p "$port" -U "$user" -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE $kong_db TO $kong_user;"
    
    echo "✅ Kong database setup completed"
}

# Function untuk test koneksi Kong database
test_kong_db_connection() {
    local host=$1
    local port=$2
    local user=$3
    local password=$4
    local db=$5
    
    echo "🔍 Testing Kong database connection..."
    
    export PGPASSWORD="$password"
    
    if psql -h "$host" -p "$port" -U "$user" -d "$db" -c "SELECT version();" > /dev/null 2>&1; then
        echo "✅ Kong database connection successful"
        return 0
    else
        echo "❌ Kong database connection failed"
        return 1
    fi
}

# Main execution
echo "📋 Kong Database Setup"
echo ""

# Input database configuration
echo "🔧 Database Configuration:"
echo ""

read -p "Database Host [$DB_HOST]: " input_host
DB_HOST=${input_host:-$DB_HOST}

read -p "Database Port [$DB_PORT]: " input_port
DB_PORT=${input_port:-$DB_PORT}

read -p "Database Admin User [$DB_USER]: " input_user
DB_USER=${input_user:-$DB_USER}

read_password "Database Admin Password" DB_PASSWORD

echo ""
echo "🔧 Kong Database Configuration:"
echo ""

read -p "Kong Database Name [$KONG_DB_NAME]: " input_kong_db
KONG_DB_NAME=${input_kong_db:-$KONG_DB_NAME}

read -p "Kong Database User [$KONG_DB_USER]: " input_kong_user
KONG_DB_USER=${input_kong_user:-$KONG_DB_USER}

read_password "Kong Database Password" KONG_DB_PASSWORD

echo ""
echo "📋 Configuration Summary:"
echo "   Database Host: $DB_HOST"
echo "   Database Port: $DB_PORT"
echo "   Admin User: $DB_USER"
echo "   Kong Database: $KONG_DB_NAME"
echo "   Kong User: $KONG_DB_USER"
echo ""

read -p "Continue with this configuration? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Setup cancelled"
    exit 1
fi

# Test admin connection
if ! test_db_connection "$DB_HOST" "$DB_PORT" "$DB_USER" "$DB_PASSWORD" "postgres"; then
    echo "❌ Cannot connect to PostgreSQL as admin user"
    echo "   Please check your credentials and ensure PostgreSQL is running"
    exit 1
fi

# Create Kong database
create_kong_database "$DB_HOST" "$DB_PORT" "$DB_USER" "$DB_PASSWORD" "$KONG_DB_NAME" "$KONG_DB_USER" "$KONG_DB_PASSWORD"

# Test Kong database connection
if ! test_kong_db_connection "$DB_HOST" "$DB_PORT" "$KONG_DB_USER" "$KONG_DB_PASSWORD" "$KONG_DB_NAME"; then
    echo "❌ Cannot connect to Kong database"
    exit 1
fi

echo ""
echo "✅ Kong database setup completed successfully!"
echo ""
echo "📋 Database Information for Kong Configuration:"
echo "   KONG_PG_HOST: $DB_HOST"
echo "   KONG_PG_PORT: $DB_PORT"
echo "   KONG_PG_USER: $KONG_DB_USER"
echo "   KONG_PG_PASSWORD: $KONG_DB_PASSWORD"
echo "   KONG_PG_DATABASE: $KONG_DB_NAME"
echo ""
echo "🔧 Next Steps:"
echo "   1. Update docker-compose.yml with these database settings"
echo "   2. Run Kong migrations: docker-compose up kong-migrations"
echo "   3. Start Kong: docker-compose up -d kong"
echo ""

# Generate environment file
cat > .env << EOF
# Kong Database Configuration
KONG_PG_HOST=$DB_HOST
KONG_PG_PORT=$DB_PORT
KONG_PG_USER=$KONG_DB_USER
KONG_PG_PASSWORD=$KONG_DB_PASSWORD
KONG_PG_DATABASE=$KONG_DB_NAME
EOF

echo "📄 Database configuration saved to .env file"
echo "   You can source this file: source .env"
