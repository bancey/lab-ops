terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.108.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.9.0"
    }
  }
}
