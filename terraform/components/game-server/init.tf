terraform {
  required_version = "1.12.1"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.30.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.1.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.5.0"
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
