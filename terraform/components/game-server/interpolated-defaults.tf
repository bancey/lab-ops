data "azurerm_client_config" "current" {}

locals {
  tags = {
    "application" = "gameservers",
    "environment" = var.env,
  }

  nsg_rules = {
    Allow80 : {
      priority                   = 1000
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
    Allow22 : {
      priority                   = 1010
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = data.azurerm_key_vault_secret.public_ip.value
      destination_address_prefix = "*"
    }
    Allow443 : {
      priority                   = 1020
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = data.azurerm_key_vault_secret.public_ip.value
      destination_address_prefix = "*"
    }
    Allow8080 : {
      priority                   = 1030
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "8080"
      source_address_prefix      = data.azurerm_key_vault_secret.public_ip.value
      destination_address_prefix = "*"
    }
    Allow2022 : {
      priority                   = 1040
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "2022"
      source_address_prefix      = data.azurerm_key_vault_secret.public_ip.value
      destination_address_prefix = "*"
    }
    AllowGameServerPorts : {
      priority                   = 1050
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = data.azurerm_key_vault_secret.game_server_ports.value
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }
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
