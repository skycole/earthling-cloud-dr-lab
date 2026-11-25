output "subscription_id" {
  description = "Azure subscription ID."
  value       = data.azurerm_client_config.current.subscription_id
}

output "resource_group_name" {
  description = "Lab resource group name."
  value       = azurerm_resource_group.lab.name
}

output "evidence_storage_account_name" {
  description = "Storage account mirroring the AWS evidence vault."
  value       = azurerm_storage_account.evidence_vault.name
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace used for audit aggregation."
  value       = azurerm_log_analytics_workspace.audit.id
}

output "dr_operator_role_definition_id" {
  description = "Custom DR operator role definition resource ID."
  value       = azurerm_role_definition.dr_operator.role_definition_resource_id
}

output "compliance_auditor_role_definition_id" {
  description = "Custom compliance auditor role definition resource ID."
  value       = azurerm_role_definition.compliance_auditor.role_definition_resource_id
}

output "budget_name" {
  description = "Resource group budget name ($1.00 guardrail)."
  value       = azurerm_consumption_budget_resource_group.zero_spend_guardrail.name
}