resource "random_string" "storage_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_storage_account" "logs" {
  name                          = "${var.prefix}log${random_string.storage_suffix.result}"
  resource_group_name           = azurerm_resource_group.hub-rg.name
  location                      = var.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  shared_access_key_enabled     = false
  min_tls_version               = "TLS1_2"
  tags                          = var.tags
  public_network_access_enabled = false

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 30
    }
  }
}

resource "azurerm_storage_container" "logs" {
  name                  = "firewall-logs"
  storage_account_id    = azurerm_storage_account.logs.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "backups" {
  name                  = "vm-backups"
  storage_account_id    = azurerm_storage_account.logs.id
  container_access_type = "private"
}

resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                           = "firewall-diagnostics"
  target_resource_id             = azurerm_firewall.firewall.id
  storage_account_id             = azurerm_storage_account.logs.id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.main.id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category_group = "alllogs"
  }
}

#creates valut for holding policies
resource "azurerm_recovery_services_vault" "main" {
  resource_group_name = azurerm_resource_group.hub-rg.name
  name                = "hub-backup-vault"
  location            = var.location
  sku                 = "Standard"
}

#creates daily backup policy, hold data for 30 days, backups done at 23:00
resource "azurerm_backup_policy_vm" "daily" {
  name                = "daily-vm-backup"
  resource_group_name = azurerm_resource_group.hub-rg.name
  recovery_vault_name = azurerm_recovery_services_vault.main.name
  backup {
    frequency = "Daily"
    time      = "23:00"
  }
  retention_daily {
    count = 30
  }
}

#points linux vm to vault and policy needed
resource "azurerm_backup_protected_vm" "ubuntu" {
  resource_group_name = azurerm_resource_group.hub-rg.name
  recovery_vault_name = azurerm_recovery_services_vault.main.name
  source_vm_id        = azurerm_linux_virtual_machine.ubuntu.id
  backup_policy_id    = azurerm_backup_policy_vm.daily.id
}

resource "azurerm_logic_app_workflow" "alert-notify" {
  name                = "alert-notification-workflow"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub-rg.name
}

resource "azurerm_logic_app_trigger_http_request" "alert-received" {
  name         = "alert-fires"
  logic_app_id = azurerm_logic_app_workflow.alert-notify.id
  schema       = "{}"
}

resource "azurerm_monitor_action_group" "ops" {
  name                = "ops-notification"
  resource_group_name = azurerm_resource_group.hub-rg.name
  short_name          = "opsalert"

  logic_app_receiver {
    name                    = "notify-logic-app"
    resource_id             = azurerm_logic_app_workflow.alert-notify.id
    callback_url            = azurerm_logic_app_trigger_http_request.alert-received.callback_url
    use_common_alert_schema = true
  }
}

resource "azurerm_logic_app_action_http" "notify-nfty" {
  name         = "send-ntfy-notification"
  logic_app_id = azurerm_logic_app_workflow.alert-notify.id
  method       = "POST"
  uri          = "https://ntfy.sh/${var.ntfy_topic}"
  body         = "Alert: @{triggerBody()?['data']?['essentials']?['alertRule']} fired at severity @{triggerBody()?['data']?['essentials']?['severity']}"

  headers = {
    Title    = "Azure Alert Fired"
    priority = "urgent"
  }

  depends_on = [azurerm_logic_app_trigger_http_request.alert-received]
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "failed-logins" {
  name                 = "alert-failed-logins"
  resource_group_name  = azurerm_resource_group.hub-rg.name
  location             = var.location
  evaluation_frequency = "PT1M"
  window_duration      = "PT5M"
  scopes               = [azurerm_log_analytics_workspace.main.id]
  severity             = 1

  criteria {
    query = <<-KQL
      Syslog
      | where Facility in ("auth", "authpriv")
      | where SyslogMessage has "Failed password" or SyslogMessage has "authentication failure"
      | summarize FailedAttempts = count() by Computer, bin(TimeGenerated, 5m)
    KQL

    time_aggregation_method = "Maximum"
    metric_measure_column   = "FailedAttempts"
    threshold               = var.failed_login_threshold
    operator                = "GreaterThanOrEqual"

    dimension {
      name     = "Computer"
      operator = "Include"
      values   = ["*"]
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.ops.id]
  }
  auto_mitigation_enabled = true
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "hub-log-analytics"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub-rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_virtual_machine_extension" "ama-vm1" {
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.ubuntu.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.33"
  auto_upgrade_minor_version = true
}

resource "azurerm_virtual_machine_extension" "ama-vm2" {
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.ubuntu2.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.33"
  auto_upgrade_minor_version = true
}

resource "azurerm_monitor_data_collection_rule" "syslog" {
  name                = "dcr-syslog"
  resource_group_name = azurerm_resource_group.hub-rg.name
  location            = var.location

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.main.id
      name                  = "law-destination"
    }
  }

  data_flow {
    streams      = ["Microsoft-Syslog"]
    destinations = ["law-destination"]
  }

  data_sources {
    syslog {
      name           = "syslog-datasource"
      facility_names = ["auth", "authpriv"]
      log_levels     = ["*"]
      streams        = ["Microsoft-Syslog"]
    }
  }
}

resource "azurerm_monitor_data_collection_rule_association" "vm1" {
  name                    = "dcr-assoc-vm1"
  target_resource_id      = azurerm_linux_virtual_machine.ubuntu.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.syslog.id
  depends_on              = [azurerm_virtual_machine_extension.ama-vm1]
}

resource "azurerm_monitor_data_collection_rule_association" "vm2" {
  name                    = "dcr-assoc-vm2"
  target_resource_id      = azurerm_linux_virtual_machine.ubuntu2.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.syslog.id
  depends_on              = [azurerm_virtual_machine_extension.ama-vm2]
}