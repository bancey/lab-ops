module "wanda_containers" {
  providers = {
    proxmox = proxmox.wanda
  }

  source   = "../../modules/proxmox-ct"
  for_each = { for key, value in var.containers : key => value if(lower(value.node) == "wanda" && contains(var.target_nodes, lower(value.node))) }

  target_node         = each.value.node
  ct_name             = each.key
  ct_id               = each.value.ct_id
  ct_description      = each.value.ct_description
  ip_address          = each.value.ip_address
  gateway_ip_address  = each.value.gateway_ip_address
  network_bridge_name = each.value.network_bridge_name
  vlan_tag            = each.value.vlan_tag
  password            = data.azurerm_key_vault_secret.lab_vm_password.value

  cpu_cores  = 1
  memory     = 512
  image_id   = "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
  image_type = "ubuntu"
}

module "tiny_containers" {
  providers = {
    proxmox = proxmox.tiny
  }

  source   = "../../modules/proxmox-ct"
  for_each = { for key, value in var.containers : key => value if(contains(local.tiny_nodes, lower(value.node)) && contains(var.target_nodes, lower(value.node))) }

  target_node         = each.value.node
  ct_name             = each.key
  ct_id               = each.value.ct_id
  ct_description      = each.value.ct_description
  ip_address          = each.value.ip_address
  gateway_ip_address  = each.value.gateway_ip_address
  network_bridge_name = each.value.network_bridge_name
  vlan_tag            = each.value.vlan_tag
  password            = data.azurerm_key_vault_secret.lab_vm_password.value

  cpu_cores  = 1
  memory     = 512
  image_id   = "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
  image_type = "ubuntu"
}
