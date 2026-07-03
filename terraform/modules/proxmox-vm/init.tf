terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.111.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.9.0"
    }
  }
}
