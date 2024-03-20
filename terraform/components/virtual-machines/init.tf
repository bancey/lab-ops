terraform {
  required_version = "1.7.5"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.49.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.96.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.26.0"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

provider "proxmox" {
  alias     = "wanda"
  endpoint  = data.azurerm_key_vault_secret.wanda_proxmox_url.value
  api_token = data.azurerm_key_vault_secret.wanda_proxmox_token.value
  insecure  = true
  ssh {
    agent    = true
    username = split("@", data.azurerm_key_vault_secret.wanda_proxmox_token.value)[0]
  }
}

provider "proxmox" {
  alias     = "hela"
  endpoint  = data.azurerm_key_vault_secret.hela_proxmox_url.value
  api_token = data.azurerm_key_vault_secret.tiny_proxmox_token.value
  insecure  = true
  ssh {
    agent    = true
    username = split("@", data.azurerm_key_vault_secret.tiny_proxmox_token.value)[0]
  }
}

provider "proxmox" {
  alias     = "loki"
  endpoint  = data.azurerm_key_vault_secret.loki_proxmox_url.value
  api_token = data.azurerm_key_vault_secret.tiny_proxmox_token.value
  insecure  = true
  ssh {
    agent    = true
    username = split("@", data.azurerm_key_vault_secret.tiny_proxmox_token.value)[0]
  }
}

provider "proxmox" {
  alias     = "thor"
  endpoint  = data.azurerm_key_vault_secret.thor_proxmox_url.value
  api_token = data.azurerm_key_vault_secret.tiny_proxmox_token.value
  insecure  = true
  ssh {
    agent    = true
    username = split("@", data.azurerm_key_vault_secret.tiny_proxmox_token.value)[0]
  }
}

provider "cloudflare" {
  api_token = data.azurerm_key_vault_secret.cloudflare_lab_api_token.value
}
