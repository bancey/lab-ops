terraform {
  required_version = "1.8.1"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.99.0"
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
  api_token = data.azurerm_key_vault_secret.cloudflare_lab_api_token.value
}
