variable "location" {
  default = "centralus"
}

variable "tags" {
  description = "common tags applied to all"
  type        = map(string)
  default = {
    enviroment = "lab"
    project    = "hub-and-spoke"
  }
}

data "azurerm_key_vault_secret" "password" {
  key_vault_id = data.azurerm_key_vault.keyvault.id
  name         = "password"
}

data "azurerm_key_vault_secret" "username" {
  key_vault_id = data.azurerm_key_vault.keyvault.id
  name         = "username"
}

variable "prefix" {
  type    = string
  default = "hubspoke"
}

variable "resource_group_name" {
  type    = string
  default = "resource-group"
}

variable "vm_size" {
  type    = string
  default = "Standard_D2_v3"
}

variable "hub_vnet_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "firewall_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}
variable "bastion_subnet_cidr" {
  type    = string
  default = "10.0.2.0/24"
}
variable "spoke1_workload_cidr" {
  type    = string
  default = "10.1.0.0/25"
}
variable "spoke1_vnet_cidr" {
  type    = string
  default = "10.1.0.0/24"
}
variable "spoke2_vnet_cidr" {
  type    = string
  default = "10.2.0.0/24"
}
variable "spoke2_workload_cidr" {
  type    = string
  default = "10.2.0.0/25"
}
variable "endpoints" {
  type    = string
  default = "10.0.3.0/24"
}

variable "failed_login_threshold" {
  type    = number
  default = 5
}

