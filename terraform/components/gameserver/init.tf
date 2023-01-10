terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.37.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.4.3"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.4"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "3.31.0"
    }
    ovh = {
      source  = "ovh/ovh"
      version = "0.25.0"
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

provider "ovh" {
  endpoint           = data.azurerm_key_vault_secret.ovh_endpoint.value
  application_key    = data.azurerm_key_vault_secret.ovh_application_key.value
  application_secret = data.azurerm_key_vault_secret.ovh_application_secret.value
  consumer_key       = data.azurerm_key_vault_secret.ovh_consumer_key.value
}
