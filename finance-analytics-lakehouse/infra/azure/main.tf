data "azurerm_client_config" "current" {}

resource "random_string" "storage_suffix" {
  length  = 8
  upper   = false
  special = false
}

resource "random_string" "synapse_suffix" {
  length  = 8
  upper   = false
  special = false
}

locals {
  project_name = "finance-lakehouse"
  common_tags = {
    environment = var.environment
    project     = local.project_name
    managed_by  = "terraform"
    workload    = "portfolio"
  }
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.project_name}-${var.environment}"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_storage_account" "lake" {
  name                = "stfinlake${random_string.storage_suffix.result}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  access_tier              = "Hot"
  is_hns_enabled           = true

  allow_nested_items_to_be_public = false
  default_to_oauth_authentication = true
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = true
  shared_access_key_enabled       = false

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  tags = local.common_tags
}

resource "azurerm_role_assignment" "deployer_blob_contributor" {
  scope                = azurerm_storage_account.lake.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "raw" {
  name               = "raw"
  storage_account_id = azurerm_storage_account.lake.id

  depends_on = [azurerm_role_assignment.deployer_blob_contributor]
}

resource "azurerm_storage_data_lake_gen2_filesystem" "curated" {
  name               = "curated"
  storage_account_id = azurerm_storage_account.lake.id

  depends_on = [azurerm_role_assignment.deployer_blob_contributor]
}

resource "azurerm_storage_data_lake_gen2_filesystem" "control" {
  name               = "control"
  storage_account_id = azurerm_storage_account.lake.id

  depends_on = [azurerm_role_assignment.deployer_blob_contributor]
}

resource "azurerm_synapse_workspace" "this" {
  name                                 = "syn-finlake-${random_string.synapse_suffix.result}"
  resource_group_name                  = azurerm_resource_group.this.name
  location                             = azurerm_resource_group.this.location
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.control.id

  azuread_authentication_only     = true
  managed_virtual_network_enabled = false
  public_network_access_enabled   = true

  identity {
    type = "SystemAssigned"
  }

  # Azure returns service defaults for these fields even with Entra-only auth.
  # Ignoring them prevents a no-op refresh from replacing the workspace.
  lifecycle {
    ignore_changes = [
      sql_administrator_login,
      sql_identity_control_enabled,
    ]
  }

  tags = local.common_tags
}

resource "azurerm_role_assignment" "synapse_blob_contributor" {
  scope                = azurerm_storage_account.lake.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_synapse_workspace.this.identity[0].principal_id
}

resource "azurerm_synapse_role_assignment" "deployer_sql_administrator" {
  synapse_workspace_id = azurerm_synapse_workspace.this.id
  role_name            = "Synapse SQL Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
  principal_type       = "User"

  depends_on = [azurerm_synapse_firewall_rule.client]
}

resource "azurerm_synapse_firewall_rule" "client" {
  count = var.client_ip == null ? 0 : 1

  name                 = "deployment-client"
  synapse_workspace_id = azurerm_synapse_workspace.this.id
  start_ip_address     = var.client_ip
  end_ip_address       = var.client_ip
}
