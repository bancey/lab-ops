locals {
  flattened_resources = flatten([
    for network_key, network in var.twingate_networks : [
      for resource_key, resource in network.resources : {
        network_key  = network_key
        resource_key = resource_key
        key          = "${network_key}-${resource_key}"
        resource     = resource
      }
    ]
  ])
  flattened_connectors = flatten([
    for network_key, network in var.twingate_networks : [
      for connector in network.connectors : {
        network_key = network_key
        key         = "${network_key}-${connector}"
        connector   = connector
      }
    ]
  ])
}

data "azurerm_client_config" "current" {}

data "azurerm_key_vault" "vault" {
  name                = "bancey-vault"
  resource_group_name = "common"
}

data "azurerm_key_vault_secret" "twingate_url" {
  name         = "Twingate-URL"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "twingate_api_token" {
  name         = "Twingate-API-Token"
  key_vault_id = data.azurerm_key_vault.vault.id
}
