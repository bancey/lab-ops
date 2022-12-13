module "migration" {
  source = "../../modules/proxmox-vm"

  target_node    = "wanda"
  vm_name        = "migration"
  vm_description = "Temporary migration VM to allow me to decommission the physical host."
  cpu_cores      = 2
  memory         = 8192
  ip_address     = "192.168.80.20"
  startup_order  = 15
}
