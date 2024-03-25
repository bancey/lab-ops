resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.target_node

  source_raw {
    data = templatefile("${path.module}/cloud-config.tftpl", {
      name     = var.vm_name
      password = var.password
      domain   = var.domain
      username = var.username
    })

    file_name = "${var.vm_name}-cloud-config.yaml"
  }
}
