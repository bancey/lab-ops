terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.55.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.1"
    }
  }
}
