module "wanda_virtual_machines" {
  providers = {
    proxmox = proxmox.wanda
  }

  source   = "../../modules/proxmox-vm"
  for_each = { for key, value in var.var.virtual_machines : key => value if lower(value.node) == "wanda" }

  target_node         = each.value.node
  vm_name             = each.key
  vm_id               = each.value.vm_id
  vm_description      = each.value.vm_description
  cpu_cores           = each.value.cpu_cores
  memory              = each.value.memory
  ip_address          = each.value.ip_address
  gateway_ip_address  = each.value.gateway_ip_address
  network_bridge_name = each.value.network_bridge_name
  vlan_tag            = each.value.vlan_tag
  startup_order       = each.value.startup_order
  startup_delay       = each.value.startup_delay
  storage             = each.value.storage
  username            = data.azurerm_key_vault_secret.lab_vm_username.value
  password            = data.azurerm_key_vault_secret.lab_vm_password.value
}

module "hela_virtual_machines" {
  providers = {
    proxmox = proxmox.hela
  }

  source   = "../../modules/proxmox-vm"
  for_each = { for key, value in var.var.virtual_machines : key => value if lower(value.node) == "hela" }

  target_node         = each.value.node
  vm_name             = each.key
  vm_id               = each.value.vm_id
  vm_description      = each.value.vm_description
  cpu_cores           = each.value.cpu_cores
  memory              = each.value.memory
  ip_address          = each.value.ip_address
  gateway_ip_address  = each.value.gateway_ip_address
  network_bridge_name = each.value.network_bridge_name
  vlan_tag            = each.value.vlan_tag
  startup_order       = each.value.startup_order
  startup_delay       = each.value.startup_delay
  storage             = each.value.storage
  username            = data.azurerm_key_vault_secret.lab_vm_username.value
  password            = data.azurerm_key_vault_secret.lab_vm_password.value
}

module "loki_virtual_machines" {
  providers = {
    proxmox = proxmox.loki
  }

  source   = "../../modules/proxmox-vm"
  for_each = { for key, value in var.var.virtual_machines : key => value if lower(value.node) == "loki" }

  target_node         = each.value.node
  vm_name             = each.key
  vm_id               = each.value.vm_id
  vm_description      = each.value.vm_description
  cpu_cores           = each.value.cpu_cores
  memory              = each.value.memory
  ip_address          = each.value.ip_address
  gateway_ip_address  = each.value.gateway_ip_address
  network_bridge_name = each.value.network_bridge_name
  vlan_tag            = each.value.vlan_tag
  startup_order       = each.value.startup_order
  startup_delay       = each.value.startup_delay
  storage             = each.value.storage
  username            = data.azurerm_key_vault_secret.lab_vm_username.value
  password            = data.azurerm_key_vault_secret.lab_vm_password.value
}

module "thor_virtual_machines" {
  providers = {
    proxmox = proxmox.thor
  }

  source   = "../../modules/proxmox-vm"
  for_each = { for key, value in var.var.virtual_machines : key => value if lower(value.node) == "thor" }

  target_node         = each.value.node
  vm_name             = each.key
  vm_id               = each.value.vm_id
  vm_description      = each.value.vm_description
  cpu_cores           = each.value.cpu_cores
  memory              = each.value.memory
  ip_address          = each.value.ip_address
  gateway_ip_address  = each.value.gateway_ip_address
  network_bridge_name = each.value.network_bridge_name
  vlan_tag            = each.value.vlan_tag
  startup_order       = each.value.startup_order
  startup_delay       = each.value.startup_delay
  storage             = each.value.storage
  username            = data.azurerm_key_vault_secret.lab_vm_username.value
  password            = data.azurerm_key_vault_secret.lab_vm_password.value
}
