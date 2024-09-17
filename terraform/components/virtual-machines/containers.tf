resource "proxmox_virtual_environment_container" "wanda_containers" {
  provider = proxmox.wanda
  for_each = { for key, value in var.containers : key => value if(lower(value.node) == "wanda" && contains(var.target_nodes, lower(value.node))) }

  node_name   = each.value.node
  vm_id       = each.value.ct_id
  description = each.value.ct_description

  initialization {
    hostname = each.key

    ip_config {
      ipv4 {
        address = each.value.ip_address
        gateway = each.value.gateway_ip_address
      }
    }

    user_account {
      password = data.azurerm_key_vault_secret.lab_vm_password.value
    }
  }

  network_interface {
    name    = each.value.network_bridge_name
    vlan_id = each.value.vlan_tag
  }

  operating_system {
    template_file_id = "local:vztmpl/${each.value.image}"
    type             = each.value.image_type
  }

  disk {
    datastore_id = each.value.storage
    size         = "8"
  }

  cpu {
    architecture = "amd64"
    cores        = each.value.cpu_cores
  }

  memory {
    dedicated = each.value.memory
  }

  startup {
    order    = each.value.startup_order
    up_delay = each.value.startup_delay
  }
}

resource "proxmox_virtual_environment_container" "tiny_containers" {
  provider = proxmox.tiny
  for_each = { for key, value in var.containers : key => value if(contains(local.tiny_nodes, lower(value.node)) && contains(var.target_nodes, lower(value.node))) }

  node_name   = each.value.node
  vm_id       = each.value.ct_id
  description = each.value.ct_description

  initialization {
    hostname = each.key

    ip_config {
      ipv4 {
        address = each.value.ip_address
        gateway = each.value.gateway_ip_address
      }
    }

    user_account {
      password = data.azurerm_key_vault_secret.lab_vm_password.value
    }
  }

  network_interface {
    name    = each.value.network_bridge_name
    vlan_id = each.value.vlan_tag
  }

  operating_system {
    template_file_id = "local:vztmpl/${each.value.image}"
    type             = each.value.image_type
  }

  disk {
    datastore_id = each.value.storage
    size         = "8"
  }

  cpu {
    architecture = "amd64"
    cores        = each.value.cpu_cores
  }

  memory {
    dedicated = each.value.memory
  }

  startup {
    order    = each.value.startup_order
    up_delay = each.value.startup_delay
  }
}
