terraform {
  required_version = "1.14.4"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.60.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.8.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.2.1"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.16.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"
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
