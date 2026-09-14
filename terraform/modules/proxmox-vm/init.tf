terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.113.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.9.0"
    }
  }
}
