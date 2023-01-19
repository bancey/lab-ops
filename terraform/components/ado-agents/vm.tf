module "migration" {
  source = "../../modules/proxmox-vm"

  target_node    = "wanda"
  vm_name        = "ago-agents"
  vm_id          = 102
  vm_description = "VM for Azure DevOps agents running in containers."
  cpu_cores      = 2
  memory         = 4096
  ip_address     = "192.168.80.22"
  startup_order  = 15
}
