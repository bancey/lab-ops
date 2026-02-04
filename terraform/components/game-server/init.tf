terraform {
  required_version = "1.14.3"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.58.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.8.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.1.0"
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
