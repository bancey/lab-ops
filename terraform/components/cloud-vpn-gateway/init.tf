terraform {
  required_version = "1.10.2"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.13.0"
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
