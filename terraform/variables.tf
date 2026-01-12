variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "project_name" {
  type    = string
  default = "foodhub"
}

variable "instance_type" {
  type    = string
  default = "t3.medium" # Jenkins + SonarQube cần tối thiểu 4GB RAM
}

variable "key_name" {
  type        = string
  description = "Tên Key Pair đã có trên AWS"
}

variable "ami_id" {
  type    = string
  default = "ami-0672fd5b9210aa093" # Ubuntu 22.04 LTS ap-southeast-1
}

variable "ecr_repos" {
  type    = set(string)
  default = ["foodhub-users", "foodhub-products", "foodhub-orders", "foodhub-frontend"]
}

# Hybrid Cloud - OpenStack Integration Variables
variable "openstack_vpn_gateway_ip" {
  type        = string
  description = "Public IP of OpenStack VPN Gateway (from OpenStack Terraform output)"
  default     = ""  # Will be populated after OpenStack deployment
}

variable "openstack_network_cidr" {
  type        = string
  description = "CIDR block of OpenStack private network"
  default     = "10.0.0.0/16"
}

variable "vpn_preshared_key" {
  type        = string
  description = "Pre-shared key for VPN connection"
  default     = "FoodHub-VPN-PSK-Change-Me-2025"
  sensitive   = true
}

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
  default     = "foodhub-cluster"
}