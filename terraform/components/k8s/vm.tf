module "master" {
  count  = var.master_count
  source = "../../modules/proxmox-vm"

  target_node    = "wanda"
  vm_name        = "master${count.index}"
  vm_id          = local.master_start_vm_id + count.index
  vm_description = "k8s control plane"
  cpu_cores      = 2
  memory         = 4096
  ip_address     = cidrhost(var.master_cidr, count.index)
}

module "nodes" {
  count  = var.node_count
  source = "../../modules/proxmox-vm"

  target_node    = "wanda"
  vm_name        = "node${count.index}"
  vm_id          = local.node_start_vm_id + count.index
  vm_description = "k8s worker node"
  cpu_cores      = 2
  memory         = 4096
  ip_address     = cidrhost(var.nodes_cidr, count.index)
}
