terraform {
  required_version = "1.9.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.2.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.42.0"
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
