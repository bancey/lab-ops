locals {
  k8s_hosts = {
    for cluster_key, cluster in var.kubernetes_virtual_machines : "${cluster_key}_k3s_cluster" => {
      target_nodes       = cluster.target_nodes
      k3s_etcd_datastore = cluster.k3s_etcd_datastore
      metallb_ip_range   = cluster.metallb_ip_range
      masters = {
        for i in range(cluster.master.count) : "${cluster_key}-master${i}" => cidrhost(cluster.master.cidr, i)
      }
      workers = {
        for i in range(cluster.worker.count) : "${cluster_key}-node${i}" => cidrhost(cluster.worker.cidr, i)
      }
    }
  }
}

data "azurerm_key_vault" "vault" {
  name                = "bancey-vault"
  resource_group_name = "common"
}

data "azurerm_key_vault_secret" "github_app_id" {
  name         = "GitHub-Bot-ID"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "github_installation_id" {
  name         = "GitHub-Bot-Installation-ID"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "github_repository" "this" {
  full_name = "bancey/lab-ops"
}
