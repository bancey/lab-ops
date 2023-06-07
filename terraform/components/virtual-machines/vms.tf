module "virtual_machines" {
  source   = "../../modules/proxmox-vm"
  for_each = var.virtual_machines

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
}
