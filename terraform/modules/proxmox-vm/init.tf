terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.67.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.2"
    }
  }
}
