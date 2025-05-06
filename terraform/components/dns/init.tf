terraform {
  required_version = "1.11.4"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.27.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.4.0"
    }
    adguard = {
      source  = "gmichels/adguard"
      version = "1.5.1"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

provider "cloudflare" {
  alias     = "lab"
  api_token = data.azurerm_key_vault_secret.cloudflare_lab_api_token.value
}

provider "cloudflare" {
  alias     = "main"
  api_token = data.azurerm_key_vault_secret.cloudflare_main_api_token.value
}

provider "adguard" {
  alias    = "thanos"
  host     = data.azurerm_key_vault_secret.adguard_thanos_host.value
  username = data.azurerm_key_vault_secret.adguard_thanos_username.value
  password = data.azurerm_key_vault_secret.adguard_thanos_password.value
  scheme   = "http"
  timeout  = 60
}

provider "adguard" {
  alias    = "gamora"
  host     = data.azurerm_key_vault_secret.adguard_gamora_host.value
  username = data.azurerm_key_vault_secret.adguard_gamora_username.value
  password = data.azurerm_key_vault_secret.adguard_gamora_password.value
  scheme   = "http"
  timeout  = 60
}
