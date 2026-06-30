# Data source for existing SSH key
data "azurerm_ssh_public_key" "linux_key" {
  name                = "ssh-linux-non-prod"
  resource_group_name = "core-rg"
}

# Spoke 1 VM Resources
resource "azurerm_network_interface" "spoke1_vm_nic" {
  name                = "nic-vm-spoke1"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.spoke1_workload.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "spoke1_vm" {
  name                = "vm-spoke1-linux"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  size                = "Standard_B2s"
  admin_username      = "admin-lab"

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.spoke1_vm_nic.id,
  ]

  admin_ssh_key {
    username   = "admin-lab"
    public_key = data.azurerm_ssh_public_key.linux_key.public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Gatus monitors spoke2 from spoke1
  custom_data = base64encode(templatefile("${path.module}/cloud-init/gatus.yaml.tpl", {
    target_ip   = azurerm_network_interface.spoke2_vm_nic.private_ip_address
    target_name = "spoke2"
  }))

  tags = {
    application = "app1"
  }
}

# Spoke 2 VM Resources
resource "azurerm_network_interface" "spoke2_vm_nic" {
  name                = "nic-vm-spoke2"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.spoke2_workload.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "spoke2_vm" {
  name                = "vm-spoke2-linux"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  size                = "Standard_B2s"
  admin_username      = "admin-lab"

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.spoke2_vm_nic.id,
  ]

  admin_ssh_key {
    username   = "admin-lab"
    public_key = data.azurerm_ssh_public_key.linux_key.public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Gatus monitors spoke1 from spoke2
  custom_data = base64encode(templatefile("${path.module}/cloud-init/gatus.yaml.tpl", {
    target_ip   = azurerm_network_interface.spoke1_vm_nic.private_ip_address
    target_name = "spoke1"
  }))

  tags = {
    application = "app2"
  }
}
