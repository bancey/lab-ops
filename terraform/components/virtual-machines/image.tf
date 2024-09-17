resource "proxmox_virtual_environment_download_file" "wanda_images" {
  for_each       = var.target_nodes == null ? {} : contains(var.target_nodes, "wanda") ? var.images : {}
  provider       = proxmox.wanda
  content_type   = each.value.content_type
  datastore_id   = "local"
  node_name      = "wanda"
  file_name      = each.key
  url            = each.value.url
  upload_timeout = 2400
}

resource "proxmox_virtual_environment_download_file" "tiny_images" {
  for_each       = { for pair in setproduct(local.tiny_nodes, local.set_images) : "${pair[0]}-${pair[1].key}" => { filename = pair[1].key, url = pair[1].value.url, content_type = pair[1].value.content_type, node = pair[0] } if contains(var.target_nodes, pair[0]) }
  provider       = proxmox.tiny
  content_type   = each.value.content_type
  datastore_id   = "local"
  node_name      = each.value.node
  file_name      = each.value.filename
  url            = each.value.url
  upload_timeout = 2400
}
