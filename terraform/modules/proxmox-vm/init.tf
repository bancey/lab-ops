terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.74.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.2"
    }
  }
}
