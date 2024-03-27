locals {
  master_vms = flatten([
    for vm_key, vm_value in var.kubernetes_virtual_machines : [
      for i in range(vm_value.master.count) : {
        target_node         = length(vm_value.target_nodes) > 1 ? vm_value.target_nodes[i] : vm_value.target_nodes[0]
        vm_name             = "master${i}"
        vm_id               = vm_value.master.vm_id_start + i
        vm_description      = "k8s control plane"
        cpu_cores           = 4
        memory              = 8192
        ip_address          = cidrhost(vm_value.master.cidr, i)
        gateway_ip_address  = vm_value.master.gateway_ip_address
        network_bridge_name = vm_value.master.network_bridge_name
        vlan_tag            = vm_value.master.vlan_tag
        startup_delay       = 0
        startup_order       = 10
        tags                = ["k8s", "k8s-control-plane"]
      }
    ]
  ])
  worker_vms = flatten([
    for vm_key, vm_value in var.kubernetes_virtual_machines : [
      for i in range(vm_value.worker.count) : {
        target_node         = length(vm_value.target_nodes) > 1 ? vm_value.target_nodes[i] : vm_value.target_nodes[0]
        vm_name             = "node${i}"
        vm_id               = vm_value.worker.vm_id_start + i
        vm_description      = "k8s worker node"
        cpu_cores           = 2
        memory              = 4096
        ip_address          = cidrhost(vm_value.worker.cidr, i)
        gateway_ip_address  = vm_value.worker.gateway_ip_address
        network_bridge_name = vm_value.worker.network_bridge_name
        vlan_tag            = vm_value.worker.vlan_tag
        startup_delay       = 0
        startup_order       = 15
        tags                = ["k8s", "k8s-worker"]
      }
    ]
  ])
}

data "azurerm_client_config" "current" {}

data "azurerm_key_vault" "vault" {
  name                = "bancey-vault"
  resource_group_name = "common"
}

data "azurerm_key_vault_secret" "wanda_proxmox_url" {
  name         = "Wanda-Proxmox-URL"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "hela_proxmox_url" {
  name         = "Hela-Proxmox-URL"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "loki_proxmox_url" {
  name         = "Loki-Proxmox-URL"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "thor_proxmox_url" {
  name         = "Thor-Proxmox-URL"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "wanda_proxmox_username" {
  name         = "Wanda-Proxmox-Username"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "wanda_proxmox_password" {
  name         = "Wanda-Proxmox-Password"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "tiny_proxmox_username" {
  name         = "Tiny-Proxmox-Username"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "tiny_proxmox_password" {
  name         = "Tiny-Proxmox-Password"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "lab_vm_username" {
  name         = "Lab-VM-Username"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "lab_vm_password" {
  name         = "Lab-VM-Password"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "cloudflare_lab_zone_id" {
  name         = "Cloudflare-Lab-Zone-ID"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "cloudflare_lab_zone_name" {
  name         = "Cloudflare-Lab-Zone-Name"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "cloudflare_lab_api_token" {
  name         = "Cloudflare-Lab-API-Token"
  key_vault_id = data.azurerm_key_vault.vault.id
}
