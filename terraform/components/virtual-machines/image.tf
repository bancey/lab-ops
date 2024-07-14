resource "proxmox_virtual_environment_download_file" "wanda_images" {
  for_each       = var.target_nodes == null ? {} : contains(var.target_nodes, "wanda") ? var.images : {}
  provider       = proxmox.wanda
  content_type   = "iso"
  datastore_id   = "local"
  node_name      = "wanda"
  file_name      = each.key
  url            = each.value
  upload_timeout = 2400
  overwrite      = false
}

resource "proxmox_virtual_environment_download_file" "hela_images" {
  for_each       = var.target_nodes == null ? {} : contains(var.target_nodes, "hela") ? var.images : {}
  provider       = proxmox.hela
  content_type   = "iso"
  datastore_id   = "local"
  node_name      = "hela"
  file_name      = each.key
  url            = each.value
  upload_timeout = 2400
  overwrite      = false
}

resource "proxmox_virtual_environment_download_file" "thor_images" {
  for_each       = var.target_nodes == null ? {} : contains(var.target_nodes, "thor") ? var.images : {}
  provider       = proxmox.wanda
  content_type   = "iso"
  datastore_id   = "local"
  node_name      = "thor"
  file_name      = each.key
  url            = each.value
  upload_timeout = 2400
  overwrite      = false
}

resource "proxmox_virtual_environment_download_file" "loki_images" {
  for_each       = var.target_nodes == null ? {} : contains(var.target_nodes, "loki") ? var.images : {}
  provider       = proxmox.wanda
  content_type   = "iso"
  datastore_id   = "local"
  node_name      = "loki"
  file_name      = each.key
  url            = each.value
  upload_timeout = 2400
  overwrite      = false
}
