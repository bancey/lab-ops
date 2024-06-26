resource "proxmox_virtual_environment_download_file" "wanda_ubuntu_cloud_image" {
  for_each       = var.target_nodes == null ? {} : contains(var.target_nodes, "wanda") ? { for image in var.ubuntu_images : "${image.ubuntu_version}-${image.ubuntu_image_version}" => image } : {}
  provider       = proxmox.wanda
  content_type   = "iso"
  datastore_id   = "local"
  node_name      = "wanda"
  file_name      = "${each.value.ubuntu_version}-server-cloudimg-amd64-${each.value.ubuntu_image_version}.img"
  url            = "https://cloud-images.ubuntu.com/${each.value.ubuntu_version}/${each.value.ubuntu_image_version}/jammy-server-cloudimg-amd64.img"
  upload_timeout = 2400
}

resource "proxmox_virtual_environment_download_file" "hela_ubuntu_cloud_image" {
  for_each       = var.target_nodes == null ? {} : contains(var.target_nodes, "hela") ? { for image in var.ubuntu_images : "${image.ubuntu_version}-${image.ubuntu_image_version}" => image } : {}
  provider       = proxmox.hela
  content_type   = "iso"
  datastore_id   = "local"
  node_name      = "hela"
  file_name      = "${each.value.ubuntu_version}-server-cloudimg-amd64-${each.value.ubuntu_image_version}.img"
  url            = "https://cloud-images.ubuntu.com/${each.value.ubuntu_version}/${each.value.ubuntu_image_version}/jammy-server-cloudimg-amd64.img"
  upload_timeout = 2400
}

resource "proxmox_virtual_environment_download_file" "thor_ubuntu_cloud_image" {
  for_each       = var.target_nodes == null ? {} : contains(var.target_nodes, "thor") ? { for image in var.ubuntu_images : "${image.ubuntu_version}-${image.ubuntu_image_version}" => image } : {}
  provider       = proxmox.thor
  content_type   = "iso"
  datastore_id   = "local"
  node_name      = "thor"
  file_name      = "${each.value.ubuntu_version}-server-cloudimg-amd64-${each.value.ubuntu_image_version}.img"
  url            = "https://cloud-images.ubuntu.com/${each.value.ubuntu_version}/${each.value.ubuntu_image_version}/jammy-server-cloudimg-amd64.img"
  upload_timeout = 2400
}

resource "proxmox_virtual_environment_download_file" "loki_ubuntu_cloud_image" {
  for_each       = var.target_nodes == null ? {} : contains(var.target_nodes, "loki") ? { for image in var.ubuntu_images : "${image.ubuntu_version}-${image.ubuntu_image_version}" => image } : {}
  provider       = proxmox.loki
  content_type   = "iso"
  datastore_id   = "local"
  node_name      = "loki"
  file_name      = "${each.value.ubuntu_version}-server-cloudimg-amd64-${each.value.ubuntu_image_version}.img"
  url            = "https://cloud-images.ubuntu.com/${each.value.ubuntu_version}/${each.value.ubuntu_image_version}/jammy-server-cloudimg-amd64.img"
  upload_timeout = 2400
}
