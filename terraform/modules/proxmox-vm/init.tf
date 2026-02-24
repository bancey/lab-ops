terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.97.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.7.0"
    }
  }
}
