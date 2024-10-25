terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.66.3"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.2"
    }
  }
}
