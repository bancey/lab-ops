data "azurerm_client_config" "current" {}

data "azurerm_key_vault" "vault" {
  name                = "bancey-vault"
  resource_group_name = "common"
}

data "azurerm_key_vault_secret" "wanda_proxmox_url" {
  name         = "Wanda-Proxmox-URL"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "hela_proxmox_url" {
  name         = "Hela-Proxmox-URL"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "loki_proxmox_url" {
  name         = "Loki-Proxmox-URL"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "thor_proxmox_url" {
  name         = "Thor-Proxmox-URL"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "wanda_proxmox_username" {
  name         = "Wanda-Proxmox-Username"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "wanda_proxmox_password" {
  name         = "Wanda-Proxmox-Password"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "tiny_proxmox_username" {
  name         = "Tiny-Proxmox-Username"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "tiny_proxmox_password" {
  name         = "Tiny-Proxmox-Password"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "lab_vm_username" {
  name         = "Lab-VM-Username"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "lab_vm_password" {
  name         = "Lab-VM-Password"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "cloudflare_lab_zone_id" {
  name         = "Cloudflare-Lab-Zone-ID"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "cloudflare_lab_zone_name" {
  name         = "Cloudflare-Lab-Zone-Name"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "cloudflare_lab_api_token" {
  name         = "Cloudflare-Lab-API-Token"
  key_vault_id = data.azurerm_key_vault.vault.id
}
