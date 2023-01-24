module "master" {
  count  = var.master_count
  source = "../../modules/proxmox-vm"

  target_node         = "wanda"
  vm_name             = "master${count.index}"
  vm_id               = local.master_start_vm_id + count.index
  vm_description      = "k8s control plane"
  cpu_cores           = 2
  memory              = 4096
  ip_address          = cidrhost(var.master_cidr, count.index)
  gateway_ip_address  = var.master_gateway_ip_address
  network_bridge_name = "vmbr1"
}

module "nodes" {
  count  = var.node_count
  source = "../../modules/proxmox-vm"

  target_node         = "wanda"
  vm_name             = "node${count.index}"
  vm_id               = local.node_start_vm_id + count.index
  vm_description      = "k8s worker node"
  cpu_cores           = 2
  memory              = 4096
  ip_address          = cidrhost(var.node_cidr, count.index)
  gateway_ip_address  = var.node_gateway_ip_address
  network_bridge_name = "vmbr1"
}

module "k3s_vm" {
  count  = local.vm_count
  source = "../../modules/proxmox-vm"

  target_node         = "wanda"
  vm_name             = count.index >= var.master_count ? "node${count.index}" : "node${count.index - var.node_count}"
  vm_id               = local.master_start_vm_id + count.index
  vm_description      = "k8s control plane"
  cpu_cores           = 2
  memory              = 4096
  ip_address          = cidrhost(var.master_cidr, count.index)
  gateway_ip_address  = var.master_gateway_ip_address
  network_bridge_name = "vmbr1"
}
