resource "twingate_connector" "homelab" {
  remote_network_id      = twingate_remote_network.homelab.id
  status_updates_enabled = true
}

resource "twingate_connector_tokens" "homelab" {
  connector_id = twingate_connector.homelab.id
}

resource "azurerm_key_vault_secret" "access_token" {
  name         = "Twingate-Homelab-Access-Token"
  value        = twingate_connector_tokens.homelab.access_token
  key_vault_id = data.azurerm_key_vault.vault.id
}

resource "azurerm_key_vault_secret" "refresh_token" {
  name         = "Twingate-Homelab-Refresh-Token"
  value        = twingate_connector_tokens.homelab.refresh_token
  key_vault_id = data.azurerm_key_vault.vault.id
}
