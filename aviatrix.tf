# Data source to get hub VNet GUID
data "azurerm_virtual_network" "hub" {
  name                = azurerm_virtual_network.hub.name
  resource_group_name = azurerm_resource_group.main.name
}

# Deploy Aviatrix Spoke Gateway using mc-spoke module
module "mc_spoke_hub" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"

  cloud                = "Azure"
  name                 = "avx-spoke-hub-frc"
  cidr                 = "10.0.0.0/16"
  region               = "France Central"
  account              = var.aviatrix_azure_account_name
  
  # Use existing VNet
  use_existing_vpc     = true
  vpc_id              = "${azurerm_virtual_network.hub.name}:${azurerm_resource_group.main.name}:${data.azurerm_virtual_network.hub.guid}"
  
  # Gateway subnet configuration
  gw_subnet           = azurerm_subnet.hub_avx_gw.address_prefixes[0]
  hagw_subnet         = azurerm_subnet.hub_avx_ha_gw.address_prefixes[0]
  instance_size       = "Standard_B2ms"
  
  # HA Gateway configuration
  ha_gw              = true
  
  # Enable single IP NAT
  single_ip_snat     = true
  
  # Manual advertised spoke CIDRs
  included_advertised_spoke_routes = "${azurerm_virtual_network.spoke1.address_space[0]},${azurerm_virtual_network.spoke2.address_space[0]}"
  # Transit gateway attachment (set to false for now)
  attached           = false
  
  depends_on = [
    azurerm_subnet.hub_avx_gw,
    azurerm_subnet.hub_avx_ha_gw,
    azurerm_subnet_route_table_association.hub_shared_rt_association
  ]
}

# Aviatrix VPN Gateway in Hub
resource "aviatrix_gateway" "vpn_gateway" {
  cloud_type         = 8
  account_name       = var.aviatrix_azure_account_name
  gw_name           = "avx-vpn-hub-frc"
  vpc_id            = "${azurerm_virtual_network.hub.name}:${azurerm_resource_group.main.name}:${data.azurerm_virtual_network.hub.guid}"
  vpc_reg           = "France Central"
  gw_size           = "Standard_B2ms"
  subnet            = azurerm_subnet.hub_vpn_gw.address_prefixes[0]
  
  # VPN configuration
  vpn_access        = true
  vpn_cidr          = "192.168.43.0/24"
  enable_elb        = false
  max_vpn_conn      = "100"
  
  # Split tunnel
  split_tunnel      = true
  additional_cidrs  = "${azurerm_virtual_network.spoke1.address_space[0]},${azurerm_virtual_network.spoke2.address_space[0]}"
  
  depends_on = [
    azurerm_subnet.hub_vpn_gw,
    module.mc_spoke_hub
  ]
}

# Aviatrix VPN User
resource "aviatrix_vpn_user" "zvr_user" {
  vpc_id     = "${azurerm_virtual_network.hub.name}:${azurerm_resource_group.main.name}:${data.azurerm_virtual_network.hub.guid}"
  gw_name    = aviatrix_gateway.vpn_gateway.gw_name
  user_name  = "zvr-user"
  user_email = "aweiss@aviatrix.com"
  
  depends_on = [aviatrix_gateway.vpn_gateway]
}