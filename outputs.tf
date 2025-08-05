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
