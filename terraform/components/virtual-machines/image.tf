resource "proxmox_virtual_environment_download_file" "wanda_ubuntu_cloud_image" {
  provider     = proxmox.wanda
  content_type = "iso"
  datastore_id = "local"
  node_name    = "wanda"
  url          = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
}

resource "proxmox_virtual_environment_download_file" "hela_ubuntu_cloud_image" {
  provider     = proxmox.hela
  content_type = "iso"
  datastore_id = "local"
  node_name    = "hela"
  url          = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
}

resource "proxmox_virtual_environment_download_file" "thor_ubuntu_cloud_image" {
  provider     = proxmox.thor
  content_type = "iso"
  datastore_id = "local"
  node_name    = "thor"
  url          = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
}

resource "proxmox_virtual_environment_download_file" "loki_ubuntu_cloud_image" {
  provider     = proxmox.loki
  content_type = "iso"
  datastore_id = "local"
  node_name    = "loki"
  url          = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
}
