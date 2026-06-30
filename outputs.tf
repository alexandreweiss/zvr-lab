output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "hub_vnet_id" {
  value = azurerm_virtual_network.hub.id
}

output "spoke1_vnet_id" {
  value = azurerm_virtual_network.spoke1.id
}

output "spoke2_vnet_id" {
  value = azurerm_virtual_network.spoke2.id
}

output "hub_vnet_address_space" {
  value = azurerm_virtual_network.hub.address_space
}

output "spoke1_vnet_address_space" {
  value = azurerm_virtual_network.spoke1.address_space
}

output "spoke2_vnet_address_space" {
  value = azurerm_virtual_network.spoke2.address_space
}

output "spoke1_vm_private_ip" {
  description = "Private IP of vm-spoke1-linux"
  value       = azurerm_network_interface.spoke1_vm_nic.private_ip_address
}

output "spoke2_vm_private_ip" {
  description = "Private IP of vm-spoke2-linux"
  value       = azurerm_network_interface.spoke2_vm_nic.private_ip_address
}

output "ilb_frontend_ip" {
  description = "Internal Load Balancer frontend IP (next-hop for UDRs)"
  value       = azurerm_lb.hub_internal.frontend_ip_configuration[0].private_ip_address
}

output "vpn_gateway_name" {
  description = "Aviatrix VPN gateway name (download .ovpn from Controller)"
  value       = aviatrix_gateway.vpn_gateway.gw_name
}

output "ssh_private_key_path" {
  description = "Path to generated SSH private key — use to connect to VMs"
  value       = local_sensitive_file.ssh_private_key.filename
}

output "gatus_spoke1_dashboard" {
  description = "Gatus dashboard on spoke1 VM (monitors spoke2) — requires VPN"
  value       = "http://${azurerm_network_interface.spoke1_vm_nic.private_ip_address}:8080"
}

output "gatus_spoke2_dashboard" {
  description = "Gatus dashboard on spoke2 VM (monitors spoke1) — requires VPN"
  value       = "http://${azurerm_network_interface.spoke2_vm_nic.private_ip_address}:8080"
}
