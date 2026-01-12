#!/bin/bash
set -e

echo "=========================================="
echo "Setup PostgreSQL Replication: OpenStack <-> AWS RDS"
echo "=========================================="

# Configuration
OPENSTACK_PG_HOST="${1:-OPENSTACK_PG_IP}"
OPENSTACK_PG_PORT="${2:-5432}"
AWS_RDS_HOST="${3:-AWS_RDS_ENDPOINT}"
AWS_RDS_PORT="${4:-5432}"
PG_USER="${5:-foodhub_user}"
PG_PASSWORD="${6:-foodhub_password_change_me}"
REPLICATION_USER="${7:-replicator}"
REPLICATION_PASSWORD="${8:-replication_password_change_me}"

echo "📋 Configuration:"
echo "  OpenStack PostgreSQL: ${OPENSTACK_PG_HOST}:${OPENSTACK_PG_PORT}"
echo "  AWS RDS: ${AWS_RDS_HOST}:${AWS_RDS_PORT}"
echo "  Replication User: ${REPLICATION_USER}"
echo ""

# Function to test PostgreSQL connection
test_pg_connection() {
    local host=$1
    local port=$2
    local user=$3
    local password=$4

    echo "🔍 Testing connection to ${host}:${port}..."
    PGPASSWORD=${password} psql -h ${host} -p ${port} -U ${user} -d postgres -c "SELECT version();" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✅ Connection successful"
        return 0
    else
        echo "❌ Connection failed"
        return 1
    fi
}

# Test connections
echo ""
echo "🔍 Testing database connections..."
test_pg_connection ${OPENSTACK_PG_HOST} ${OPENSTACK_PG_PORT} ${PG_USER} ${PG_PASSWORD}
test_pg_connection ${AWS_RDS_HOST} ${AWS_RDS_PORT} ${PG_USER} ${PG_PASSWORD}

# Configure OpenStack PostgreSQL as Primary
echo ""
echo "📝 Configuring OpenStack PostgreSQL as Primary..."

cat > /tmp/setup_primary.sql <<EOF
-- Create replication user if not exists
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = '${REPLICATION_USER}') THEN
        CREATE USER ${REPLICATION_USER} WITH REPLICATION ENCRYPTED PASSWORD '${REPLICATION_PASSWORD}';
    END IF;
END
\$\$;

-- Create replication slot for AWS RDS
SELECT pg_create_physical_replication_slot('aws_rds_slot')
WHERE NOT EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = 'aws_rds_slot');

-- Show replication status
SELECT * FROM pg_stat_replication;
SELECT * FROM pg_replication_slots;
EOF

PGPASSWORD=${PG_PASSWORD} psql -h ${OPENSTACK_PG_HOST} -p ${OPENSTACK_PG_PORT} -U ${PG_USER} -d postgres -f /tmp/setup_primary.sql

# Create AWS RDS read replica configuration
echo ""
echo "📝 Creating AWS RDS replica configuration..."

cat > /tmp/aws_rds_replica_guide.md <<EOF
# AWS RDS PostgreSQL Replication Setup

## Method 1: Using AWS DMS (Database Migration Service)

AWS DMS provides a managed solution for continuous replication from external sources to RDS.

### Steps:

1. **Create DMS Replication Instance:**
   \`\`\`bash
   aws dms create-replication-instance \\
     --replication-instance-identifier foodhub-dms \\
     --replication-instance-class dms.t3.medium \\
     --allocated-storage 50 \\
     --vpc-security-group-ids sg-xxxxx \\
     --replication-subnet-group-identifier default
   \`\`\`

2. **Create Source Endpoint (OpenStack PostgreSQL):**
   \`\`\`bash
   aws dms create-endpoint \\
     --endpoint-identifier openstack-pg-source \\
     --endpoint-type source \\
     --engine-name postgres \\
     --server-name ${OPENSTACK_PG_HOST} \\
     --port ${OPENSTACK_PG_PORT} \\
     --username ${REPLICATION_USER} \\
     --password ${REPLICATION_PASSWORD} \\
     --database-name foodhub_users
   \`\`\`

3. **Create Target Endpoint (AWS RDS):**
   \`\`\`bash
   aws dms create-endpoint \\
     --endpoint-identifier aws-rds-target \\
     --endpoint-type target \\
     --engine-name postgres \\
     --server-name ${AWS_RDS_HOST} \\
     --port ${AWS_RDS_PORT} \\
     --username ${PG_USER} \\
     --password ${PG_PASSWORD} \\
     --database-name foodhub_users
   \`\`\`

4. **Test Endpoints:**
   \`\`\`bash
   aws dms test-connection \\
     --replication-instance-arn arn:aws:dms:region:account:rep:xxxxx \\
     --endpoint-arn arn:aws:dms:region:account:endpoint:xxxxx
   \`\`\`

5. **Create Replication Task for each database:**
   \`\`\`bash
   aws dms create-replication-task \\
     --replication-task-identifier foodhub-users-replication \\
     --source-endpoint-arn arn:aws:dms:region:account:endpoint:openstack-pg-source \\
     --target-endpoint-arn arn:aws:dms:region:account:endpoint:aws-rds-target \\
     --replication-instance-arn arn:aws:dms:region:account:rep:foodhub-dms \\
     --migration-type full-load-and-cdc \\
     --table-mappings file://table-mappings.json
   \`\`\`

   table-mappings.json:
   \`\`\`json
   {
     "rules": [
       {
         "rule-type": "selection",
         "rule-id": "1",
         "rule-name": "1",
         "object-locator": {
           "schema-name": "public",
           "table-name": "%"
         },
         "rule-action": "include"
       }
     ]
   }
   \`\`\`

6. **Start Replication Task:**
   \`\`\`bash
   aws dms start-replication-task \\
     --replication-task-arn arn:aws:dms:region:account:task:xxxxx \\
     --start-replication-task-type start-replication
   \`\`\`

## Method 2: Using Logical Replication (pglogical)

For more control, you can use pglogical extension:

### On OpenStack PostgreSQL (Primary):

\`\`\`sql
-- Install pglogical extension
CREATE EXTENSION IF NOT EXISTS pglogical;

-- Create pglogical node
SELECT pglogical.create_node(
  node_name := 'openstack_provider',
  dsn := 'host=${OPENSTACK_PG_HOST} port=${OPENSTACK_PG_PORT} dbname=foodhub_users user=${REPLICATION_USER} password=${REPLICATION_PASSWORD}'
);

-- Add all tables to replication set
SELECT pglogical.replication_set_add_all_tables('default', ARRAY['public']);
\`\`\`

### On AWS RDS (Replica):

\`\`\`sql
-- Install pglogical extension
CREATE EXTENSION IF NOT EXISTS pglogical;

-- Create subscriber node
SELECT pglogical.create_node(
  node_name := 'aws_subscriber',
  dsn := 'host=${AWS_RDS_HOST} port=${AWS_RDS_PORT} dbname=foodhub_users user=${PG_USER} password=${PG_PASSWORD}'
);

-- Create subscription
SELECT pglogical.create_subscription(
  subscription_name := 'subscription_from_openstack',
  provider_dsn := 'host=${OPENSTACK_PG_HOST} port=${OPENSTACK_PG_PORT} dbname=foodhub_users user=${REPLICATION_USER} password=${REPLICATION_PASSWORD}',
  replication_sets := ARRAY['default'],
  synchronize_structure := false,
  synchronize_data := true
);
\`\`\`

## Monitoring Replication

### Check replication lag:
\`\`\`sql
-- On Primary (OpenStack)
SELECT * FROM pg_stat_replication;

-- Check replication slots
SELECT * FROM pg_replication_slots;

-- Check WAL sender status
SELECT pid, usename, application_name, client_addr, state,
       sent_lsn, write_lsn, flush_lsn, replay_lsn,
       sync_state, sync_priority
FROM pg_stat_replication;
\`\`\`

### Monitor DMS Tasks:
\`\`\`bash
aws dms describe-replication-tasks \\
  --filters Name=replication-task-id,Values=foodhub-users-replication

# Check task statistics
aws dms describe-table-statistics \\
  --replication-task-arn arn:aws:dms:region:account:task:xxxxx
\`\`\`

## Failover Procedure

### Promote AWS RDS to Primary:

1. Stop DMS replication task
2. Promote read replica (if using RDS read replica)
3. Update application connection strings
4. Reconfigure OpenStack PostgreSQL as replica (reverse direction)

## Backup Strategy

- OpenStack: Use pg_basebackup and WAL archiving
- AWS RDS: Automated backups enabled
- Cross-region backups for disaster recovery
EOF

cat /tmp/aws_rds_replica_guide.md

echo ""
echo "=========================================="
echo "✅ Database Replication Configuration Created"
echo "=========================================="
echo ""
echo "📋 Replication Status:"
PGPASSWORD=${PG_PASSWORD} psql -h ${OPENSTACK_PG_HOST} -p ${OPENSTACK_PG_PORT} -U ${PG_USER} -d postgres -c "SELECT * FROM pg_stat_replication;"
echo ""
echo "📋 Replication Slots:"
PGPASSWORD=${PG_PASSWORD} psql -h ${OPENSTACK_PG_HOST} -p ${OPENSTACK_PG_PORT} -U ${PG_USER} -d postgres -c "SELECT * FROM pg_replication_slots;"
echo ""
echo "📄 Detailed guide saved to: /tmp/aws_rds_replica_guide.md"
echo ""
echo "⚠️  IMPORTANT: Configure AWS DMS or pglogical following the guide above"
echo "=========================================="
