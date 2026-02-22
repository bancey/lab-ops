locals {
  master_vms = flatten([
    for cluster_key, cluster in var.kubernetes_virtual_machines : [
      for i in range(cluster.master.count) : {
        cluster_key         = cluster_key
        target_node         = length(cluster.target_nodes) > 1 ? cluster.target_nodes[i % length(cluster.target_nodes)] : cluster.target_nodes[0]
        vm_name             = "${cluster_key}-master${i}"
        vm_id               = cluster.master.vm_id_start + i
        vm_description      = "k8s control plane"
        cpu_cores           = cluster.master.cpu_cores
        memory              = cluster.master.memory
        disk_size           = try(cluster.master, "disk_size", null) != null ? cluster.master.disk_size : cluster.disk_size
        ip_address          = cidrhost(cluster.master.cidr, i)
        gateway_ip_address  = cluster.master.gateway_ip_address
        network_bridge_name = cluster.master.network_bridge_name
        vlan_tag            = cluster.master.vlan_tag
        startup_delay       = 0
        startup_order       = 10
        tags                = ["k8s", "k8s-control-plane"]
        image               = "local:iso/${cluster.image}"
      }
    ]
  ])
  worker_vms = flatten([
    for cluster_key, cluster in var.kubernetes_virtual_machines : [
      for i in range(cluster.worker.count) : {
        target_node         = length(cluster.target_nodes) > 1 ? cluster.target_nodes[i % length(cluster.target_nodes)] : cluster.target_nodes[0]
        vm_name             = "${cluster_key}-node${i}"
        vm_id               = cluster.worker.vm_id_start + i
        vm_description      = "k8s worker node"
        cpu_cores           = cluster.worker.cpu_cores
        memory              = cluster.worker.memory
        disk_size           = try(cluster.worker, "disk_size", null) != null ? cluster.master.disk_size : cluster.disk_size
        ip_address          = cidrhost(cluster.worker.cidr, i)
        gateway_ip_address  = cluster.worker.gateway_ip_address
        network_bridge_name = cluster.worker.network_bridge_name
        vlan_tag            = cluster.worker.vlan_tag
        startup_delay       = 0
        startup_order       = 15
        tags                = ["k8s", "k8s-worker"]
        image               = "local:iso/${cluster.image}"
      }
    ]
  ])
  tiny_nodes = ["hela", "loki", "thor"]
  set_images = [
    for key, value in var.images : {
      key   = key
      value = value
    }
  ]
  ansible_secrets = flatten([
    for key, value in var.ansible : [
      for arg_name, secret_name in value.secrets : {
        key           = "${key}_${arg_name}"
        ansible_key   = key
        argument_name = arg_name
        secret_name   = secret_name
      }
    ] if length(value.secrets) > 0
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

data "azurerm_key_vault_secret" "tiny_proxmox_url" {
  name         = "Tiny-Proxmox-URL"
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
