terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.91.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.6.1"
    }
  }
}
