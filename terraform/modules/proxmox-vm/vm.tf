resource "proxmox_virtual_environment_vm" "vm" {
  name        = var.vm_name
  vm_id       = var.vm_id
  description = var.vm_description
  pool_id     = var.resource_pool
  node_name   = var.target_node
  on_boot     = var.start_on_boot
  tags        = concat(["terraform"], var.tags)

  initialization {
    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id
    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway_ip_address
      }
    }
  }

  startup {
    order    = var.startup_order
    up_delay = var.startup_delay
  }

  agent {
    enabled = true
  }

  cpu {
    cores        = var.cpu_cores
    sockets      = var.cpu_sockets
    architecture = var.cpu_architecture
  }

  memory {
    dedicated = var.memory
  }

  network_device {
    bridge  = var.network_bridge_name
    vlan_id = var.vlan_tag
  }

  operating_system {
    type = "l26"
  }

  disk {
    datastore_id = "local-lvm"
    file_id      = var.image_id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = var.disk_size
  }
}
