output "network_id" {
  description = "ID of the created network"
  value       = openstack_networking_network_v2.foodhub_network.id
}

output "subnet_id" {
  description = "ID of the created subnet"
  value       = openstack_networking_subnet_v2.foodhub_subnet.id
}

output "router_id" {
  description = "ID of the created router"
  value       = openstack_networking_router_v2.foodhub_router.id
}

# Kubernetes Master Outputs
output "k8s_master_ips" {
  description = "Private IPs of Kubernetes master nodes"
  value       = openstack_compute_instance_v2.k8s_master[*].access_ip_v4
}

output "k8s_master_floating_ips" {
  description = "Public IPs of Kubernetes master nodes"
  value       = openstack_networking_floatingip_v2.k8s_master_fip[*].address
}

# Kubernetes Worker Outputs
output "k8s_worker_ips" {
  description = "Private IPs of Kubernetes worker nodes"
  value       = openstack_compute_instance_v2.k8s_worker[*].access_ip_v4
}

output "k8s_worker_floating_ips" {
  description = "Public IPs of Kubernetes worker nodes"
  value       = openstack_networking_floatingip_v2.k8s_worker_fip[*].address
}

# PostgreSQL Outputs
output "postgresql_private_ip" {
  description = "Private IP of PostgreSQL instance"
  value       = openstack_compute_instance_v2.postgresql.access_ip_v4
}

output "postgresql_floating_ip" {
  description = "Public IP of PostgreSQL instance"
  value       = openstack_networking_floatingip_v2.postgresql_fip.address
}

output "postgresql_connection_string" {
  description = "PostgreSQL connection string"
  value       = "postgresql://foodhub_user:foodhub_password_change_me@${openstack_compute_instance_v2.postgresql.access_ip_v4}:5432/foodhub_users"
  sensitive   = true
}

# Harbor Outputs
output "harbor_private_ip" {
  description = "Private IP of Harbor registry"
  value       = openstack_compute_instance_v2.harbor.access_ip_v4
}

output "harbor_floating_ip" {
  description = "Public IP of Harbor registry"
  value       = openstack_networking_floatingip_v2.harbor_fip.address
}

output "harbor_url" {
  description = "Harbor registry URL"
  value       = "http://${openstack_networking_floatingip_v2.harbor_fip.address}"
}

output "harbor_credentials" {
  description = "Harbor admin credentials"
  value       = "admin / FoodHub@2025"
  sensitive   = true
}

# VPN Gateway Outputs
output "vpn_gateway_private_ip" {
  description = "Private IP of VPN gateway"
  value       = openstack_networking_port_v2.vpn_gateway_port.all_fixed_ips[0]
}

output "vpn_gateway_floating_ip" {
  description = "Public IP of VPN gateway (use this for AWS VPN configuration)"
  value       = openstack_networking_floatingip_v2.vpn_gateway_fip.address
}

# SSH Connection Instructions
output "ssh_connection_instructions" {
  description = "SSH connection commands"
  value = <<-EOT
    # Connect to Kubernetes Master:
    ssh ubuntu@${openstack_networking_floatingip_v2.k8s_master_fip[0].address}

    # Connect to Harbor Registry:
    ssh ubuntu@${openstack_networking_floatingip_v2.harbor_fip.address}

    # Connect to PostgreSQL:
    ssh ubuntu@${openstack_networking_floatingip_v2.postgresql_fip.address}

    # Connect to VPN Gateway:
    ssh ubuntu@${openstack_networking_floatingip_v2.vpn_gateway_fip.address}
  EOT
}

# Kubernetes Configuration
output "kubernetes_api_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = "https://${openstack_networking_floatingip_v2.k8s_master_fip[0].address}:6443"
}

# Summary
output "deployment_summary" {
  description = "Deployment summary"
  value = <<-EOT
    ═══════════════════════════════════════════════════════════════
    OpenStack FoodHub Infrastructure Deployment Complete
    ═══════════════════════════════════════════════════════════════

    🌐 Network:
       - Network CIDR: ${var.subnet_cidr}
       - Router: ${openstack_networking_router_v2.foodhub_router.name}

    ☸️  Kubernetes Cluster:
       - Master Nodes: ${var.k8s_master_count}
       - Worker Nodes: ${var.k8s_worker_count}
       - API Endpoint: https://${openstack_networking_floatingip_v2.k8s_master_fip[0].address}:6443

    🐳 Harbor Registry:
       - URL: http://${openstack_networking_floatingip_v2.harbor_fip.address}
       - Username: admin
       - Password: FoodHub@2025

    🗄️  PostgreSQL Database:
       - Host: ${openstack_compute_instance_v2.postgresql.access_ip_v4}
       - Port: 5432
       - Databases: foodhub_users, foodhub_products, foodhub_orders

    🔒 VPN Gateway (for AWS):
       - Public IP: ${openstack_networking_floatingip_v2.vpn_gateway_fip.address}
       - Local Network: ${var.subnet_cidr}
       - Remote Network: ${var.aws_vpc_cidr}

    ═══════════════════════════════════════════════════════════════
    Next Steps:
    1. Configure AWS VPN with OpenStack VPN Gateway IP
    2. Setup Kubernetes cluster with kubeadm
    3. Configure Harbor image sync with AWS ECR
    4. Setup PostgreSQL replication with AWS RDS
    5. Deploy ArgoCD for GitOps
    ═══════════════════════════════════════════════════════════════
  EOT
}
