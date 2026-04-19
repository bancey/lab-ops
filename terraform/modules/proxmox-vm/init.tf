terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.103.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.8.0"
    }
  }
}
