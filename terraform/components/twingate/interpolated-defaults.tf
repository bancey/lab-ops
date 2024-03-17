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
