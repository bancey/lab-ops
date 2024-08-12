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
  for_each       = { for pair in setproduct(local.tiny_nodes, local.set_images) : "${pair[0]}-${pair[1].key}" => pair[1].value if contains(var.target_nodes, pair[0]) }
  provider       = proxmox.tiny
  content_type   = "iso"
  datastore_id   = "local"
  node_name      = each.value
  file_name      = each.key
  url            = each.value
  upload_timeout = 2400
}
