module "virtual_machines" {
  source   = "../../modules/proxmox-vm"
  for_each = var.virtual_machines

  target_node    = each.value.node
  vm_name        = each.key
  vm_id          = each.value.vm_id
  vm_description = each.value.vm_description
  cpu_cores      = each.value.cpu_cores
  memory         = each.value.memory
  ip_address     = each.value.ip_address
  startup_order  = each.value.startup_order
  startup_delay  = each.value.startup_delay
}
