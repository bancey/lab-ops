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
      keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC8GRj4esk6kfB54F2h3M25PgcyOAl8mEey5BgHVkel05g+dBUGb/ERmoQ5itrMNhOy2mtrsguHDEW9tatwmKfmQQvZcbGKAt/BZjnQtTa/5iPdmq6C/B0URr7oTBBS9ClDfJOQNIxBKFcIujpkVtQHN84UhAw8UMwEMdKQtgiW1chUERSAuMQ+qzNtoFnZ1Do3C5gSiX0d1eZWr8UqCUab4cpjLnTQZO2KDIrrVJ1H9FGFida4vXEReDKxpzxp6IL+JjWwEzBF0TavPNRPRnbVdro+PT5Fk4Jz+GJtX4191xz1ePwbGKRYpyJQg58s9/nl5UobMvQNsx/cBAlX6ebemMcjD9YiCC1HK3rU9a5v8TDffqVpG50fbuL+c7aWWshMeIveat4WFTGPgnvAvT+ojQSSi2cVIL5qB/7s3uZkCOXTGeaTeKvCTF+d5U6DMjbTP5oOPGpcgWGzqvxT+0/fVDRQayTTsNGfxRGCDRwEIqBKSbo6HnMmQSt6zXtICUfVmldm+20kIwtaqej98tDRsB1/WUnaQaIjCeGHv8rZoqPla9t+8vk9bTHrJ6h9pxacNnECrtcSvA0Zs7u8Z3wkEVm25Uq6Kzdl8NqhWLIG8ct7Mmgs7p3Oj/5Qsrnt2+zUdVGOXwCKiDQnMsoeJ9/a3/p4pY+tnx6d9M5sbourxQ== alexb@Bancey-W11"
      ]
    }
  }

  network_interface {
    name    = "veth0"
    bridge  = each.value.network_bridge_name
    vlan_id = each.value.vlan_tag
  }

  operating_system {
    template_file_id = "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
    type             = "ubuntu"
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

  unprivileged = true
  features {
    nesting = true
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
      keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC8GRj4esk6kfB54F2h3M25PgcyOAl8mEey5BgHVkel05g+dBUGb/ERmoQ5itrMNhOy2mtrsguHDEW9tatwmKfmQQvZcbGKAt/BZjnQtTa/5iPdmq6C/B0URr7oTBBS9ClDfJOQNIxBKFcIujpkVtQHN84UhAw8UMwEMdKQtgiW1chUERSAuMQ+qzNtoFnZ1Do3C5gSiX0d1eZWr8UqCUab4cpjLnTQZO2KDIrrVJ1H9FGFida4vXEReDKxpzxp6IL+JjWwEzBF0TavPNRPRnbVdro+PT5Fk4Jz+GJtX4191xz1ePwbGKRYpyJQg58s9/nl5UobMvQNsx/cBAlX6ebemMcjD9YiCC1HK3rU9a5v8TDffqVpG50fbuL+c7aWWshMeIveat4WFTGPgnvAvT+ojQSSi2cVIL5qB/7s3uZkCOXTGeaTeKvCTF+d5U6DMjbTP5oOPGpcgWGzqvxT+0/fVDRQayTTsNGfxRGCDRwEIqBKSbo6HnMmQSt6zXtICUfVmldm+20kIwtaqej98tDRsB1/WUnaQaIjCeGHv8rZoqPla9t+8vk9bTHrJ6h9pxacNnECrtcSvA0Zs7u8Z3wkEVm25Uq6Kzdl8NqhWLIG8ct7Mmgs7p3Oj/5Qsrnt2+zUdVGOXwCKiDQnMsoeJ9/a3/p4pY+tnx6d9M5sbourxQ== alexb@Bancey-W11"
      ]
    }
  }

  network_interface {
    name    = "veth0"
    bridge  = each.value.network_bridge_name
    vlan_id = each.value.vlan_tag
  }

  operating_system {
    template_file_id = "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
    type             = "ubuntu"
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

  unprivileged = false
  features {
    nesting = true
  }
}
