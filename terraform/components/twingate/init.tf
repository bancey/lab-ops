terraform {
  required_version = "1.11.4"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.28.0"
    }
    twingate = {
      source  = "Twingate/twingate"
      version = "3.1.0"
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
