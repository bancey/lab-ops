terraform {
  required_version = "1.8.1"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.100.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.5"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.30.0"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

provider "cloudflare" {
  api_token = data.azurerm_key_vault_secret.cloudflare_main_api_token.value
}
