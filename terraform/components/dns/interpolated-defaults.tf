locals {
  dns_yaml_path    = var.dns_yaml_path != null ? var.dns_yaml_path : "${path.cwd}/../../environments/${var.env}/dns.yaml"
  dns              = yamldecode(file(local.dns_yaml_path))
  adguard_rewrites = { for key, value in local.dns.dns : key => value.record if lookup(value, "public", false) != true }
}

data "local_file" "dns_yaml" {
  filename = local.dns_yaml_path
}

data "azurerm_key_vault" "vault" {
  name                = "bancey-vault"
  resource_group_name = "common"
}

data "azurerm_key_vault_secret" "cloudflare_lab_zone_id" {
  name         = "Cloudflare-Lab-Zone-ID"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "cloudflare_main_zone_id" {
  name         = "Cloudflare-Main-Zone-ID"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "cloudflare_lab_zone_name" {
  name         = "Cloudflare-Lab-Zone-Name"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "cloudflare_main_zone_name" {
  name         = "Cloudflare-Main-Zone-Name"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "cloudflare_lab_api_token" {
  name         = "Cloudflare-Lab-API-Token"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "cloudflare_main_api_token" {
  name         = "Cloudflare-Main-API-Token"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "public_ip" {
  name         = "Home-Public-IP"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "adguard_thanos_host" {
  name         = "Adguard-Thanos-Host"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "adguard_thanos_username" {
  name         = "Adguard-Thanos-Username"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "adguard_thanos_password" {
  name         = "Adguard-Thanos-Password"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "adguard_gamora_host" {
  name         = "Adguard-Gamora-Host"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "adguard_gamora_username" {
  name         = "Adguard-Gamora-Username"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "adguard_gamora_password" {
  name         = "Adguard-Gamora-Password"
  key_vault_id = data.azurerm_key_vault.vault.id
}
