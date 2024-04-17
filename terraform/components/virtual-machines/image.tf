resource "proxmox_virtual_environment_download_file" "wanda_ubuntu_cloud_image" {
  count        = var.target_nodes == null ? 0 : contains(var.target_nodes, "wanda") ? 1 : 0
  provider     = proxmox.wanda
  content_type = "iso"
  datastore_id = "local"
  node_name    = "wanda"
  url          = "https://cloud-images.ubuntu.com/jammy/20240416/jammy-server-cloudimg-amd64.img"
}

resource "proxmox_virtual_environment_download_file" "hela_ubuntu_cloud_image" {
  count        = var.target_nodes == null ? 0 : contains(var.target_nodes, "hela") ? 1 : 0
  provider     = proxmox.hela
  content_type = "iso"
  datastore_id = "local"
  node_name    = "hela"
  url          = "https://cloud-images.ubuntu.com/jammy/20240416/jammy-server-cloudimg-amd64.img"
}

resource "proxmox_virtual_environment_download_file" "thor_ubuntu_cloud_image" {
  count        = var.target_nodes == null ? 0 : contains(var.target_nodes, "thor") ? 1 : 0
  provider     = proxmox.thor
  content_type = "iso"
  datastore_id = "local"
  node_name    = "thor"
  url          = "https://cloud-images.ubuntu.com/jammy/20240416/jammy-server-cloudimg-amd64.img"
}

resource "proxmox_virtual_environment_download_file" "loki_ubuntu_cloud_image" {
  count        = var.target_nodes == null ? 0 : contains(var.target_nodes, "loki") ? 1 : 0
  provider     = proxmox.loki
  content_type = "iso"
  datastore_id = "local"
  node_name    = "loki"
  url          = "https://cloud-images.ubuntu.com/jammy/20240416/jammy-server-cloudimg-amd64.img"
}
