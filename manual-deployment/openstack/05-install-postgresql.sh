#!/bin/bash
set -e

# ========================================
# PostgreSQL Installation on OpenStack
# ========================================

echo "=========================================="
echo "🗄️  Installing PostgreSQL Database"
echo "=========================================="

# Load IPs
source /tmp/foodhub-ips.sh

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_green() { echo -e "${GREEN}✅ $1${NC}"; }
print_blue() { echo -e "${BLUE}ℹ️  $1${NC}"; }

PG_PASSWORD="foodhub_password_change_me"
REPL_PASSWORD="replication_password_change_me"

echo ""
print_blue "Installing PostgreSQL on: ${PG_IP}"

# Create installation script
cat > /tmp/install-postgresql.sh <<'POSTGRES_SCRIPT'
#!/bin/bash
set -e

echo "Installing PostgreSQL..."

# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install PostgreSQL 15
sudo apt-get install -y postgresql-15 postgresql-contrib-15

# Configure PostgreSQL
echo "Configuring PostgreSQL..."

# Update postgresql.conf
sudo tee -a /etc/postgresql/15/main/postgresql.conf > /dev/null <<EOF

# FoodHub Configuration
listen_addresses = '*'
wal_level = replica
max_wal_senders = 10
wal_keep_size = 1GB
hot_standby = on
archive_mode = on
archive_command = 'test ! -f /var/lib/postgresql/15/archive/%f && cp %p /var/lib/postgresql/15/archive/%f'
EOF

# Create archive directory
sudo mkdir -p /var/lib/postgresql/15/archive
sudo chown -R postgres:postgres /var/lib/postgresql/15/archive

# Update pg_hba.conf
sudo tee -a /etc/postgresql/15/main/pg_hba.conf > /dev/null <<EOF

# FoodHub access
host    all             all             10.0.0.0/16             md5
host    all             all             10.1.0.0/16             md5
host    replication     replicator      10.1.0.0/16             md5
EOF

# Restart PostgreSQL
sudo systemctl restart postgresql

# Create databases and users
echo "Creating databases and users..."
sudo -u postgres psql <<SQL
CREATE DATABASE foodhub_users;
CREATE DATABASE foodhub_products;
CREATE DATABASE foodhub_orders;

CREATE USER foodhub_user WITH ENCRYPTED PASSWORD 'PG_PASSWORD_PLACEHOLDER';
GRANT ALL PRIVILEGES ON DATABASE foodhub_users TO foodhub_user;
GRANT ALL PRIVILEGES ON DATABASE foodhub_products TO foodhub_user;
GRANT ALL PRIVILEGES ON DATABASE foodhub_orders TO foodhub_user;

-- Create replication user
CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD 'REPL_PASSWORD_PLACEHOLDER';
SQL

echo "✅ PostgreSQL installed and configured"

POSTGRES_SCRIPT

# Replace placeholders
sed -i "s/PG_PASSWORD_PLACEHOLDER/${PG_PASSWORD}/" /tmp/install-postgresql.sh
sed -i "s/REPL_PASSWORD_PLACEHOLDER/${REPL_PASSWORD}/" /tmp/install-postgresql.sh

# Copy and execute
print_blue "Copying installation script..."
scp -o StrictHostKeyChecking=no -i ${SSH_KEY} /tmp/install-postgresql.sh ubuntu@${PG_IP}:/tmp/

print_blue "Installing PostgreSQL (this may take 5 minutes)..."
ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${PG_IP} "bash /tmp/install-postgresql.sh"

print_green "PostgreSQL installation complete"

# Test connection
print_blue "Testing database connection..."
sleep 5

if ssh -i ${SSH_KEY} ubuntu@${PG_IP} "PGPASSWORD=${PG_PASSWORD} psql -h localhost -U foodhub_user -d foodhub_users -c 'SELECT version();'" > /dev/null 2>&1; then
    print_green "Database connection successful"
else
    echo "⚠️  Database connection test failed"
fi

# ========================================
# Summary
# ========================================

echo ""
echo "=========================================="
echo "🎉 PostgreSQL Installation Complete!"
echo "=========================================="
echo ""
echo "📋 Database Info:"
echo "  Host:      ${PG_IP}"
echo "  Port:      5432"
echo "  User:      foodhub_user"
echo "  Password:  ${PG_PASSWORD}"
echo ""
echo "📊 Databases:"
echo "  - foodhub_users"
echo "  - foodhub_products"
echo "  - foodhub_orders"
echo ""
echo "🔗 Connection string:"
echo "  postgresql://foodhub_user:${PG_PASSWORD}@${PG_IP}:5432/foodhub_users"
echo ""
echo "🔍 Test connection:"
echo "  psql -h ${PG_IP} -U foodhub_user -d foodhub_users"
echo "=========================================="

# Save DB info
cat > /tmp/foodhub-db.sh <<EOF
export DB_HOST="${PG_IP}"
export DB_PORT="5432"
export DB_USER="foodhub_user"
export DB_PASSWORD="${PG_PASSWORD}"
export REPL_USER="replicator"
export REPL_PASSWORD="${REPL_PASSWORD}"
EOF

print_green "Database info saved to /tmp/foodhub-db.sh"
