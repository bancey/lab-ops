terraform {
  required_version = "1.15.3"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.72.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.8.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.3.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.19.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.3.0"
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

provider "null" {}
