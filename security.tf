resource "azurerm_firewall_policy" "hub-policy" {
  name                     = "hub-fwpolicy"
  resource_group_name      = azurerm_resource_group.hub-rg.name
  location                 = var.location
  threat_intelligence_mode = "Deny"
}

resource "azurerm_firewall_policy_rule_collection_group" "baseline" {
  name               = "baseline-firewall-policy"
  firewall_policy_id = azurerm_firewall_policy.hub-policy.id
  priority           = 500

  application_rule_collection {
    name     = "app-oubound-web"
    priority = 100
    action   = "Allow"
    rule {
      name              = "allow-http-https"
      source_addresses  = [var.spoke1_workload_cidr, var.spoke2_workload_cidr]
      destination_fqdns = ["*"]

      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
    }
  }

  network_rule_collection {
    name     = "spoke-to-spoke"
    priority = 200
    action   = "Allow"

    rule {
      name                  = "allow-icmp"
      protocols             = ["ICMP"]
      source_addresses      = [var.spoke1_workload_cidr, var.spoke2_workload_cidr]
      destination_addresses = [var.spoke1_workload_cidr, var.spoke2_workload_cidr]
      destination_ports     = ["*"]
    }
  }
}