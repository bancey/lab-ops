terraform {
  required_version = "1.11.3"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.26.0"
    }
    twingate = {
      source  = "Twingate/twingate"
      version = "3.0.17"
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
