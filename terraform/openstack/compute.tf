# Get or create SSH keypair
resource "openstack_compute_keypair_v2" "foodhub_keypair" {
  name = var.keypair_name
  # You can either:
  # 1. Let OpenStack generate the key (it will be in terraform state)
  # 2. Provide your own public key
  # public_key = file("~/.ssh/id_rsa.pub")
}

# Get image
data "openstack_images_image_v2" "ubuntu" {
  name        = var.image_name
  most_recent = true
}

# Kubernetes Master Nodes
resource "openstack_compute_instance_v2" "k8s_master" {
  count           = var.k8s_master_count
  name            = "${var.project_name}-k8s-master-${count.index + 1}"
  flavor_name     = var.k8s_master_flavor
  key_pair        = openstack_compute_keypair_v2.foodhub_keypair.name
  security_groups = [openstack_networking_secgroup_v2.k8s_master_sg.name]

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
    Name = "${var.project_name}-k8s-master-${count.index + 1}"
    Role = "kubernetes-master"
  })

  user_data = templatefile("${path.module}/scripts/k8s-master-init.sh", {
    k8s_version = "1.28.0"
    pod_cidr    = "192.168.0.0/16"
  })
}

# Allocate and associate floating IPs for master nodes
resource "openstack_networking_floatingip_v2" "k8s_master_fip" {
  count = var.k8s_master_count
  pool  = var.external_network_name
}

resource "openstack_compute_floatingip_associate_v2" "k8s_master_fip_assoc" {
  count       = var.k8s_master_count
  floating_ip = openstack_networking_floatingip_v2.k8s_master_fip[count.index].address
  instance_id = openstack_compute_instance_v2.k8s_master[count.index].id
}

# Kubernetes Worker Nodes
resource "openstack_compute_instance_v2" "k8s_worker" {
  count           = var.k8s_worker_count
  name            = "${var.project_name}-k8s-worker-${count.index + 1}"
  flavor_name     = var.k8s_worker_flavor
  key_pair        = openstack_compute_keypair_v2.foodhub_keypair.name
  security_groups = [openstack_networking_secgroup_v2.k8s_worker_sg.name]

  block_device {
    uuid                  = data.openstack_images_image_v2.ubuntu.id
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = 100
    boot_index            = 0
    delete_on_termination = true
  }

  network {
    uuid = openstack_networking_network_v2.foodhub_network.id
  }

  metadata = merge(var.tags, {
    Name = "${var.project_name}-k8s-worker-${count.index + 1}"
    Role = "kubernetes-worker"
  })

  user_data = templatefile("${path.module}/scripts/k8s-worker-init.sh", {
    master_ip = openstack_compute_instance_v2.k8s_master[0].access_ip_v4
  })
}

# Allocate and associate floating IPs for worker nodes
resource "openstack_networking_floatingip_v2" "k8s_worker_fip" {
  count = var.k8s_worker_count
  pool  = var.external_network_name
}

resource "openstack_compute_floatingip_associate_v2" "k8s_worker_fip_assoc" {
  count       = var.k8s_worker_count
  floating_ip = openstack_networking_floatingip_v2.k8s_worker_fip[count.index].address
  instance_id = openstack_compute_instance_v2.k8s_worker[count.index].id
}
