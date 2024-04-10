terraform {
  required_version = "1.8.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.98.0"
    }
    twingate = {
      source  = "Twingate/twingate"
      version = "3.0.0"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

provider "twingate" {
  network   = data.azurerm_key_vault_secret.twingate_url.value
  api_token = data.azurerm_key_vault_secret.twingate_api_token.value
}
