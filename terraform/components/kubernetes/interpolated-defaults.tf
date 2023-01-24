locals {
  master_start_vm_id = 200
  node_start_vm_id   = 220
  vm_count = var.master_count + var.node_count
}

data "azurerm_client_config" "current" {}

data "azurerm_key_vault" "vault" {
  name                = "bancey-vault"
  resource_group_name = "common"
}

data "azurerm_key_vault_secret" "proxmox_url" {
  name         = "Wanda-Proxmox-URL"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "proxmox_token_id" {
  name         = "Wanda-Proxmox-Token-ID"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "proxmox_token_secret" {
  name         = "Wanda-Proxmox-Token-Secret"
  key_vault_id = data.azurerm_key_vault.vault.id
}
