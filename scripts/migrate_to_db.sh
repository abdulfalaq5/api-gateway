#!/bin/bash

# Exit on error
set -e

echo "Starting migration process from DB-less to DB mode..."

# 1. Start Postgres Database
echo "Starting Postgres database..."
docker-compose up -d postgres

# 2. Wait for Postgres to be ready
echo "Waiting for Postgres to be ready..."
until docker-compose exec -T postgres pg_isready -U kong; do
  echo "Waiting for postgres..."
  sleep 2
done
echo "Postgres is ready."

# 3. Bootstrap Migrations
echo "Bootstrapping Kong migrations..."
docker-compose run --rm kong kong migrations bootstrap

# 4. Apply Migrations
echo "Applying Kong migrations..."
docker-compose run --rm kong kong migrations up

# 5. Import Config (with variable substitution)
echo "Importing configuration from /kong/config/kong.yml..."
# We use sed to replace ${JWT_SECRET} with the actual env var value inside the container.
# The container has access to JWT_SECRET via the env_file directive in docker-compose.yml.
docker-compose run --rm kong sh -c '
if [ -z "$JWT_SECRET" ]; then
  echo "Error: JWT_SECRET environment variable is not set."
  exit 1
fi
sed "s|\${JWT_SECRET}|$JWT_SECRET|g" /kong/config/kong.yml > /tmp/kong_import.yml
echo "Config substituted. Importing to database..."
kong config db_import /tmp/kong_import.yml
'

echo "Data import completed."

# 6. Restart everything to ensure fresh start
echo "Restarting services..."
docker-compose down
docker-compose up -d

echo "Migration successfully completed! Kong is now running in Database Mode."
