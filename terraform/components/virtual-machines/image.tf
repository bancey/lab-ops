resource "proxmox_virtual_environment_download_file" "wanda_ubuntu_cloud_image" {
  count        = var.target_nodes == null ? 0 : contains(var.target_nodes, "wanda") ? toset(var.ubuntu_images) : 0
  provider     = proxmox.wanda
  content_type = "iso"
  datastore_id = "local"
  node_name    = "wanda"
  file_name    = "${var.ubuntu_images[count.index].ubuntu_version}-server-cloudimg-amd64-${var.ubuntu_images[count.index].ubuntu_image_version}.img"
  url          = "https://cloud-images.ubuntu.com/${var.ubuntu_images[count.index].ubuntu_version}/${var.ubuntu_images[count.index].ubuntu_image_version}/jammy-server-cloudimg-amd64.img"
}

resource "proxmox_virtual_environment_download_file" "hela_ubuntu_cloud_image" {
  count        = var.target_nodes == null ? 0 : contains(var.target_nodes, "hela") ? toset(var.ubuntu_images) : 0
  provider     = proxmox.hela
  content_type = "iso"
  datastore_id = "local"
  node_name    = "hela"
  file_name    = "${var.ubuntu_images[count.index].ubuntu_version}-server-cloudimg-amd64-${var.ubuntu_images[count.index].ubuntu_image_version}.img"
  url          = "https://cloud-images.ubuntu.com/${var.ubuntu_images[count.index].ubuntu_version}/${var.ubuntu_images[count.index].ubuntu_image_version}/jammy-server-cloudimg-amd64.img"
}

resource "proxmox_virtual_environment_download_file" "thor_ubuntu_cloud_image" {
  count        = var.target_nodes == null ? 0 : contains(var.target_nodes, "thor") ? toset(var.ubuntu_images) : 0
  provider     = proxmox.thor
  content_type = "iso"
  datastore_id = "local"
  node_name    = "thor"
  file_name    = "${var.ubuntu_images[count.index].ubuntu_version}-server-cloudimg-amd64-${var.ubuntu_images[count.index].ubuntu_image_version}.img"
  url          = "https://cloud-images.ubuntu.com/${var.ubuntu_images[count.index].ubuntu_version}/${var.ubuntu_images[count.index].ubuntu_image_version}/jammy-server-cloudimg-amd64.img"
}

resource "proxmox_virtual_environment_download_file" "loki_ubuntu_cloud_image" {
  count        = var.target_nodes == null ? 0 : contains(var.target_nodes, "loki") ? toset(var.ubuntu_images) : 0
  provider     = proxmox.loki
  content_type = "iso"
  datastore_id = "local"
  node_name    = "loki"
  file_name    = "${var.ubuntu_images[count.index].ubuntu_version}-server-cloudimg-amd64-${var.ubuntu_images[count.index].ubuntu_image_version}.img"
  url          = "https://cloud-images.ubuntu.com/${var.ubuntu_images[count.index].ubuntu_version}/${var.ubuntu_images[count.index].ubuntu_image_version}/jammy-server-cloudimg-amd64.img"
}
