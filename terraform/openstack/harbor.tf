# Harbor Container Registry Instance
resource "openstack_compute_instance_v2" "harbor" {
  name            = "${var.project_name}-harbor"
  flavor_name     = var.harbor_flavor
  key_pair        = openstack_compute_keypair_v2.foodhub_keypair.name
  security_groups = [openstack_networking_secgroup_v2.harbor_sg.name]

  block_device {
    uuid                  = data.openstack_images_image_v2.ubuntu.id
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = 50
    boot_index            = 0
    delete_on_termination = true
  }

  network {
    uuid = openstack_networking_network_v2.foodhub_network.id
  }

  metadata = merge(var.tags, {
    Name = "${var.project_name}-harbor"
    Role = "container-registry"
  })

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update system
    apt-get update
    apt-get upgrade -y

    # Install Docker
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io

    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    # Download Harbor installer
    cd /opt
    wget https://github.com/goharbor/harbor/releases/download/v2.10.0/harbor-offline-installer-v2.10.0.tgz
    tar xzvf harbor-offline-installer-v2.10.0.tgz
    cd harbor

    # Configure Harbor
    cp harbor.yml.tmpl harbor.yml

    # Get the instance's floating IP (to be updated after deployment)
    HOSTNAME=$(hostname -I | awk '{print $1}')

    # Update harbor.yml configuration
    sed -i "s/hostname: reg.mydomain.com/hostname: $HOSTNAME/" harbor.yml
    sed -i "s/harbor_admin_password: Harbor12345/harbor_admin_password: FoodHub@2025/" harbor.yml

    # Disable HTTPS for initial setup (can be enabled later with proper certs)
    sed -i 's/^https:/#https:/' harbor.yml
    sed -i 's/^  port: 443/#  port: 443/' harbor.yml
    sed -i 's/^  certificate:/#  certificate:/' harbor.yml
    sed -i 's/^  private_key:/#  private_key:/' harbor.yml

    # Install Harbor
    ./install.sh --with-trivy --with-chartmuseum

    echo "Harbor installation completed. Access at http://$HOSTNAME"
    echo "Default credentials: admin / FoodHub@2025"
  EOF
}

# Create and attach storage volume for Harbor
resource "openstack_blockstorage_volume_v3" "harbor_storage" {
  name        = "${var.project_name}-harbor-storage"
  description = "Storage volume for Harbor container images"
  size        = var.harbor_volume_size
}

resource "openstack_compute_volume_attach_v2" "harbor_storage_attach" {
  instance_id = openstack_compute_instance_v2.harbor.id
  volume_id   = openstack_blockstorage_volume_v3.harbor_storage.id
}

# Allocate and associate floating IP for Harbor
resource "openstack_networking_floatingip_v2" "harbor_fip" {
  pool        = var.external_network_name
  description = "Floating IP for Harbor container registry"
}

resource "openstack_compute_floatingip_associate_v2" "harbor_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.harbor_fip.address
  instance_id = openstack_compute_instance_v2.harbor.id
}
