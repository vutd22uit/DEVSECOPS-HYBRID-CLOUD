# VPN Gateway Instance for AWS Connection
resource "openstack_compute_instance_v2" "vpn_gateway" {
  name            = "${var.project_name}-vpn-gateway"
  flavor_name     = "m1.small"
  key_pair        = openstack_compute_keypair_v2.foodhub_keypair.name
  security_groups = [openstack_networking_secgroup_v2.vpn_sg.name]

  block_device {
    uuid                  = data.openstack_images_image_v2.ubuntu.id
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = 20
    boot_index            = 0
    delete_on_termination = true
  }

  network {
    port = openstack_networking_port_v2.vpn_gateway_port.id
  }

  metadata = merge(var.tags, {
    Name = "${var.project_name}-vpn-gateway"
    Role = "vpn-gateway"
  })

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update system
    apt-get update
    apt-get upgrade -y

    # Install strongSwan for IPSec VPN
    apt-get install -y strongswan strongswan-pki libcharon-extra-plugins

    # Enable IP forwarding
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.conf
    sysctl -p

    # Configure firewall rules
    apt-get install -y iptables-persistent

    # Allow forwarding between interfaces
    iptables -A FORWARD -i eth0 -o eth0 -j ACCEPT
    iptables -A FORWARD -i eth0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

    netfilter-persistent save

    echo "VPN Gateway installation completed"
    echo "Configure strongSwan with AWS VPN settings:"
    echo "  - AWS VPN Gateway IP: ${var.aws_vpn_gateway_ip}"
    echo "  - OpenStack Network: ${var.subnet_cidr}"
    echo "  - AWS VPC CIDR: ${var.aws_vpc_cidr}"
  EOF
}

# Create a file with VPN configuration template
resource "local_file" "vpn_config_template" {
  filename = "${path.module}/configs/ipsec.conf.template"
  content  = <<-EOF
    # /etc/ipsec.conf - strongSwan IPsec configuration file

    config setup
        charondebug="ike 2, knl 2, cfg 2, net 2, esp 2, dmn 2, mgr 2"
        uniqueids=never

    conn aws-vpn-tunnel1
        type=tunnel
        authby=secret
        left=%defaultroute
        leftid=${openstack_networking_floatingip_v2.vpn_gateway_fip.address}
        leftsubnet=${var.subnet_cidr}
        right=${var.aws_vpn_gateway_ip}
        rightsubnet=${var.aws_vpc_cidr}
        ike=aes256-sha256-modp2048!
        esp=aes256-sha256-modp2048!
        keyingtries=%forever
        ikelifetime=8h
        lifetime=1h
        dpddelay=10s
        dpdtimeout=30s
        dpdaction=restart
        auto=start

    # /etc/ipsec.secrets - strongSwan IPsec secrets file
    # ${openstack_networking_floatingip_v2.vpn_gateway_fip.address} ${var.aws_vpn_gateway_ip} : PSK "your-pre-shared-key-here"
  EOF
}
