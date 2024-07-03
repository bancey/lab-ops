terraform {
  required_version = "1.9.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.60.1"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.108.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.35.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.1"
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
  insecure = true
  ssh {
    agent = true
  }
}

provider "proxmox" {
  alias    = "hela"
  endpoint = data.azurerm_key_vault_secret.hela_proxmox_url.value
  username = data.azurerm_key_vault_secret.tiny_proxmox_username.value
  password = data.azurerm_key_vault_secret.tiny_proxmox_password.value
  insecure = true
  ssh {
    agent = true
  }
}

provider "proxmox" {
  alias    = "loki"
  endpoint = data.azurerm_key_vault_secret.loki_proxmox_url.value
  username = data.azurerm_key_vault_secret.tiny_proxmox_username.value
  password = data.azurerm_key_vault_secret.tiny_proxmox_password.value
  insecure = true
  ssh {
    agent = true
  }
}

provider "proxmox" {
  alias    = "thor"
  endpoint = data.azurerm_key_vault_secret.thor_proxmox_url.value
  username = data.azurerm_key_vault_secret.tiny_proxmox_username.value
  password = data.azurerm_key_vault_secret.tiny_proxmox_password.value
  insecure = true
  ssh {
    agent = true
  }
}

provider "cloudflare" {
  api_token = data.azurerm_key_vault_secret.cloudflare_lab_api_token.value
}
