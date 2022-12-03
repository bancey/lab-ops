module "master" {
  source = "../../modules/proxmox-vm"

  target_node = "wanda"
  vm_name     = "master"
  cpu_cores       = 2
  memory      = 4096
  ip_address  = "192.168.80.16"
}

module "node0" {
  source = "../../modules/proxmox-vm"

  target_node = "wanda"
  vm_name     = "node0"
  cpu_cores       = 2
  memory      = 4096
  ip_address  = "192.168.80.17"
}

module "node1" {
  source = "../../modules/proxmox-vm"

  target_node = "wanda"
  vm_name     = "node1"
  cpu_cores       = 2
  memory      = 4096
  ip_address  = "192.168.80.18"
}
