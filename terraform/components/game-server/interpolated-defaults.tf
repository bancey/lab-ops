data "azurerm_client_config" "current" {}

locals {
  tags = {
    "application" = "game_servers",
    "environment" = var.env,
  }
}

module "private_nsg_rules" {
  source = "./game-server-nsg"
}

module "public_nsg_rules" {
  source                = "./game-server-nsg"
  source_address_prefix = data.azurerm_key_vault_secret.public_ip.value
  publicly_accessible   = true
}

data "azurerm_key_vault" "vault" {
  name                = "bancey-vault"
  resource_group_name = "common"
}

data "azurerm_key_vault_secret" "cloudflare_main_zone_id" {
  name         = "Cloudflare-Main-Zone-ID"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "cloudflare_main_zone_name" {
  name         = "Cloudflare-Main-Zone-Name"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "cloudflare_main_api_token" {
  name         = "Cloudflare-Main-API-Token"
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

data "azurerm_key_vault_secret" "twingate_pterodactyl_sa_key" {
  name         = "Twingate-Pterodactyl-SA-Key"
  key_vault_id = data.azurerm_key_vault.vault.id
}
