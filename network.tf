resource "azurerm_resource_group" "hub-rg" {
  location = var.location
  name     = "resource-group"
}

resource "azurerm_virtual_network" "hub-vnet" {
  location            = var.location
  resource_group_name = azurerm_resource_group.hub-rg.name
  name                = "hub-network"
  address_space       = [var.hub_vnet_cidr]
  tags                = var.tags

}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.hub-rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
  address_prefixes     = [var.firewall_subnet_cidr]
}

resource "azurerm_public_ip" "pubip" {
  name                = "firewall-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "firewall" {
  name                = "hubfirewall"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub-rg.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.hub-policy.id

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.pubip.id
  }
}

resource "azurerm_subnet" "AzureBastionSubnet" {
  name                 = "AzureBastionSubnet"
  address_prefixes     = [var.bastion_subnet_cidr]
  resource_group_name  = azurerm_resource_group.hub-rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
}

resource "azurerm_public_ip" "bastion-ip" {
  name                = "bastion-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "bastion-host" {
  name                = "AzureBastionHost"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub-rg.name

  ip_configuration {
    name                 = "AzureBastionSubnet"
    subnet_id            = azurerm_subnet.AzureBastionSubnet.id
    public_ip_address_id = azurerm_public_ip.bastion-ip.id
  }
}

resource "azurerm_network_security_group" "hub" {
  location            = var.location
  resource_group_name = azurerm_resource_group.hub-rg.name
  name                = "hub-nsg"

  security_rule {
    name                       = "ssh-from-bastion"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.bastion_subnet_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "deny-other"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "workload1" {
  subnet_id                 = azurerm_subnet.workoad1.id
  network_security_group_id = azurerm_network_security_group.hub.id
}

resource "azurerm_virtual_network" "spoke1" {
  name                = "spoke1-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub-rg.name
  address_space       = [var.spoke1_vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "workoad1" {
  address_prefixes     = [var.spoke1_workload_cidr]
  resource_group_name  = azurerm_resource_group.hub-rg.name
  name                 = "workload1-subnet"
  virtual_network_name = azurerm_virtual_network.spoke1.name
}

resource "azurerm_virtual_network_peering" "hub-to-spoke" {
  name                      = "hub-to-spoke"
  resource_group_name       = azurerm_resource_group.hub-rg.name
  virtual_network_name      = azurerm_virtual_network.hub-vnet.name
  remote_virtual_network_id = azurerm_virtual_network.spoke1.id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "spoke-to-hub" {
  name                      = "spoke-to-hub"
  resource_group_name       = azurerm_resource_group.hub-rg.name
  virtual_network_name      = azurerm_virtual_network.spoke1.name
  remote_virtual_network_id = azurerm_virtual_network.hub-vnet.id
  allow_forwarded_traffic   = true
}

resource "azurerm_route_table" "route-table" {
  location            = var.location
  name                = "route-table"
  resource_group_name = azurerm_resource_group.hub-rg.name

  route {
    name                   = "route1"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.firewall.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "spoke" {
  route_table_id = azurerm_route_table.route-table.id
  subnet_id      = azurerm_subnet.workoad1.id
}

resource "azurerm_virtual_network" "spoke2" {
  name                = "spoke2-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub-rg.name
  address_space       = [var.spoke2_vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "workoad2" {
  address_prefixes     = [var.spoke2_workload_cidr]
  resource_group_name  = azurerm_resource_group.hub-rg.name
  name                 = "workload2-subnet"
  virtual_network_name = azurerm_virtual_network.spoke2.name
}

resource "azurerm_virtual_network_peering" "hub-to-spoke2" {
  name                      = "hub-to-spoke2"
  resource_group_name       = azurerm_resource_group.hub-rg.name
  virtual_network_name      = azurerm_virtual_network.hub-vnet.name
  remote_virtual_network_id = azurerm_virtual_network.spoke2.id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "spoke2-to-hub" {
  name                      = "spoke2-to-hub"
  resource_group_name       = azurerm_resource_group.hub-rg.name
  virtual_network_name      = azurerm_virtual_network.spoke2.name
  remote_virtual_network_id = azurerm_virtual_network.hub-vnet.id
  allow_forwarded_traffic   = true
}

resource "azurerm_subnet_route_table_association" "spoke2" {
  route_table_id = azurerm_route_table.route-table.id
  subnet_id      = azurerm_subnet.workoad2.id
}

resource "azurerm_subnet_network_security_group_association" "workload2" {
  subnet_id                 = azurerm_subnet.workoad2.id
  network_security_group_id = azurerm_network_security_group.hub.id
}

resource "azurerm_subnet" "private-endpoints" {
  name                 = "private-endpoints"
  resource_group_name  = azurerm_resource_group.hub-rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
  address_prefixes     = [var.endpoints]
}

resource "azurerm_private_endpoint" "storage-blob" {
  name                = "storage-logs-blob"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub-rg.name
  subnet_id           = azurerm_subnet.private-endpoints.id

  private_service_connection {
    name                           = "storage-logs-psc"
    private_connection_resource_id = azurerm_storage_account.logs.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "blob-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
}

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.hub-rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob-hub" {
  name                = "blob-hub-link"
  virtual_network_id  = azurerm_virtual_network.hub-vnet.id
  private_dns_zone_id = azurerm_private_dns_zone.blob.id
  #resource_group_name = azurerm_resource_group.hub-rg.name
}

