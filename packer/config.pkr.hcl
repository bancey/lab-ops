packer {
  required_plugins {
    proxmox = {
      version = "1.1.3"
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

variable "vm_storage" {
  type = string
  default = "local-lvm"
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
  default = 2
}

variable "vm_memory" {
  type    = number
  default = 4098
}

variable "username" {
  type    = string
  default = "bancey"
}

variable "ssh_private_key_file" {
  type = string
}

variable "http_directory" {
  type    = string
  default = "http"
}

variable "http_interface" {
  type    = string
  default = null
}

variable "files_directory" {
  type    = string
  default = "files"
}

variable "boot_command" {
  type = list(string)
}

variable "primary_provisioner_commands" {
  type    = list(string)
  default = []
}

variable "secondary_provisioner_commands" {
  type    = list(string)
  default = []
}

source "proxmox-iso" "template" {
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

  os = "l26"

  disks {
    disk_size         = "20G"
    format            = "raw"
    storage_pool      = var.vm_storage
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
  cloud_init_storage_pool = var.vm_storage

  # PACKER Boot Commands
  boot_command = var.boot_command
  boot         = "c"
  boot_wait    = "20s"

  http_directory = "${path.cwd}/${var.http_directory}"
  http_interface = var.http_interface

  ssh_username         = "${var.username}"
  ssh_private_key_file = "${var.ssh_private_key_file}"
  ssh_timeout          = "20m"
}

# Build Definition to create the VM Template
build {

  name    = var.vm_name
  sources = ["source.proxmox-iso.template"]

  provisioner "shell" {
    inline = var.primary_provisioner_commands
  }

  provisioner "file" {
    source      = "${path.cwd}/${var.files_directory}"
    destination = "/tmp"
  }

  provisioner "shell" {
    inline = var.secondary_provisioner_commands
  }
}