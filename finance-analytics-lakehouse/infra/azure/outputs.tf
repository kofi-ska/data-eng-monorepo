output "resource_group_name" {
  description = "Resource group containing the finance lakehouse resources."
  value       = azurerm_resource_group.this.name
}

output "storage_account_name" {
  description = "ADLS Gen2 storage account used by the ELT workflow."
  value       = azurerm_storage_account.lake.name
}

output "raw_container_name" {
  description = "Filesystem that stores unmodified EBA source files."
  value       = azurerm_storage_data_lake_gen2_filesystem.raw.name
}

output "curated_container_name" {
  description = "Filesystem that stores transformed finance datasets."
  value       = azurerm_storage_data_lake_gen2_filesystem.curated.name
}

output "control_container_name" {
  description = "Filesystem that stores manifests and validation results."
  value       = azurerm_storage_data_lake_gen2_filesystem.control.name
}

output "synapse_workspace_name" {
  description = "Serverless Synapse workspace used for SQL ELT."
  value       = azurerm_synapse_workspace.this.name
}

output "serverless_sql_endpoint" {
  description = "Endpoint for the built-in Synapse serverless SQL pool."
  value       = azurerm_synapse_workspace.this.connectivity_endpoints["sqlOnDemand"]
}
