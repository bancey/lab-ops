data "azurerm_key_vault" "vault" {
  name                = "bancey-vault"
  resource_group_name = "common"
}

data "azurerm_key_vault_secret" "cloudflare_main_api_token" {
  name         = "Cloudflare-Main-API-Token"
  key_vault_id = data.azurerm_key_vault.vault.id
}