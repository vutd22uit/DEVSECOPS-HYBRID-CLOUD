terraform {
  required_version = ">= 1.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54.0"
    }
  }

  backend "local" {
    path = "terraform-openstack.tfstate"
  }
}

provider "openstack" {
  # Authentication can be done via environment variables:
  # export OS_AUTH_URL="http://your-openstack:5000/v3"
  # export OS_USERNAME="admin"
  # export OS_PASSWORD="your-password"
  # export OS_PROJECT_NAME="foodhub"
  # export OS_USER_DOMAIN_NAME="Default"
  # export OS_PROJECT_DOMAIN_NAME="Default"
  # export OS_REGION_NAME="RegionOne"

  # Or uncomment and configure here:
  # auth_url    = var.openstack_auth_url
  # user_name   = var.openstack_username
  # password    = var.openstack_password
  # tenant_name = var.openstack_project_name
  # domain_name = var.openstack_domain_name
  # region      = var.openstack_region
}
