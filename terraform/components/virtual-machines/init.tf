terraform {
  required_version = "1.14.6"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.97.1"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.62.1"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.18.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.7.0"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

provider "local" {}

provider "proxmox" {
  alias    = "wanda"
  endpoint = data.azurerm_key_vault_secret.wanda_proxmox_url.value
  username = data.azurerm_key_vault_secret.wanda_proxmox_username.value
  password = data.azurerm_key_vault_secret.wanda_proxmox_password.value
  ssh {
    agent = true
  }
}

provider "proxmox" {
  alias    = "tiny"
  endpoint = data.azurerm_key_vault_secret.tiny_proxmox_url.value
  username = data.azurerm_key_vault_secret.tiny_proxmox_username.value
  password = data.azurerm_key_vault_secret.tiny_proxmox_password.value
  ssh {
    agent = true
  }
}

provider "cloudflare" {
  api_token = data.azurerm_key_vault_secret.cloudflare_lab_api_token.value
}
