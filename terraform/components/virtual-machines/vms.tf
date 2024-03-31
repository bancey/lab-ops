module "wanda_virtual_machines" {
  providers = {
    proxmox = proxmox.wanda
  }

  source   = "../../modules/proxmox-vm"
  for_each = { for key, value in var.virtual_machines : key => value if(lower(value.node) == "wanda" && contains(var.target_nodes, lower(value.node))) }

  target_node         = each.value.node
  vm_name             = each.key
  vm_id               = each.value.vm_id
  vm_description      = each.value.vm_description
  cpu_cores           = each.value.cpu_cores
  memory              = each.value.memory
  ip_address          = "${each.value.ip_address}/24"
  gateway_ip_address  = each.value.gateway_ip_address
  network_bridge_name = each.value.network_bridge_name
  vlan_tag            = each.value.vlan_tag
  startup_order       = each.value.startup_order
  startup_delay       = each.value.startup_delay
  storage             = each.value.storage
  username            = data.azurerm_key_vault_secret.lab_vm_username.value
  password            = data.azurerm_key_vault_secret.lab_vm_password.value
  image_id            = proxmox_virtual_environment_download_file.wanda_ubuntu_cloud_image[0].id
}

module "hela_virtual_machines" {
  providers = {
    proxmox = proxmox.hela
  }

  source   = "../../modules/proxmox-vm"
  for_each = { for key, value in var.virtual_machines : key => value if(lower(value.node) == "hela" && contains(var.target_nodes, lower(value.node))) }

  target_node         = each.value.node
  vm_name             = each.key
  vm_id               = each.value.vm_id
  vm_description      = each.value.vm_description
  cpu_cores           = each.value.cpu_cores
  memory              = each.value.memory
  ip_address          = "${each.value.ip_address}/24"
  gateway_ip_address  = each.value.gateway_ip_address
  network_bridge_name = each.value.network_bridge_name
  vlan_tag            = each.value.vlan_tag
  startup_order       = each.value.startup_order
  startup_delay       = each.value.startup_delay
  storage             = each.value.storage
  username            = data.azurerm_key_vault_secret.lab_vm_username.value
  password            = data.azurerm_key_vault_secret.lab_vm_password.value
  image_id            = proxmox_virtual_environment_download_file.hela_ubuntu_cloud_image[0].id
}

module "loki_virtual_machines" {
  providers = {
    proxmox = proxmox.loki
  }

  source   = "../../modules/proxmox-vm"
  for_each = { for key, value in var.virtual_machines : key => value if(lower(value.node) == "loki" && contains(var.target_nodes, lower(value.node))) }

  target_node         = each.value.node
  vm_name             = each.key
  vm_id               = each.value.vm_id
  vm_description      = each.value.vm_description
  cpu_cores           = each.value.cpu_cores
  memory              = each.value.memory
  ip_address          = "${each.value.ip_address}/24"
  gateway_ip_address  = each.value.gateway_ip_address
  network_bridge_name = each.value.network_bridge_name
  vlan_tag            = each.value.vlan_tag
  startup_order       = each.value.startup_order
  startup_delay       = each.value.startup_delay
  storage             = each.value.storage
  username            = data.azurerm_key_vault_secret.lab_vm_username.value
  password            = data.azurerm_key_vault_secret.lab_vm_password.value
  image_id            = proxmox_virtual_environment_download_file.loki_ubuntu_cloud_image[0].id
}

module "thor_virtual_machines" {
  providers = {
    proxmox = proxmox.thor
  }

  source   = "../../modules/proxmox-vm"
  for_each = { for key, value in var.virtual_machines : key => value if(lower(value.node) == "thor" && contains(var.target_nodes, lower(value.node))) }

  target_node         = each.value.node
  vm_name             = each.key
  vm_id               = each.value.vm_id
  vm_description      = each.value.vm_description
  cpu_cores           = each.value.cpu_cores
  memory              = each.value.memory
  ip_address          = "${each.value.ip_address}/24"
  gateway_ip_address  = each.value.gateway_ip_address
  network_bridge_name = each.value.network_bridge_name
  vlan_tag            = each.value.vlan_tag
  startup_order       = each.value.startup_order
  startup_delay       = each.value.startup_delay
  storage             = each.value.storage
  username            = data.azurerm_key_vault_secret.lab_vm_username.value
  password            = data.azurerm_key_vault_secret.lab_vm_password.value
  image_id            = proxmox_virtual_environment_download_file.thor_ubuntu_cloud_image[0].id
}
