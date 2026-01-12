# Security Group for Kubernetes Master Nodes
resource "openstack_networking_secgroup_v2" "k8s_master_sg" {
  name        = "${var.project_name}-k8s-master-sg"
  description = "Security group for Kubernetes master nodes"
}

resource "openstack_networking_secgroup_rule_v2" "k8s_master_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.k8s_master_sg.id
  description       = "Allow SSH"
}

resource "openstack_networking_secgroup_rule_v2" "k8s_master_api" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.k8s_master_sg.id
  description       = "Allow Kubernetes API Server"
}

resource "openstack_networking_secgroup_rule_v2" "k8s_master_etcd" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 2379
  port_range_max    = 2380
  remote_ip_prefix  = var.subnet_cidr
  security_group_id = openstack_networking_secgroup_v2.k8s_master_sg.id
  description       = "Allow etcd communication"
}

resource "openstack_networking_secgroup_rule_v2" "k8s_master_all_internal" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 1
  port_range_max    = 65535
  remote_ip_prefix  = var.subnet_cidr
  security_group_id = openstack_networking_secgroup_v2.k8s_master_sg.id
  description       = "Allow all internal traffic"
}

# Security Group for Kubernetes Worker Nodes
resource "openstack_networking_secgroup_v2" "k8s_worker_sg" {
  name        = "${var.project_name}-k8s-worker-sg"
  description = "Security group for Kubernetes worker nodes"
}

resource "openstack_networking_secgroup_rule_v2" "k8s_worker_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.k8s_worker_sg.id
  description       = "Allow SSH"
}

resource "openstack_networking_secgroup_rule_v2" "k8s_worker_nodeport" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 30000
  port_range_max    = 32767
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.k8s_worker_sg.id
  description       = "Allow NodePort services"
}

resource "openstack_networking_secgroup_rule_v2" "k8s_worker_all_internal" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 1
  port_range_max    = 65535
  remote_ip_prefix  = var.subnet_cidr
  security_group_id = openstack_networking_secgroup_v2.k8s_worker_sg.id
  description       = "Allow all internal traffic"
}

resource "openstack_networking_secgroup_rule_v2" "k8s_worker_http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.k8s_worker_sg.id
  description       = "Allow HTTP"
}

resource "openstack_networking_secgroup_rule_v2" "k8s_worker_https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.k8s_worker_sg.id
  description       = "Allow HTTPS"
}

# Security Group for PostgreSQL Database
resource "openstack_networking_secgroup_v2" "postgresql_sg" {
  name        = "${var.project_name}-postgresql-sg"
  description = "Security group for PostgreSQL database"
}

resource "openstack_networking_secgroup_rule_v2" "postgresql_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.postgresql_sg.id
  description       = "Allow SSH"
}

resource "openstack_networking_secgroup_rule_v2" "postgresql_db" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 5432
  port_range_max    = 5432
  remote_ip_prefix  = var.subnet_cidr
  security_group_id = openstack_networking_secgroup_v2.postgresql_sg.id
  description       = "Allow PostgreSQL from internal network"
}

resource "openstack_networking_secgroup_rule_v2" "postgresql_aws" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 5432
  port_range_max    = 5432
  remote_ip_prefix  = var.aws_vpc_cidr
  security_group_id = openstack_networking_secgroup_v2.postgresql_sg.id
  description       = "Allow PostgreSQL from AWS VPC"
}

# Security Group for Harbor Registry
resource "openstack_networking_secgroup_v2" "harbor_sg" {
  name        = "${var.project_name}-harbor-sg"
  description = "Security group for Harbor container registry"
}

resource "openstack_networking_secgroup_rule_v2" "harbor_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.harbor_sg.id
  description       = "Allow SSH"
}

resource "openstack_networking_secgroup_rule_v2" "harbor_http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.harbor_sg.id
  description       = "Allow HTTP"
}

resource "openstack_networking_secgroup_rule_v2" "harbor_https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.harbor_sg.id
  description       = "Allow HTTPS"
}

# Security Group for VPN Gateway
resource "openstack_networking_secgroup_v2" "vpn_sg" {
  name        = "${var.project_name}-vpn-sg"
  description = "Security group for VPN Gateway to AWS"
}

resource "openstack_networking_secgroup_rule_v2" "vpn_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.vpn_sg.id
  description       = "Allow SSH"
}

resource "openstack_networking_secgroup_rule_v2" "vpn_ipsec_500" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 500
  port_range_max    = 500
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.vpn_sg.id
  description       = "Allow IPSec IKE"
}

resource "openstack_networking_secgroup_rule_v2" "vpn_ipsec_4500" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 4500
  port_range_max    = 4500
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.vpn_sg.id
  description       = "Allow IPSec NAT-T"
}

resource "openstack_networking_secgroup_rule_v2" "vpn_esp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "50"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.vpn_sg.id
  description       = "Allow ESP protocol"
}

# Allow all egress traffic for all security groups
resource "openstack_networking_secgroup_rule_v2" "k8s_master_egress" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = openstack_networking_secgroup_v2.k8s_master_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "k8s_worker_egress" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = openstack_networking_secgroup_v2.k8s_worker_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "postgresql_egress" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = openstack_networking_secgroup_v2.postgresql_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "harbor_egress" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = openstack_networking_secgroup_v2.harbor_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "vpn_egress" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = openstack_networking_secgroup_v2.vpn_sg.id
}
