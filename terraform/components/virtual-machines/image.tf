resource "proxmox_virtual_environment_download_file" "wanda_images" {
  for_each       = var.target_nodes == null ? {} : contains(var.target_nodes, "wanda") ? var.images : {}
  provider       = proxmox.wanda
  content_type   = "iso"
  datastore_id   = "local"
  node_name      = "wanda"
  file_name      = each.key
  url            = each.value
  upload_timeout = 2400
}

resource "proxmox_virtual_environment_download_file" "tiny_images" {
  for_each       = { for pair in setproduct(local.tiny_nodes, local.set_images) : pair[1].key => {url = pair[1].value, node = pair[0]} if contains(var.target_nodes, pair[0]) }
  provider       = proxmox.tiny
  content_type   = "iso"
  datastore_id   = "local"
  node_name      = each.value.node
  file_name      = each.key
  url            = each.value.url
  upload_timeout = 2400
}

moved {
  from = proxmox_virtual_environment_download_file.hela_images["jammy-server-cloudimg-amd64.img"]
  to   = proxmox_virtual_environment_download_file.tiny_images["hela-jammy-server-cloudimg-amd64.img"]
}
moved {
  from = proxmox_virtual_environment_download_file.loki_images["jammy-server-cloudimg-amd64.img"]
  to   = proxmox_virtual_environment_download_file.tiny_images["loki-jammy-server-cloudimg-amd64.img"]
}
moved {
  from = proxmox_virtual_environment_download_file.thor_images["jammy-server-cloudimg-amd64.img"]
  to   = proxmox_virtual_environment_download_file.tiny_images["thor-jammy-server-cloudimg-amd64.img"]
}
