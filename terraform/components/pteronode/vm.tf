module "pteronode" {
  source = "../../modules/proxmox-vm"

  target_node    = "wanda"
  vm_name        = "wings1"
  vm_id          = 300
  vm_description = "A Pterodactyl Node"
  cpu_cores      = 1
  memory         = 12288
  ip_address     = "192.168.80.21"
  startup_order  = 15
  startup_delay  = 10
}
