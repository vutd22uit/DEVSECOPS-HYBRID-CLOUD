# Create private network
resource "openstack_networking_network_v2" "foodhub_network" {
  name           = "${var.project_name}-network"
  admin_state_up = "true"
  description    = "Private network for FoodHub microservices"
}

# Create subnet
resource "openstack_networking_subnet_v2" "foodhub_subnet" {
  name            = "${var.project_name}-subnet"
  network_id      = openstack_networking_network_v2.foodhub_network.id
  cidr            = var.subnet_cidr
  ip_version      = 4
  dns_nameservers = var.dns_nameservers

  allocation_pool {
    start = cidrhost(var.subnet_cidr, 10)
    end   = cidrhost(var.subnet_cidr, 250)
  }
}

# Get external network
data "openstack_networking_network_v2" "external_network" {
  name = var.external_network_name
}

# Create router
resource "openstack_networking_router_v2" "foodhub_router" {
  name                = "${var.project_name}-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external_network.id
  description         = "Router for FoodHub network with external connectivity"
}

# Attach router to subnet
resource "openstack_networking_router_interface_v2" "foodhub_router_interface" {
  router_id = openstack_networking_router_v2.foodhub_router.id
  subnet_id = openstack_networking_subnet_v2.foodhub_subnet.id
}

# Create port for VPN Gateway (for AWS VPN connection)
resource "openstack_networking_port_v2" "vpn_gateway_port" {
  name           = "${var.project_name}-vpn-gateway-port"
  network_id     = openstack_networking_network_v2.foodhub_network.id
  admin_state_up = "true"

  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.foodhub_subnet.id
  }

  security_group_ids = [
    openstack_networking_secgroup_v2.vpn_sg.id
  ]
}

# Allocate floating IP for VPN Gateway
resource "openstack_networking_floatingip_v2" "vpn_gateway_fip" {
  pool        = var.external_network_name
  description = "Floating IP for VPN Gateway to AWS"
}

# Associate floating IP with VPN Gateway port
resource "openstack_networking_floatingip_associate_v2" "vpn_gateway_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.vpn_gateway_fip.address
  port_id     = openstack_networking_port_v2.vpn_gateway_port.id
}
