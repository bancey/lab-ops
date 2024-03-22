locals {
  password_hash = bcrypt(var.password, 10)
}

resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.target_node

  source_raw {
    data = templatefile("${path.module}/cloud-config.tftpl", {
      name     = var.vm_name
      domain   = var.domain
      username = var.username
      password = local.password_hash
    })

    file_name = "cloud-config.yaml"
  }
}