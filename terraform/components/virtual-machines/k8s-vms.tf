module "wanda_k8s_virtual_machines" {
  providers = {
    proxmox = proxmox.wanda
  }

  source   = "../../modules/proxmox-vm"
  for_each = { for value in concat(local.master_vms, local.worker_vms) : "${value.target_node}-${value.vm_name}" => value if(lower(value.target_node) == "wanda" && contains(var.target_nodes, lower(value.target_node))) }

  target_node         = each.value.target_node
  vm_name             = each.value.vm_name
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
  storage             = "local-lvm"
  username            = data.azurerm_key_vault_secret.lab_vm_username.value
  password            = data.azurerm_key_vault_secret.lab_vm_password.value
  image_id            = each.value.image
  disk_size           = each.value.disk_size
  tags                = each.value.tags
}

module "tiny_k8s_virtual_machines" {
  providers = {
    proxmox = proxmox.tiny
  }

  source   = "../../modules/proxmox-vm"
  for_each = { for value in concat(local.master_vms, local.worker_vms) : "${value.target_node}-${value.vm_name}" => value if(contains(local.tiny_nodes, lower(value.target_node)) && contains(var.target_nodes, lower(value.target_node))) }

  target_node         = each.value.target_node
  vm_name             = each.value.vm_name
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
  storage             = "local-lvm"
  username            = data.azurerm_key_vault_secret.lab_vm_username.value
  password            = data.azurerm_key_vault_secret.lab_vm_password.value
  image_id            = each.value.image
  disk_size           = each.value.disk_size
  tags                = each.value.tags
}

moved {
  from = module.hela_k8s_virtual_machines["hela-tiny-master0"].proxmox_virtual_environment_file.cloud_config
  to   = module.tiny_k8s_virtual_machines["hela-tiny-master0"].proxmox_virtual_environment_file.cloud_config
}
moved {
  from = module.hela_k8s_virtual_machines["hela-tiny-master0"].proxmox_virtual_environment_vm.vm
  to   = module.tiny_k8s_virtual_machines["hela-tiny-master0"].proxmox_virtual_environment_vm.vm
}
moved {
  from = module.hela_k8s_virtual_machines["hela-tiny-node0"].proxmox_virtual_environment_file.cloud_config
  to   = module.tiny_k8s_virtual_machines["hela-tiny-node0"].proxmox_virtual_environment_file.cloud_config
}
moved {
  from = module.hela_k8s_virtual_machines["hela-tiny-node0"].proxmox_virtual_environment_vm.vm
  to   = module.tiny_k8s_virtual_machines["hela-tiny-node0"].proxmox_virtual_environment_vm.vm
}
moved {
  from = module.loki_k8s_virtual_machines["loki-tiny-master1"].proxmox_virtual_environment_file.cloud_config
  to   = module.tiny_k8s_virtual_machines["loki-tiny-master1"].proxmox_virtual_environment_file.cloud_config
}
moved {
  from = module.loki_k8s_virtual_machines["loki-tiny-master1"].proxmox_virtual_environment_vm.vm
  to   = module.tiny_k8s_virtual_machines["loki-tiny-master1"].proxmox_virtual_environment_vm.vm
}
moved {
  from = module.loki_k8s_virtual_machines["loki-tiny-node1"].proxmox_virtual_environment_file.cloud_config
  to   = module.tiny_k8s_virtual_machines["loki-tiny-node1"].proxmox_virtual_environment_file.cloud_config
}
moved {
  from = module.loki_k8s_virtual_machines["loki-tiny-node1"].proxmox_virtual_environment_vm.vm
  to   = module.tiny_k8s_virtual_machines["loki-tiny-node1"].proxmox_virtual_environment_vm.vm
}
moved {
  from = module.thor_k8s_virtual_machines["thor-tiny-master2"].proxmox_virtual_environment_file.cloud_config
  to   = module.tiny_k8s_virtual_machines["thor-tiny-master2"].proxmox_virtual_environment_file.cloud_config
}
moved {
  from = module.thor_k8s_virtual_machines["thor-tiny-master2"].proxmox_virtual_environment_vm.vm
  to   = module.tiny_k8s_virtual_machines["thor-tiny-master2"].proxmox_virtual_environment_vm.vm
}
moved {
  from = module.thor_k8s_virtual_machines["thor-tiny-node2"].proxmox_virtual_environment_file.cloud_config
  to   = module.tiny_k8s_virtual_machines["thor-tiny-node2"].proxmox_virtual_environment_file.cloud_config
}
moved {
  from = module.thor_k8s_virtual_machines["thor-tiny-node2"].proxmox_virtual_environment_vm.vm
  to   = module.tiny_k8s_virtual_machines["thor-tiny-node2"].proxmox_virtual_environment_vm.vm
}
