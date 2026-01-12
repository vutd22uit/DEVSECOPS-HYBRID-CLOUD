variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "foodhub"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "openstack_region" {
  description = "OpenStack region"
  type        = string
  default     = "RegionOne"
}

# Network Configuration
variable "network_cidr" {
  description = "CIDR block for OpenStack network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for private subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "external_network_name" {
  description = "Name of the external network for floating IPs"
  type        = string
  default     = "public"  # Common default, adjust based on your OpenStack setup
}

variable "dns_nameservers" {
  description = "DNS nameservers for the subnet"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

# Compute Configuration
variable "k8s_master_count" {
  description = "Number of Kubernetes master nodes"
  type        = number
  default     = 1
}

variable "k8s_worker_count" {
  description = "Number of Kubernetes worker nodes"
  type        = number
  default     = 3
}

variable "k8s_master_flavor" {
  description = "Flavor (instance type) for Kubernetes master nodes"
  type        = string
  default     = "m1.medium"  # Adjust based on your OpenStack flavors
}

variable "k8s_worker_flavor" {
  description = "Flavor (instance type) for Kubernetes worker nodes"
  type        = string
  default     = "m1.large"
}

variable "image_name" {
  description = "Name of the Ubuntu/CentOS image for instances"
  type        = string
  default     = "ubuntu-22.04"  # Adjust based on your OpenStack images
}

variable "keypair_name" {
  description = "Name of the SSH keypair"
  type        = string
  default     = "foodhub-key"
}

# Database Configuration
variable "db_flavor" {
  description = "Flavor for PostgreSQL database instance"
  type        = string
  default     = "m1.medium"
}

variable "db_volume_size" {
  description = "Size of database volume in GB"
  type        = number
  default     = 50
}

# Harbor Configuration
variable "harbor_flavor" {
  description = "Flavor for Harbor registry instance"
  type        = string
  default     = "m1.large"
}

variable "harbor_volume_size" {
  description = "Size of Harbor storage volume in GB"
  type        = number
  default     = 100
}

# Storage Configuration
variable "storage_volume_size" {
  description = "Size of additional storage volumes in GB"
  type        = number
  default     = 100
}

# AWS Integration
variable "aws_vpc_cidr" {
  description = "AWS VPC CIDR for VPN peering"
  type        = string
  default     = "10.1.0.0/16"
}

variable "aws_vpn_gateway_ip" {
  description = "AWS VPN Gateway IP address"
  type        = string
  default     = ""  # To be filled after AWS VPN setup
}

# Tags
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Project     = "FoodHub"
    ManagedBy   = "Terraform"
    Environment = "Production"
    Cloud       = "OpenStack"
  }
}
