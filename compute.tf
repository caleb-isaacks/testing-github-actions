provider "azurerm" {
  features {}
}

resource "azurerm_network_interface" "spoke1-nic" {
  name                = "spoke1-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub-rg.name

  ip_configuration {
    name                          = "spoke1-internal"
    subnet_id                     = azurerm_subnet.workoad1.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "ubuntu" {
  name                            = "linux"
  resource_group_name             = azurerm_resource_group.hub-rg.name
  location                        = var.location
  size                            = var.vm_size
  disable_password_authentication = false
  admin_username                  = data.azurerm_key_vault_secret.username.value
  admin_password                  = data.azurerm_key_vault_secret.password.value
  network_interface_ids           = [azurerm_network_interface.spoke1-nic.id]
  encryption_at_host_enabled      = false

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    offer     = "0001-com-ubuntu-server-jammy"
    publisher = "Canonical"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

resource "azurerm_network_interface" "spoke2-nic" {
  name                = "spoke2-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub-rg.name

  ip_configuration {
    name                          = "spokes-internal"
    subnet_id                     = azurerm_subnet.workoad2.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "ubuntu2" {
  name                            = "linux2"
  resource_group_name             = azurerm_resource_group.hub-rg.name
  location                        = var.location
  size                            = var.vm_size
  disable_password_authentication = false
  admin_username                  = data.azurerm_key_vault_secret.username.value
  admin_password                  = data.azurerm_key_vault_secret.password.value
  network_interface_ids           = [azurerm_network_interface.spoke2-nic.id]
  encryption_at_host_enabled      = false

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    offer     = "0001-com-ubuntu-server-jammy"
    publisher = "Canonical"
    sku       = "22_04-lts"
    version   = "latest"
  }
}