terraform {
  required_version = "1.9.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.3.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.43.0"
    }
    adguard = {
      source  = "gmichels/adguard"
      version = "1.3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.2"
    }
  }

  #backend "azurerm" {}
}

provider "local" {}

provider "azurerm" {
  subscription_id = "5a8abf1c-0a69-49c6-bcf1-676843b64217"
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
}

provider "adguard" {
  alias    = "gamora"
  host     = data.azurerm_key_vault_secret.adguard_gamora_host.value
  username = data.azurerm_key_vault_secret.adguard_gamora_username.value
  password = data.azurerm_key_vault_secret.adguard_gamora_password.value
  scheme   = "http"
}
