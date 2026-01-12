# PostgreSQL Database Instance
resource "openstack_compute_instance_v2" "postgresql" {
  name            = "${var.project_name}-postgresql"
  flavor_name     = var.db_flavor
  key_pair        = openstack_compute_keypair_v2.foodhub_keypair.name
  security_groups = [openstack_networking_secgroup_v2.postgresql_sg.name]

  block_device {
    uuid                  = data.openstack_images_image_v2.ubuntu.id
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = 30
    boot_index            = 0
    delete_on_termination = true
  }

  network {
    uuid = openstack_networking_network_v2.foodhub_network.id
  }

  metadata = merge(var.tags, {
    Name = "${var.project_name}-postgresql"
    Role = "database"
  })

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update system
    apt-get update
    apt-get upgrade -y

    # Install PostgreSQL 15
    apt-get install -y postgresql-15 postgresql-contrib-15

    # Configure PostgreSQL for replication
    cat >> /etc/postgresql/15/main/postgresql.conf <<CONFIG
    listen_addresses = '*'
    wal_level = replica
    max_wal_senders = 10
    wal_keep_size = 1GB
    hot_standby = on
    archive_mode = on
    archive_command = 'test ! -f /var/lib/postgresql/15/archive/%f && cp %p /var/lib/postgresql/15/archive/%f'
    CONFIG

    # Create archive directory
    mkdir -p /var/lib/postgresql/15/archive
    chown -R postgres:postgres /var/lib/postgresql/15/archive

    # Configure pg_hba.conf for network access
    cat >> /etc/postgresql/15/main/pg_hba.conf <<HBA
    host    all             all             10.0.0.0/16             md5
    host    all             all             10.1.0.0/16             md5
    host    replication     replicator      10.1.0.0/16             md5
    HBA

    # Restart PostgreSQL
    systemctl restart postgresql

    # Create databases and users
    sudo -u postgres psql <<SQL
    CREATE DATABASE foodhub_users;
    CREATE DATABASE foodhub_products;
    CREATE DATABASE foodhub_orders;

    CREATE USER foodhub_user WITH ENCRYPTED PASSWORD 'foodhub_password_change_me';
    GRANT ALL PRIVILEGES ON DATABASE foodhub_users TO foodhub_user;
    GRANT ALL PRIVILEGES ON DATABASE foodhub_products TO foodhub_user;
    GRANT ALL PRIVILEGES ON DATABASE foodhub_orders TO foodhub_user;

    -- Create replication user for AWS RDS
    CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD 'replication_password_change_me';
    SQL

    echo "PostgreSQL installation and configuration completed"
  EOF
}

# Create and attach data volume for PostgreSQL
resource "openstack_blockstorage_volume_v3" "postgresql_data" {
  name        = "${var.project_name}-postgresql-data"
  description = "Data volume for PostgreSQL database"
  size        = var.db_volume_size
}

resource "openstack_compute_volume_attach_v2" "postgresql_data_attach" {
  instance_id = openstack_compute_instance_v2.postgresql.id
  volume_id   = openstack_blockstorage_volume_v3.postgresql_data.id
}

# Allocate and associate floating IP for PostgreSQL
resource "openstack_networking_floatingip_v2" "postgresql_fip" {
  pool        = var.external_network_name
  description = "Floating IP for PostgreSQL database"
}

resource "openstack_compute_floatingip_associate_v2" "postgresql_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.postgresql_fip.address
  instance_id = openstack_compute_instance_v2.postgresql.id
}
