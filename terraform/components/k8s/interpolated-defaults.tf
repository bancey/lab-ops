data "azurerm_client_config" "current" {}

data "azurerm_key_vault" "vault" {
  name                = "bancey-vault"
  resource_group_name = "common"
}

data "azurerm_key_vault_secret" "proxmox_url" {
  name         = "Baldr-Proxmox-URL"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "proxmox_token_id" {
  name         = "Baldr-Proxmox-Token-ID"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "proxmox_token_secret" {
  name         = "Baldr-Proxmox-Token-Secret"
  key_vault_id = data.azurerm_key_vault.vault.id
}
