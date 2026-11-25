data "azurerm_client_config" "current" {}

resource "random_id" "storage_suffix" {
  byte_length = 4
}

locals {
  common_tags = {
    Project     = "earthling-cloud-dr-lab"
    Owner       = "Sky Coleman"
    ManagedBy   = "Terraform"
    Environment = "lab"
  }
  resource_group_name = "${var.lab_name_prefix}-rg"
  storage_name        = substr("${var.lab_name_prefix}${random_id.storage_suffix.hex}", 0, 24)
}

resource "azurerm_resource_group" "lab" {
  name     = local.resource_group_name
  location = var.location

  tags = merge(local.common_tags, {
    NIST_Control = "CM-6"
    Name         = "earthling-cloud-dr-lab"
  })
}

# SC-28, CP-9, AC-3: Immutable-style evidence storage (versioning + no public access)
resource "azurerm_storage_account" "evidence_vault" {
  name                            = local.storage_name
  resource_group_name             = azurerm_resource_group.lab.name
  location                        = azurerm_resource_group.lab.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true

  blob_properties {
    versioning_enabled = true
  }

  tags = merge(local.common_tags, {
    NIST_Control = "SC-28,CP-9,AC-3"
    Name         = "earthling-evidence-vault"
  })
}

resource "azurerm_storage_container" "evidence" {
  name                  = "evidence"
  storage_account_id    = azurerm_storage_account.evidence_vault.id
  container_access_type = "private"
}

# AU-2, AU-9: Centralized audit via Log Analytics + diagnostic settings
resource "azurerm_log_analytics_workspace" "audit" {
  name                = "${var.lab_name_prefix}-law"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = merge(local.common_tags, {
    NIST_Control = "AU-2,AU-9"
    Name         = "earthling-audit-workspace"
  })
}

resource "azurerm_monitor_diagnostic_setting" "storage_audit" {
  name                       = "storage-to-log-analytics"
  target_resource_id         = azurerm_storage_account.evidence_vault.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.audit.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  enabled_metric {
    category = "Transaction"
  }
}

# AC-6: Custom read-only auditor role scoped to resource group
resource "azurerm_role_definition" "compliance_auditor" {
  name        = "${var.lab_name_prefix}-compliance-auditor"
  scope       = azurerm_resource_group.lab.id
  description = "Read-only evidence and audit access for continuous monitoring."

  permissions {
    actions = [
      "Microsoft.Storage/storageAccounts/read",
      "Microsoft.Storage/storageAccounts/listKeys/action",
      "Microsoft.Storage/storageAccounts/blobServices/containers/read",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
      "Microsoft.Insights/diagnosticSettings/read",
      "Microsoft.OperationalInsights/workspaces/read",
      "Microsoft.Resources/subscriptions/resourceGroups/read",
    ]
    not_actions = []
  }

  assignable_scopes = [
    azurerm_resource_group.lab.id,
  ]
}

resource "azurerm_role_definition" "dr_operator" {
  name        = "${var.lab_name_prefix}-dr-operator"
  scope       = azurerm_resource_group.lab.id
  description = "DR verification: read storage and logs without write or RBAC admin."

  permissions {
    actions = [
      "Microsoft.Storage/storageAccounts/read",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
      "Microsoft.OperationalInsights/workspaces/read",
      "Microsoft.Insights/diagnosticSettings/read",
    ]
    not_actions = [
      "Microsoft.Authorization/*/Delete",
      "Microsoft.Authorization/*/Write",
    ]
  }

  assignable_scopes = [
    azurerm_resource_group.lab.id,
  ]
}

# Optional lab principal: current deploying identity gets dr_operator for demos
resource "azurerm_role_assignment" "dr_operator_current" {
  scope              = azurerm_resource_group.lab.id
  role_definition_id = azurerm_role_definition.dr_operator.role_definition_resource_id
  principal_id       = data.azurerm_client_config.current.object_id
}

# FinOps: $1.00 resource group budget
resource "azurerm_consumption_budget_resource_group" "zero_spend_guardrail" {
  name              = "${var.lab_name_prefix}-zero-spend"
  resource_group_id = azurerm_resource_group.lab.id

  amount     = 1
  time_grain = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
  }

  notification {
    enabled        = true
    threshold      = 50
    operator       = "GreaterThan"
    contact_emails = [var.budget_notification_email]
    threshold_type = "Actual"
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    contact_emails = [var.budget_notification_email]
    threshold_type = "Forecasted"
  }
}