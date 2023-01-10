data "azurerm_client_config" "current" {}

locals {
  tags = {
    "application" = "pterodactyl",
    "environment" = var.env,
  }
}

data "azurerm_key_vault" "vault" {
  name                = "bancey-vault"
  resource_group_name = "common"
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

data "azurerm_key_vault_secret" "game_server_ports" {
  name         = "Game-Server-Ports"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "public_ip" {
  name         = "Home-Public-IP"
  key_vault_id = data.azurerm_key_vault.vault.id
}
