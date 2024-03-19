resource "twingate_connector" "this" {
  for_each               = { for connector in local.flattened_connectors : connector.key => connector }
  name                   = each.value.connector
  remote_network_id      = twingate_remote_network.this[each.value.network_key].id
  status_updates_enabled = true
}

resource "twingate_connector_tokens" "this" {
  for_each     = { for connector in local.flattened_connectors : connector.key => connector }
  connector_id = twingate_connector.this[each.key].id
}

resource "azurerm_key_vault_secret" "access_token" {
  for_each     = { for connector in local.flattened_connectors : connector.key => connector }
  name         = "Twingate-${each.value.connector}-Access-Token"
  value        = twingate_connector_tokens.this[each.key].access_token
  key_vault_id = data.azurerm_key_vault.vault.id
}

resource "azurerm_key_vault_secret" "refresh_token" {
  for_each     = { for connector in local.flattened_connectors : connector.key => connector }
  name         = "Twingate-${each.value.connector}-Refresh-Token"
  value        = twingate_connector_tokens.this[each.key].refresh_token
  key_vault_id = data.azurerm_key_vault.vault.id
}
