module "master" {
  source = "../../modules/proxmox-vm"

  target_node    = "wanda"
  vm_name        = "master"
  vm_description = "k8s control plane"
  cpu_cores      = 2
  memory         = 4096
  ip_address     = "192.168.80.16"
}

module "node0" {
  source = "../../modules/proxmox-vm"

  target_node    = "wanda"
  vm_name        = "node0"
  vm_description = "k8s worker node"
  cpu_cores      = 2
  memory         = 4096
  ip_address     = "192.168.80.17"
}

module "node1" {
  source = "../../modules/proxmox-vm"

  target_node    = "wanda"
  vm_name        = "node1"
  vm_description = "k8s worker node"
  cpu_cores      = 2
  memory         = 4096
  ip_address     = "192.168.80.18"
}
