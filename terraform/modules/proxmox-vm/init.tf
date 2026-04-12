terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.101.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.8.0"
    }
  }
}
