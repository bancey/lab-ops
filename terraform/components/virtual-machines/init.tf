terraform {
  required_version = "1.4.6"
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "2.9.14"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.52.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.3.0"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

provider "proxmox" {
  pm_api_url          = data.azurerm_key_vault_secret.proxmox_url.value
  pm_api_token_id     = data.azurerm_key_vault_secret.proxmox_token_id.value
  pm_api_token_secret = data.azurerm_key_vault_secret.proxmox_token_secret.value
  pm_tls_insecure     = true
}

provider "cloudflare" {
  api_token = data.azurerm_key_vault_secret.cloudflare_lab_api_token.value
}
