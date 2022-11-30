packer {
  required_plugins {
    proxmox = {
      version = "1.1.0"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

variable "proxmox_api_url" {
  type = string
}

variable "proxmox_api_token_id" {
  type = string
}

variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
}

variable "node" {
  type = string
}

variable "vm_id" {
  type = number
}

variable "vm_name" {
  type = string
}

variable "template_description" {
  type = string
}

variable "iso_url" {
  type = string
}

variable "iso_checksum" {
  type = string
}

variable "vm_cores" {
  type    = number
  default = 1
}

variable "vm_memory" {
  type    = number
  default = 2048
}

variable "username" {
  type    = string
  default = "packer"
}

variable "password" {
  type      = string
  sensitive = true
}

variable "http_directory" {
  type    = string
  default = "http"
}

variable "files_directory" {
  type    = string
  default = "files"
}

variable "primary_provisioner_commands" {
  type    = list(string)
  default = []
}

variable "secondary_provisioner_commands" {
  type    = list(string)
  default = []
}

source "proxmox" "proxmox-template" {
  # Proxmox Connection Settings
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true

  # VM General Settings
  node                 = var.node
  vm_id                = var.vm_id
  vm_name              = var.vm_name
  template_description = var.template_description

  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  iso_storage_pool = "local"
  unmount_iso      = true

  # VM System Settings
  qemu_agent = true

  # VM Hard Disk Settings
  scsi_controller = "virtio-scsi-pci"

  os = "126"

  disks {
    disk_size         = "20G"
    format            = "raw"
    storage_pool      = "local-lvm"
    storage_pool_type = "lvm"
    type              = "virtio"
  }

  # VM CPU Settings
  cores = var.vm_cores

  # VM Memory Settings
  memory = var.vm_memory

  # VM Network Settings
  network_adapters {
    model    = "virtio"
    bridge   = "vmbr0"
    firewall = "false"
  }

  # VM Cloud-Init Settings
  cloud_init              = true
  cloud_init_storage_pool = "local-lvm"

  # PACKER Boot Commands
  boot_command = [
    "<esc><wait>",
    "e<wait>",
    "<down><down><down><end>",
    "<bs><bs><bs><bs><wait>",
    "autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>",
    "<f10><wait>"
  ]
  boot      = "c"
  boot_wait = "5s"

  http_directory = "${path.cwd}/${var.http_directory}"

  ssh_username = var.username
  ssh_password = var.password
  ssh_timeout  = "20m"
}

# Build Definition to create the VM Template
build {

  name    = var.vm_name
  sources = ["source.proxmox.proxmox-template"]

  provisioner "shell" {
    inline = var.primary_provisioner_commands
  }

  provisioner "file" {
    source      = "${path.cwd}/${var.files_directory}/99-pve.cfg"
    destination = "/tmp/99-pve.cfg"
  }

  provisioner "shell" {
    inline = var.secondary_provisioner_commands
  }

}