# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "zvr-frc-zvr"
  location = "France Central"
}

# Hub VNet
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-frc"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# Hub Subnets
resource "azurerm_subnet" "hub_gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "hub_shared" {
  name                 = "subnet-shared"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Aviatrix Gateway Subnets
resource "azurerm_subnet" "hub_avx_gw" {
  name                 = "avx-gw"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.3.0/24"]
}

resource "azurerm_subnet" "hub_avx_ha_gw" {
  name                 = "avx-ha-gw"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.4.0/24"]
}

# VPN Gateway Subnet
resource "azurerm_subnet" "hub_vpn_gw" {
  name                 = "avx-vpn-gw"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.5.0/24"]
}

# Internal Load Balancer
resource "azurerm_lb" "hub_internal" {
  name                = "lb-hub-internal"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "internal-frontend"
    subnet_id                     = azurerm_subnet.hub_shared.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Load Balancer Backend Pool
resource "azurerm_lb_backend_address_pool" "hub_internal_backend" {
  loadbalancer_id = azurerm_lb.hub_internal.id
  name            = "aviatrix-gateways"
}

# Load Balancer Health Probe
resource "azurerm_lb_probe" "hub_internal_probe" {
  loadbalancer_id = azurerm_lb.hub_internal.id
  name            = "tcp-probe"
  port            = 443
  protocol        = "Tcp"
}

# Load Balancer Rule
resource "azurerm_lb_rule" "hub_internal_rule" {
  loadbalancer_id                = azurerm_lb.hub_internal.id
  name                           = "all-traffic"
  protocol                       = "All"
  frontend_port                  = 0
  backend_port                   = 0
  frontend_ip_configuration_name = "internal-frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.hub_internal_backend.id]
  probe_id                       = azurerm_lb_probe.hub_internal_probe.id
  enable_floating_ip             = false
}

# Data blocks to retrieve Aviatrix gateway NICs
data "azurerm_network_interface" "avx_gw_nic" {
    name                = "av-nic-${module.mc_spoke_hub.spoke_gateway.gw_name}"
    resource_group_name = azurerm_resource_group.main.name
    depends_on          = [module.mc_spoke_hub]
}

data "azurerm_network_interface" "avx_ha_gw_nic" {
    count               = module.mc_spoke_hub.spoke_ha_gateway != null ? 1 : 0
    name                = "av-nic-${module.mc_spoke_hub.spoke_gateway.gw_name}-hagw"
    resource_group_name = azurerm_resource_group.main.name
    depends_on          = [module.mc_spoke_hub]
}

# Associate Aviatrix Gateway NIC to Load Balancer Backend Pool
resource "azurerm_network_interface_backend_address_pool_association" "avx_gw_lb" {
  network_interface_id    = data.azurerm_network_interface.avx_gw_nic.id
  ip_configuration_name   = data.azurerm_network_interface.avx_gw_nic.ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.hub_internal_backend.id
  depends_on              = [module.mc_spoke_hub]
}

# Associate Aviatrix HA Gateway NIC to Load Balancer Backend Pool
resource "azurerm_network_interface_backend_address_pool_association" "avx_ha_gw_lb" {
  count                   = module.mc_spoke_hub.spoke_ha_gateway != null ? 1 : 0
  network_interface_id    = data.azurerm_network_interface.avx_ha_gw_nic[0].id
  ip_configuration_name   = data.azurerm_network_interface.avx_ha_gw_nic[0].ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.hub_internal_backend.id
  depends_on              = [module.mc_spoke_hub]
}

# Route table for Hub shared subnet with blackhole route
resource "azurerm_route_table" "hub_shared_rt" {
  name                          = "rt-hub-shared-blackhole"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  bgp_route_propagation_enabled = false

  route {
    name           = "InternetBlackhole"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "None"
  }
}

# Associate route table with Hub shared subnet
resource "azurerm_subnet_route_table_association" "hub_shared_rt_association" {
  subnet_id      = azurerm_subnet.hub_shared.id
  route_table_id = azurerm_route_table.hub_shared_rt.id
}

# Spoke 1 VNet
resource "azurerm_virtual_network" "spoke1" {
  name                = "vnet-spoke1-frc"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "spoke1_workload" {
  name                 = "subnet-workload"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.spoke1.name
  address_prefixes     = ["10.1.1.0/24"]
}

# Spoke 2 VNet
resource "azurerm_virtual_network" "spoke2" {
  name                = "vnet-spoke2-frc"
  address_space       = ["10.2.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "spoke2_workload" {
  name                 = "subnet-workload"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.spoke2.name
  address_prefixes     = ["10.2.1.0/24"]
}

# Route table for Spoke 1 pointing to internal load balancer
resource "azurerm_route_table" "spoke1_rt" {
  name                          = "rt-spoke1-to-hub-lb"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name

  route {
    name                   = "default-to-hub-lb"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_lb.hub_internal.frontend_ip_configuration[0].private_ip_address
  }
  bgp_route_propagation_enabled = false
}

# Associate route table with Spoke 1 workload subnet
resource "azurerm_subnet_route_table_association" "spoke1_rt_association" {
  subnet_id      = azurerm_subnet.spoke1_workload.id
  route_table_id = azurerm_route_table.spoke1_rt.id
}

# Route table for Spoke 2 pointing to internal load balancer
resource "azurerm_route_table" "spoke2_rt" {
  name                          = "rt-spoke2-to-hub-lb"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name

  route {
    name                   = "default-to-hub-lb"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_lb.hub_internal.frontend_ip_configuration[0].private_ip_address
  }
  bgp_route_propagation_enabled = false
}

# Associate route table with Spoke 2 workload subnet
resource "azurerm_subnet_route_table_association" "spoke2_rt_association" {
  subnet_id      = azurerm_subnet.spoke2_workload.id
  route_table_id = azurerm_route_table.spoke2_rt.id
}

# Peering: Hub to Spoke 1
resource "azurerm_virtual_network_peering" "hub_to_spoke1" {
  name                      = "hub-to-spoke1"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke1.id
  allow_gateway_transit     = true
  use_remote_gateways       = false
}

resource "azurerm_virtual_network_peering" "spoke1_to_hub" {
  name                      = "spoke1-to-hub"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.spoke1.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_gateway_transit     = false
  use_remote_gateways       = false
}

# Peering: Hub to Spoke 2
resource "azurerm_virtual_network_peering" "hub_to_spoke2" {
  name                      = "hub-to-spoke2"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke2.id
  allow_gateway_transit     = true
  use_remote_gateways       = false
}

resource "azurerm_virtual_network_peering" "spoke2_to_hub" {
  name                      = "spoke2-to-hub"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.spoke2.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_gateway_transit     = false
  use_remote_gateways       = false
}
