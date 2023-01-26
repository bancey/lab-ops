module "k3s_vm" {
  count  = local.vm_count
  source = "../../modules/proxmox-vm"

  target_node         = "wanda"
  vm_name             = count.index >= var.master_count ? "node${count.index - var.node_count}" : "master${count.index}"
  vm_id               = count.index >= var.master_count ? local.node_start_vm_id + (count.index - var.node_count) : local.master_start_vm_id + count.index
  vm_description      = count.index >= var.master_count ? "k8s worker node" : "k8s control plane"
  cpu_cores           = 2
  memory              = 4096
  ip_address          = count.index >= var.master_count ? cidrhost(var.node_cidr, (count.index - var.node_count)) : cidrhost(var.master_cidr, count.index)
  gateway_ip_address  = count.index >= var.master_count ? var.node_gateway_ip_address : var.master_gateway_ip_address
  network_bridge_name = var.network_bridge_name
  vlan_tag            = var.vlan_tag
  resource_pool       = "k8s"
}
